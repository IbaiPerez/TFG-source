extends RefCounted
class_name AIRealEvents

## Chance node de eventos de turno para la simulación MCTS.
##
## Ejecuta, SOBRE EL SNAPSHOT (AIRealState) y desacoplado del bus global `Events`,
## el pipeline de eventos del juego: TurnEventManager (curva de probabilidad +
## pesos por categoría + prioridad CORE), evaluación de condiciones, selección de
## choice y aplicación de efectos + costes.
##
## Casi nada aquí está escrito dos veces:
##   · CONDICIONES: se evalúan las clases REALES sobre un EventContext construido
##     con `EventContext.from_snapshot`.
##   · CHOICE y TIENDA: AIChoiceScorer / AIShopPolicy, compartidos con el mundo
##     vivo a través del puerto AIStateView.
##   · VALOR DE CARTA: AIDeckScorer, también compartido.
## Lo que SIGUE siendo propio del snapshot es la APLICACIÓN de efectos de casilla
## (`_apply_colonize_adjacent`, `_apply_urbanize_megalopolis`): los efectos reales
## mutan vía el bus `Events`, que en vivo dispararía el TilesTracker y corrompería
## la partida, y además difieren en el RNG (global `pick_random` vs el inyectado y
## determinista del MCTS) y en quién elige la casilla.
##
## Se REUSAN además los recursos puros: TurnEvent/Condition/Effect (se leen sus
## parámetros), EventCategoryWeights, UnlockedCardEntry, Comparison.
##
## Es un CHANCE NODE: muestrea su propia tirada por iteración (rng inyectado);
## promediar sobre iteraciones integra la estocasticidad (paridad distribucional,
## no exacta).


const MEGALOPOLIS: LocationType = preload("res://resources/location_type/megalopolis.tres")


## Punto de entrada: evalúa y resuelve (si dispara) el evento de fin de turno de
## `p_owner` sobre el snapshot. Devuelve el TurnEvent disparado o null.
## Espejo de TurnEventManager.evaluate + AIEventResolver.resolve.
## `w` alimenta el valorador de carta unificado que usa la tienda. Es
## opcional: sin pesos explícitos se usa el default cacheado, igual que el MCTS.
static func process_turn_event(state: AIRealState, p_owner: int,
		rng: RandomNumberGenerator, w: HeuristicWeights = null) -> TurnEvent:
	var emp := state.empire(p_owner)
	if emp == null or emp.available_events.is_empty():
		return null

	# Paso 1: probabilidad global de evento.
	if rng.randf() > _event_chance(emp, state.turn_number):
		return null

	# Candidatos disponibles agrupados por categoría. El contexto agregado se
	# construye UNA vez por evaluación y se comparte por todas las condiciones.
	var by_category := _collect_available_by_category(emp, EventContext.from_snapshot(state, p_owner))
	if by_category.is_empty():
		return null

	# Paso 2: prioridad CORE_PROGRESSION.
	var picked: TurnEvent = null
	if by_category.has(EventCategory.Type.CORE_PROGRESSION):
		if rng.randf() < _core_priority_chance(emp):
			picked = _weighted_pick_event(by_category[EventCategory.Type.CORE_PROGRESSION], rng)

	# Paso 3: pickeo ponderado por categoría.
	if picked == null:
		var category := _pick_category(by_category, state.turn_number, emp.category_weights, rng)
		if category < 0:
			return null
		picked = _weighted_pick_event(by_category[category], rng)

	if picked != null:
		_resolve_event(picked, state, p_owner, rng, w)
	return picked


# ============================================================
#  Manager (espejo de TurnEventManager)
# ============================================================

static func _event_chance(emp: AIRealState.EmpireSnap, turn: int) -> float:
	if emp.category_weights == null:
		return emp.event_chance
	return emp.category_weights.get_event_chance(turn)


static func _core_priority_chance(emp: AIRealState.EmpireSnap) -> float:
	if emp.category_weights == null:
		return 0.9
	return emp.category_weights.core_priority_chance


static func _collect_available_by_category(emp: AIRealState.EmpireSnap,
		ctx: EventContext) -> Dictionary:
	var by_category := {}
	for event in emp.available_events:
		if event.unique and event.id in emp.used_unique_events:
			continue
		if not conditions_met(event, ctx):
			continue
		if not by_category.has(event.category):
			by_category[event.category] = []
		by_category[event.category].append(event)
	return by_category


static func _pick_category(by_category: Dictionary, turn: int,
		weights: EventCategoryWeights, rng: RandomNumberGenerator) -> int:
	var total_weight := 0.0
	var category_weights := {}
	for category in by_category.keys():
		var w := 1.0
		if weights != null:
			w = weights.get_weight(category, turn)
		if w <= 0.0:
			continue
		category_weights[category] = w
		total_weight += w
	if total_weight <= 0.0:
		return -1
	var roll := rng.randf() * total_weight
	var cumulative := 0.0
	var last_category := -1
	for category in category_weights.keys():
		cumulative += category_weights[category]
		last_category = category
		if roll <= cumulative:
			return category
	return last_category


static func _weighted_pick_event(events: Array, rng: RandomNumberGenerator) -> TurnEvent:
	if events.is_empty():
		return null
	var total_weight := 0.0
	for e in events:
		total_weight += (e as TurnEvent).weight
	if total_weight <= 0.0:
		return events[0]
	var roll := rng.randf() * total_weight
	var cumulative := 0.0
	for e in events:
		cumulative += (e as TurnEvent).weight
		if roll <= cumulative:
			return e
	return events.back()


# ============================================================
#  Condiciones (se REUSAN las clases reales)
# ============================================================

## True si TODAS las condiciones del evento se cumplen. Ya no hay espejo: las
## condiciones REALES se evalúan sobre un EventContext construido desde el snapshot
## (`EventContext.from_snapshot`), así que existe una sola implementación de cada
## regla y el polimorfismo de TurnEventCondition sustituye al viejo `if cond is X`
## encadenado.
static func conditions_met(event: TurnEvent, ctx: EventContext) -> bool:
	for cond in event.conditions:
		if not cond.is_met(ctx):
			return false
	return true


# ============================================================
#  Resolución (espejo de AIEventResolver sobre el snapshot)
# ============================================================

static func _resolve_event(event: TurnEvent, state: AIRealState, p_owner: int,
		rng: RandomNumberGenerator, w: HeuristicWeights = null) -> void:
	var emp := state.empire(p_owner)

	# La tienda se resuelve aparte (compras/purgas), igual que AIEventResolver.
	if event is ShopEvent:
		_resolve_shop(event as ShopEvent, state, p_owner, emp, state.turn_number, rng, w)
		_mark_unique(event, emp)
		return

	# Choices asequibles + skip.
	var available: Array[TurnEventChoice] = []
	for c in event.choices:
		if c != null and _choice_affordable(c, emp, state):
			available.append(c)
	var skip_choice: TurnEventChoice = null
	if event.allow_skip:
		skip_choice = TurnEventChoice.new()
		available.append(skip_choice)

	if available.is_empty():
		_mark_unique(event, emp)
		return

	# Elegir la de mayor valor (skip = 0). Vista construida UNA vez para todas las
	# comparaciones (el scorer es el mismo que el del mundo vivo).
	var view := SnapshotStateView.new(state, p_owner,
		w if w != null else HeuristicWeights.get_default())
	var picked: TurnEventChoice = available[0]
	var best := AIChoiceScorer.score_choice(view, available[0])
	for i in range(1, available.size()):
		var s := AIChoiceScorer.score_choice(view, available[i])
		if s > best:
			best = s
			picked = available[i]

	if picked != skip_choice:
		_apply_choice(picked, state, p_owner, rng)
	_mark_unique(event, emp)


static func _mark_unique(event: TurnEvent, emp: AIRealState.EmpireSnap) -> void:
	if event.unique and event.id not in emp.used_unique_events:
		emp.used_unique_events.append(event.id)


static func _choice_affordable(choice: TurnEventChoice, emp: AIRealState.EmpireSnap,
		state: AIRealState) -> bool:
	if choice.cost == null:
		return true
	var cost := choice.cost
	var gold_needed := _cost_gold(cost, emp, state)
	if gold_needed > 0 and emp.gold < gold_needed:
		return false
	if cost.food > 0 and emp.food < cost.food:
		return false
	if cost.auto_remove_filter != null and not _filter_has_match(cost.auto_remove_filter, emp):
		return false
	if cost.player_remove_filter != null and _filter_candidates(cost.player_remove_filter, emp).is_empty():
		return false
	return true


## Coste de oro de un TurnEventCost (resuelve ScaledGoldCost dinámicamente).
static func _cost_gold(cost: TurnEventCost, emp: AIRealState.EmpireSnap,
		state: AIRealState) -> int:
	if cost is ScaledGoldCost:
		var sc := cost as ScaledGoldCost
		return int(ScaledValue.evaluate(sc.base_gold, sc.turn_factor, sc.gpt_percent,
			state.turn_number, emp.gold_per_turn))
	return cost.gold


# ============================================================
#  Aplicación de coste y efectos (espejo sobre el snapshot)
# ============================================================

static func _apply_choice(choice: TurnEventChoice, state: AIRealState, p_owner: int,
		rng: RandomNumberGenerator) -> void:
	var emp := state.empire(p_owner)
	if choice.cost != null:
		_apply_cost(choice.cost, emp, state)
	for effect in choice.effects:
		if effect != null:
			_apply_effect(effect, state, p_owner, rng)


static func _apply_cost(cost: TurnEventCost, emp: AIRealState.EmpireSnap,
		state: AIRealState) -> void:
	emp.gold -= _cost_gold(cost, emp, state)
	emp.food -= cost.food
	if cost.auto_remove_filter != null:
		_filter_remove_first(cost.auto_remove_filter, emp)
	if cost.player_remove_filter != null:
		_remove_most_expendable(cost.player_remove_filter, emp)


## Tabla `Script → Callable` de aplicadores de efecto, en lugar de la cadena
## de `elif effect is X`. Se resuelve SUBIENDO por get_base_script(), así que una
## subclase nueva hereda el aplicador de su padre sin depender del orden de la
## cadena. Todos los handlers comparten firma (effect, state, p_owner, emp, rng).
static var _effect_handlers: Dictionary = {}


static func _ensure_effect_handlers() -> void:
	if not _effect_handlers.is_empty():
		return
	_effect_handlers[GoldEventEffect]              = Callable(AIRealEvents, "_eff_gold")
	_effect_handlers[FoodEventEffect]              = Callable(AIRealEvents, "_eff_food")
	_effect_handlers[ScaledGoldEffect]             = Callable(AIRealEvents, "_eff_scaled_gold")
	_effect_handlers[ScaledFoodEffect]             = Callable(AIRealEvents, "_eff_scaled_food")
	_effect_handlers[ApplyModifierEffect]          = Callable(AIRealEvents, "_eff_apply_modifier")
	_effect_handlers[ScaledStatModifierEffect]     = Callable(AIRealEvents, "_eff_scaled_stat_modifier")
	_effect_handlers[ScaledBuildCostModifierEffect] = Callable(AIRealEvents, "_eff_scaled_build_cost")
	_effect_handlers[AddCardEffect]                = Callable(AIRealEvents, "_eff_add_card")
	_effect_handlers[AddToCardPoolEffect]          = Callable(AIRealEvents, "_eff_add_to_pool")
	_effect_handlers[AddRandomPoolCardEffect]      = Callable(AIRealEvents, "_eff_add_random_pool_card")
	_effect_handlers[UnlockBuildingEffect]         = Callable(AIRealEvents, "_eff_unlock_building")
	_effect_handlers[RemoveCardEventEffect]        = Callable(AIRealEvents, "_eff_remove_card")
	_effect_handlers[ColonizeAdjacentEffect]       = Callable(AIRealEvents, "_eff_colonize_adjacent")
	_effect_handlers[UrbanizeToMegalopolisEffect]  = Callable(AIRealEvents, "_eff_urbanize")


static func _apply_effect(effect: TurnEventEffect, state: AIRealState, p_owner: int,
		rng: RandomNumberGenerator) -> void:
	var emp := state.empire(p_owner)
	_ensure_effect_handlers()
	var script := effect.get_script() as Script
	while script != null:
		if _effect_handlers.has(script):
			(_effect_handlers[script] as Callable).call(effect, state, p_owner, emp, rng)
			return
		script = script.get_base_script()
	# Otros efectos sin impacto en el estado modelado → no-op.


# ── Aplicadores por tipo de efecto ────────────────────────────────────────────

static func _eff_gold(effect, _state, _p_owner, emp, _rng) -> void:
	emp.gold += (effect as GoldEventEffect).amount


static func _eff_food(effect, _state, _p_owner, emp, _rng) -> void:
	emp.food += (effect as FoodEventEffect).amount


static func _eff_scaled_gold(effect, state, _p_owner, emp, _rng) -> void:
	var e := effect as ScaledGoldEffect
	emp.gold += int(ScaledValue.evaluate(e.base, e.turn_factor, e.gpt_percent,
		state.turn_number, emp.gold_per_turn))


static func _eff_scaled_food(effect, state, _p_owner, emp, _rng) -> void:
	var e := effect as ScaledFoodEffect
	emp.food += int(ScaledValue.evaluate(e.base, e.turn_factor, e.food_percent,
		state.turn_number, emp.food))


static func _eff_apply_modifier(effect, _state, _p_owner, emp, _rng) -> void:
	_add_modifier(emp, (effect as ApplyModifierEffect).modifier.duplicate_modifier())


static func _eff_scaled_stat_modifier(effect, state, _p_owner, emp, _rng) -> void:
	var e := effect as ScaledStatModifierEffect
	var ref_stat := _scaled_stat_reference(e, emp)
	var value := ScaledValue.evaluate(e.base_value, e.turn_factor, e.stat_percent,
		state.turn_number, ref_stat)
	_add_modifier(emp, StatModifier.new(e.modifier_id, e.modifier_name,
		e.stat_type, value, e.duration))


static func _eff_scaled_build_cost(effect, state, _p_owner, emp, _rng) -> void:
	var e := effect as ScaledBuildCostModifierEffect
	var percent := ScaledValue.evaluate(e.base_percent, e.turn_factor, 0.0, state.turn_number)
	_add_modifier(emp, BuildCostModifier.new(e.modifier_id, e.modifier_name,
		percent, e.duration))


static func _eff_add_card(effect, _state, _p_owner, emp, _rng) -> void:
	emp.deck.append((effect as AddCardEffect).card.duplicate())


static func _eff_add_to_pool(effect, _state, _p_owner, emp, _rng) -> void:
	_add_to_card_pool(emp, (effect as AddToCardPoolEffect).entry)


static func _eff_add_random_pool_card(_effect, state, _p_owner, emp, rng) -> void:
	var card := _weighted_pick_pool_card(emp, state.turn_number, rng)
	if card != null:
		emp.deck.append(card.duplicate())


static func _eff_unlock_building(effect, _state, _p_owner, emp, _rng) -> void:
	var b := (effect as UnlockBuildingEffect).building
	if b != null and b not in emp.possible_buildings:
		emp.possible_buildings.append(b)


static func _eff_remove_card(effect, _state, _p_owner, emp, _rng) -> void:
	var e := effect as RemoveCardEventEffect
	if e.auto_filter != null:
		_filter_remove_first(e.auto_filter, emp)
	if e.player_filter != null:
		_remove_most_expendable(e.player_filter, emp)


static func _eff_colonize_adjacent(effect, state, p_owner, _emp, rng) -> void:
	_apply_colonize_adjacent(state, p_owner, (effect as ColonizeAdjacentEffect).preferred_biome, rng)


static func _eff_urbanize(effect, state, p_owner, _emp, _rng) -> void:
	_apply_urbanize_megalopolis(state, p_owner, (effect as UrbanizeToMegalopolisEffect).min_buildings)


## Añade un modifier al snapshot solo si es económico (afecta a recompute_economy).
static func _add_modifier(emp: AIRealState.EmpireSnap, mod: Modifier) -> void:
	if mod is StatModifier or mod is BuildCostModifier:
		emp.modifiers.append(mod)


static func _scaled_stat_reference(effect: ScaledStatModifierEffect,
		emp: AIRealState.EmpireSnap) -> float:
	match effect.stat_type:
		StatModifier.StatType.FLAT_GOLD, StatModifier.StatType.PERCENT_GOLD:
			return float(emp.gold_per_turn)
		StatModifier.StatType.FLAT_FOOD, StatModifier.StatType.PERCENT_FOOD:
			return float(emp.food)
		_:
			return 0.0


## Añade una entrada al pool desbloqueado evitando duplicados por id de carta
## (espejo de Stats.add_to_card_pool).
static func _add_to_card_pool(emp: AIRealState.EmpireSnap, entry: UnlockedCardEntry) -> void:
	for existing in emp.unlocked_card_pool:
		if existing.card.id == entry.card.id:
			return
	emp.unlocked_card_pool.append(entry)


static func _weighted_pick_pool_card(emp: AIRealState.EmpireSnap, turn: int,
		rng: RandomNumberGenerator) -> Card:
	if emp.unlocked_card_pool.is_empty():
		return null
	var total := 0.0
	for entry in emp.unlocked_card_pool:
		total += entry.get_weight(turn)
	if total <= 0.0:
		return null
	var roll := rng.randf() * total
	var cumulative := 0.0
	for entry in emp.unlocked_card_pool:
		cumulative += entry.get_weight(turn)
		if roll <= cumulative:
			return entry.card
	return emp.unlocked_card_pool.back().card


# ── Filtros de eliminación de cartas (espejo de CardRemovalFilter sobre deck) ──

static func _filter_matches(filter: CardRemovalFilter, card: Card) -> bool:
	if filter.card_id != "" and card.id != filter.card_id:
		return false
	if filter.card_type != -1 and card.type != filter.card_type:
		return false
	return true


static func _filter_candidates(filter: CardRemovalFilter,
		emp: AIRealState.EmpireSnap) -> Array[Card]:
	var result: Array[Card] = []
	for c in emp.deck:
		if _filter_matches(filter, c):
			result.append(c)
	return result


static func _filter_has_match(filter: CardRemovalFilter, emp: AIRealState.EmpireSnap) -> bool:
	for c in emp.deck:
		if _filter_matches(filter, c):
			return true
	return false


static func _filter_remove_first(filter: CardRemovalFilter, emp: AIRealState.EmpireSnap) -> void:
	for i in range(emp.deck.size()):
		if _filter_matches(filter, emp.deck[i]):
			emp.deck.remove_at(i)
			return


## Elimina la carta "más prescindible" entre las candidatas. Aproximación de
## AIHeuristic.pick_card_to_remove: prioriza descartar duplicados de la carta más
## repetida del filtro; sin criterio mejor, la primera candidata.
static func _remove_most_expendable(filter: CardRemovalFilter,
		emp: AIRealState.EmpireSnap) -> void:
	var candidates := _filter_candidates(filter, emp)
	if candidates.is_empty():
		return
	emp.deck.erase(candidates[0])


# ── Efectos de tile (reusan AIRealSimulator, sin señales) ─────────────────────

static func _apply_colonize_adjacent(state: AIRealState, p_owner: int,
		preferred_biome: int, rng: RandomNumberGenerator) -> void:
	var candidates: Array[int] = []
	var preferred: Array[int] = []
	for id in state.tiles:
		var t := state.tiles[id] as AIRealState.TileSnap
		if t.owner != p_owner:
			continue
		for nid in t.neighbor_ids:
			var nb := state.tiles.get(nid) as AIRealState.TileSnap
			if nb != null and nb.owner == AIRealState.OWNER_NONE and nid not in candidates:
				candidates.append(nid)
				if preferred_biome != -1 and nb.biome == preferred_biome:
					preferred.append(nid)
	var pool := preferred if not preferred.is_empty() else candidates
	if pool.is_empty():
		return
	var chosen: int = pool[rng.randi_range(0, pool.size() - 1)]
	AIRealEffects.apply_colonize(state, chosen, p_owner)


static func _apply_urbanize_megalopolis(state: AIRealState, p_owner: int,
		min_buildings: int) -> void:
	var best_id := -1
	var best_score := -INF
	for id in state.tiles:
		var t := state.tiles[id] as AIRealState.TileSnap
		if t.owner != p_owner or t.location_type != Tile.location_type.Town:
			continue
		if t.buildings.size() < min_buildings:
			continue
		# Fórmula compartida con el estado vivo: valor de los edificios
		# que sobreviven + recurso − los que se demolerán.
		var tile_score := AIEventScoring.megalopolis_tile_value(
			t.buildings, t.natural_resource)
		if tile_score > best_score:
			best_score = tile_score
			best_id = id
	if best_id >= 0:
		AIRealEffects.apply_change_location(state, best_id, MEGALOPOLIS, p_owner)


# ============================================================
# Tienda (espejo de ShopGenerator + AIEventResolver._resolve_shop_event)
# ============================================================

## Resuelve un ShopEvent sobre el snapshot: genera la oferta desde el pool de
## tienda (unlocked + exclusivas), compra los ítems que la heurística considera
## valiosos y purga las cartas más débiles. El efecto que importa es que `deck`
## refleje las compras/purgas; la decisión exacta es suelo heurístico.
static func _resolve_shop(event: ShopEvent, state: AIRealState, p_owner: int,
		emp: AIRealState.EmpireSnap, turn: int, rng: RandomNumberGenerator,
		w: HeuristicWeights = null) -> void:
	# Vista construida UNA vez para toda la resolución: `emp` es una
	# referencia, así que las compras/purgas que mutan el mazo se ven al instante.
	var view := SnapshotStateView.new(state, p_owner,
		w if w != null else HeuristicWeights.get_default())
	var special := event.shop_type == ShopEvent.ShopType.SPECIAL
	var num_cards := 3 if special else rng.randi_range(2, 3)
	var base_turn := 12 if special else 8
	var max_purges := rng.randi_range(2, 3) if special else 1

	# Pool de tienda completo (espejo de Stats.get_full_shop_pool).
	var pool: Array[UnlockedCardEntry] = []
	pool.append_array(emp.unlocked_card_pool)
	pool.append_array(emp.shop_exclusive_pool)

	# --- Compras ---
	for card in _weighted_pick_cards(pool, num_cards, turn, rng):
		var price := _price_for_card(card, turn, base_turn, rng)
		if emp.gold >= price and AIShopPolicy.should_buy(view, card):
			emp.gold -= price
			emp.deck.append(card.duplicate())

	# --- Purga ---
	var purge_cost := ShopGenerator._get_purge_cost(emp.total_purges_done)
	var purges_done := 0
	while not emp.deck.is_empty() and purges_done < max_purges and emp.gold >= purge_cost:
		var worst := AIShopPolicy.pick_weakest(view, emp.deck)
		if worst == null:
			break
		if AIDeckScorer.score_card_for_deck(view, worst) >= AIShopPolicy.purge_threshold(view):
			break   # todas las cartas son suficientemente valiosas
		emp.deck.erase(worst)
		emp.gold -= purge_cost
		emp.total_purges_done += 1
		purges_done += 1
		purge_cost = ShopGenerator._get_purge_cost(emp.total_purges_done)


## Precio de una carta (espejo de ShopGenerator._price_for_card/_scaled_price):
## base aleatorio por tipo escalado +2%/turno desde base_turn.
static func _price_for_card(card: Card, turn: int, base_turn: int,
		rng: RandomNumberGenerator) -> int:
	var base_min: int
	var base_max: int
	match card.type:
		Card.Type.SPECIAL, Card.Type.SINGLE_USE:
			base_min = ShopGenerator.SPECIAL_PRICE_MIN
			base_max = ShopGenerator.SPECIAL_PRICE_MAX
		_:
			base_min = ShopGenerator.BASIC_PRICE_MIN
			base_max = ShopGenerator.BASIC_PRICE_MAX
	var base := rng.randi_range(base_min, base_max)
	var turns_past := maxi(turn - base_turn, 0)
	return int(base * (1.0 + turns_past * ShopGenerator.PRICE_SCALE_PER_TURN))


## Selección ponderada de N cartas del pool sin repetición (espejo de
## ShopGenerator._weighted_pick_cards).
static func _weighted_pick_cards(pool: Array[UnlockedCardEntry], count: int,
		turn: int, rng: RandomNumberGenerator) -> Array[Card]:
	var result: Array[Card] = []
	if pool.is_empty():
		return result
	var remaining := pool.duplicate()
	for _i in range(mini(count, remaining.size())):
		var total := 0.0
		for entry in remaining:
			total += entry.get_weight(turn)
		if total <= 0.0:
			break
		var roll := rng.randf() * total
		var cumulative := 0.0
		for j in range(remaining.size()):
			cumulative += remaining[j].get_weight(turn)
			if roll <= cumulative:
				result.append(remaining[j].card)
				remaining.remove_at(j)
				break
	return result


# ============================================================
#  Internals
# ============================================================

static func _active_front_count(state: AIRealState, p_owner: int) -> int:
	var n := 0
	for f in state.fronts:
		var front := f as AIRealState.FrontSnap
		if not front.is_resolved and front.involves(p_owner):
			n += 1
	return n
