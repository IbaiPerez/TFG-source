extends RefCounted
class_name AIRealEvents

## Chance node de eventos de turno para la simulación MCTS (Fase C v2 — F2.5b).
##
## Reimplementa, SOBRE EL SNAPSHOT (AIRealState) y desacoplado del bus global
## `Events`, el pipeline de eventos del juego: TurnEventManager (curva de
## probabilidad + pesos por categoría + prioridad CORE), evaluación de
## condiciones (TurnEventCondition), selección de choice (espejo aproximado de
## AIHeuristic.score_choice) y aplicación de efectos (TurnEventEffect) + costes.
##
## ¿Por qué reimplementar en vez de reusar el código real? Dos bloqueos duros:
##   1. Varios efectos (ColonizeAdjacentEffect, UrbanizeToMegalopolisEffect)
##      mutan tiles vía `Events.change_tile_controller/location_type`. Durante
##      el juego en vivo (F3) eso dispararía el TilesTracker real y corrompería
##      la partida. Reusarlos es INSEGURO.
##   2. Las condiciones y AIHeuristic.score_choice están acopladas a Stats/Tile
##      reales (escena), que el snapshot evita por diseño.
## Se REUSAN los recursos puros: las propias instancias TurnEvent/Condition/
## Effect (se leen sus parámetros), EventCategoryWeights, UnlockedCardEntry,
## Comparison. La paridad de condiciones se valida en tests contra las reales.
##
## Es un CHANCE NODE: muestrea su propia tirada por iteración (rng inyectado);
## promediar sobre iteraciones integra la estocasticidad (paridad distribucional,
## no exacta — PLAN §3.6).


const MEGALOPOLIS: LocationType = preload("res://resources/location_type/megalopolis.tres")


## Punto de entrada: evalúa y resuelve (si dispara) el evento de fin de turno de
## `p_owner` sobre el snapshot. Devuelve el TurnEvent disparado o null.
## Espejo de TurnEventManager.evaluate + AIEventResolver.resolve.
static func process_turn_event(state: AIRealState, p_owner: int,
		rng: RandomNumberGenerator) -> TurnEvent:
	var emp := _empire_of(state, p_owner)
	if emp == null or emp.available_events.is_empty():
		return null

	# Fase A: probabilidad global de evento.
	if rng.randf() > _event_chance(emp, state.turn_number):
		return null

	# Candidatos disponibles agrupados por categoría.
	var by_category := _collect_available_by_category(emp, state, p_owner)
	if by_category.is_empty():
		return null

	# Fase B: prioridad CORE_PROGRESSION.
	var picked: TurnEvent = null
	if by_category.has(EventCategory.Type.CORE_PROGRESSION):
		if rng.randf() < _core_priority_chance(emp):
			picked = _weighted_pick_event(by_category[EventCategory.Type.CORE_PROGRESSION], rng)

	# Fase C: pickeo ponderado por categoría.
	if picked == null:
		var category := _pick_category(by_category, state.turn_number, emp.category_weights, rng)
		if category < 0:
			return null
		picked = _weighted_pick_event(by_category[category], rng)

	if picked != null:
		_resolve_event(picked, state, p_owner, rng)
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
		state: AIRealState, p_owner: int) -> Dictionary:
	var by_category := {}
	for event in emp.available_events:
		if event.unique and event.id in emp.used_unique_events:
			continue
		if not conditions_met(event, state, p_owner):
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
#  Condiciones (espejo de TurnEventCondition.is_met sobre el snapshot)
# ============================================================

## True si TODAS las condiciones del evento se cumplen sobre el snapshot.
static func conditions_met(event: TurnEvent, state: AIRealState, p_owner: int) -> bool:
	for cond in event.conditions:
		if not _condition_met(cond, state, p_owner):
			return false
	return true


static func _condition_met(cond: TurnEventCondition, state: AIRealState, p_owner: int) -> bool:
	var emp := _empire_of(state, p_owner)
	if emp == null:
		return false

	if cond is GoldThresholdCondition:
		var c := cond as GoldThresholdCondition
		return Comparison.evaluate(emp.gold, c.op, c.threshold)
	if cond is MinGoldCondition:
		return emp.gold >= (cond as MinGoldCondition).amount
	if cond is FoodThresholdCondition:
		var c := cond as FoodThresholdCondition
		return Comparison.evaluate(emp.food, c.op, c.threshold)
	if cond is GoldGenerationCondition:
		var c := cond as GoldGenerationCondition
		return Comparison.evaluate(emp.gold_per_turn, c.op, c.threshold)
	if cond is TurnNumberCondition:
		var c := cond as TurnNumberCondition
		return Comparison.evaluate(state.turn_number, c.op, c.threshold)
	if cond is DeckSizeCondition:
		var c := cond as DeckSizeCondition
		return Comparison.evaluate(emp.deck.size(), c.op, c.count)
	if cond is ActiveModifiersCondition:
		# Aproximación: el snapshot solo modela los modifiers económicos.
		var c := cond as ActiveModifiersCondition
		return Comparison.evaluate(emp.modifiers.size(), c.op, c.count)
	if cond is CardCountCondition:
		var c := cond as CardCountCondition
		return Comparison.evaluate(_count_cards_by_id(emp, c.card_id), c.op, c.count)
	if cond is CardTypeCountCondition:
		var c := cond as CardTypeCountCondition
		return Comparison.evaluate(_count_cards_by_type(emp, c.card_type), c.op, c.count)
	if cond is HasTroopsCondition:
		return emp.troop_pool.size() >= (cond as HasTroopsCondition).min_count
	if cond is HasActiveFrontsCondition:
		return _active_front_count(state, p_owner) >= (cond as HasActiveFrontsCondition).min_count
	if cond is HasRecruitedTroopOfTypeCondition:
		var c := cond as HasRecruitedTroopOfTypeCondition
		if c.troop_type < 0:
			return false
		return int(emp.types_ever_recruited.get(c.troop_type, 0)) >= c.min_count
	if cond is UniqueEventOccurredCondition:
		return (cond as UniqueEventOccurredCondition).event_id in emp.used_unique_events
	if cond is ControlledTilesCondition:
		var c := cond as ControlledTilesCondition
		return Comparison.evaluate(_count_tiles_matching(state, p_owner, c), c.op, c.count)
	if cond is UrbanizedTilesCondition:
		var c := cond as UrbanizedTilesCondition
		return Comparison.evaluate(_count_urbanized(state, p_owner), c.op, c.count)
	if cond is BuildingCountCondition:
		var c := cond as BuildingCountCondition
		return Comparison.evaluate(_count_buildings(state, p_owner), c.op, c.count)
	if cond is TownWithBuildingsCondition:
		var c := cond as TownWithBuildingsCondition
		return _has_town_with_buildings(state, p_owner, c.min_buildings, c.op)
	if cond is HasBuildingCondition:
		return _has_building_named(state, p_owner, (cond as HasBuildingCondition).building_name)
	if cond is HasAdjacentUncontrolledCondition:
		return _has_adjacent_uncontrolled(state, p_owner,
			(cond as HasAdjacentUncontrolledCondition).required_biome_type)
	if cond is HasAdjacentEnemyCondition:
		return _has_adjacent_enemy(state, p_owner)
	# Condición base o desconocida → permisiva (igual que TurnEventCondition.is_met).
	return true


static func _count_cards_by_id(emp: AIRealState.EmpireSnap, card_id: String) -> int:
	var n := 0
	for c in emp.deck:
		if c.id == card_id:
			n += 1
	return n


static func _count_cards_by_type(emp: AIRealState.EmpireSnap, card_type: int) -> int:
	var n := 0
	for c in emp.deck:
		if c.type == card_type:
			n += 1
	return n


static func _count_tiles_matching(state: AIRealState, p_owner: int,
		cond: ControlledTilesCondition) -> int:
	var n := 0
	for id in state.tiles:
		var t := state.tiles[id] as AIRealState.TileSnap
		if t.owner != p_owner:
			continue
		if cond.required_resource != null and t.natural_resource != cond.required_resource:
			continue
		if cond.required_biome_type != -1 and t.biome != cond.required_biome_type:
			continue
		if cond.required_location_type != -1 and t.location_type != cond.required_location_type:
			continue
		n += 1
	return n


static func _count_urbanized(state: AIRealState, p_owner: int) -> int:
	var n := 0
	for id in state.tiles:
		var t := state.tiles[id] as AIRealState.TileSnap
		if t.owner == p_owner and t.location_type >= Tile.location_type.Town:
			n += 1
	return n


static func _count_buildings(state: AIRealState, p_owner: int) -> int:
	var n := 0
	for id in state.tiles:
		var t := state.tiles[id] as AIRealState.TileSnap
		if t.owner == p_owner:
			n += t.buildings.size()
	return n


static func _has_town_with_buildings(state: AIRealState, p_owner: int,
		min_buildings: int, op: int) -> bool:
	for id in state.tiles:
		var t := state.tiles[id] as AIRealState.TileSnap
		if t.owner == p_owner and t.location_type == Tile.location_type.Town:
			if Comparison.evaluate(t.buildings.size(), op, min_buildings):
				return true
	return false


static func _has_building_named(state: AIRealState, p_owner: int, building_name: String) -> bool:
	for id in state.tiles:
		var t := state.tiles[id] as AIRealState.TileSnap
		if t.owner != p_owner:
			continue
		for b in t.buildings:
			if b.name == building_name:
				return true
	return false


static func _has_adjacent_uncontrolled(state: AIRealState, p_owner: int,
		required_biome: int) -> bool:
	for id in state.tiles:
		var t := state.tiles[id] as AIRealState.TileSnap
		if t.owner != p_owner:
			continue
		for nid in t.neighbor_ids:
			var nb := state.tiles.get(nid) as AIRealState.TileSnap
			if nb != null and nb.owner == AIRealState.OWNER_NONE:
				if required_biome == -1 or nb.biome == required_biome:
					return true
	return false


## Espejo de EventContext.has_adjacent_enemy + override de progresión (turno ≥ 20).
static func _has_adjacent_enemy(state: AIRealState, p_owner: int) -> bool:
	var enemy := AIRealState.OWNER_RIVAL if p_owner == AIRealState.OWNER_SELF \
		else AIRealState.OWNER_SELF
	for id in state.tiles:
		var t := state.tiles[id] as AIRealState.TileSnap
		if t.owner != p_owner:
			continue
		for nid in t.neighbor_ids:
			var nb := state.tiles.get(nid) as AIRealState.TileSnap
			if nb != null and nb.owner == enemy:
				return true
	return state.turn_number >= 20


# ============================================================
#  Resolución (espejo de AIEventResolver sobre el snapshot)
# ============================================================

static func _resolve_event(event: TurnEvent, state: AIRealState, p_owner: int,
		rng: RandomNumberGenerator) -> void:
	var emp := _empire_of(state, p_owner)

	# La tienda se resuelve aparte (compras/purgas), igual que AIEventResolver.
	if event is ShopEvent:
		_resolve_shop(event as ShopEvent, emp, state.turn_number, rng)
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

	# Elegir la de mayor valor (skip = 0).
	var picked: TurnEventChoice = available[0]
	var best := _score_choice(available[0], emp, state)
	for i in range(1, available.size()):
		var s := _score_choice(available[i], emp, state)
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
		return int(sc.base_gold + state.turn_number * sc.turn_factor
			+ emp.gold_per_turn * sc.gpt_percent)
	return cost.gold


# ============================================================
#  Selección de choice (aproximación de AIHeuristic.score_choice)
# ============================================================

static func _score_choice(choice: TurnEventChoice, emp: AIRealState.EmpireSnap,
		state: AIRealState) -> float:
	var gu := _gold_urgency(emp.gold_per_turn)
	var fu := _food_urgency(emp.food)
	var score := 0.0
	for effect in choice.effects:
		if effect == null:
			continue
		if effect is GoldEventEffect:
			score += (effect as GoldEventEffect).amount * 0.4 * gu
		elif effect is FoodEventEffect:
			score += (effect as FoodEventEffect).amount * 0.5 * fu
		elif effect is ScaledGoldEffect:
			var e := effect as ScaledGoldEffect
			var amt := e.base + state.turn_number * e.turn_factor \
				+ emp.gold_per_turn * e.gpt_percent
			score += amt * 0.4 * gu
		elif effect is ScaledFoodEffect:
			var e := effect as ScaledFoodEffect
			var amt := e.base + state.turn_number * e.turn_factor \
				+ emp.food * e.food_percent
			score += amt * 0.5 * fu
		elif effect is AddCardEffect:
			score += 8.0
		elif effect is AddRandomPoolCardEffect:
			score += 8.0
		elif effect is AddToCardPoolEffect or effect is UnlockBuildingEffect:
			score += 10.0   # desbloqueos: amplían el espacio de acciones
		elif effect is UrbanizeToMegalopolisEffect:
			score += 28.0
		elif effect is ColonizeAdjacentEffect:
			score += 15.0
		elif effect is RemoveCardEventEffect:
			score += _deck_thinning_value(emp)
		elif effect is ScaledStatModifierEffect or effect is ScaledBuildCostModifierEffect \
				or effect is ApplyModifierEffect:
			score += 5.0
		else:
			score += 3.0
	if choice.cost != null:
		score -= 2.0
	return score


static func _gold_urgency(gpt: int) -> float:
	if gpt < 0:   return 3.0
	if gpt < 50:  return 2.0
	if gpt < 100: return 1.3
	if gpt < 200: return 1.0
	if gpt < 500: return 0.7
	return 0.35


static func _food_urgency(food: int) -> float:
	if food < 0: return 3.0
	if food < 5: return 1.5
	return 0.5


static func _deck_thinning_value(emp: AIRealState.EmpireSnap) -> float:
	# Mazo grande → purgar acelera el ciclo; mazo pequeño → poco valor.
	return clampf(float(emp.deck.size() - 10) * 0.5, 0.0, 8.0)


# ============================================================
#  Aplicación de coste y efectos (espejo sobre el snapshot)
# ============================================================

static func _apply_choice(choice: TurnEventChoice, state: AIRealState, p_owner: int,
		rng: RandomNumberGenerator) -> void:
	var emp := _empire_of(state, p_owner)
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


static func _apply_effect(effect: TurnEventEffect, state: AIRealState, p_owner: int,
		rng: RandomNumberGenerator) -> void:
	var emp := _empire_of(state, p_owner)

	if effect is GoldEventEffect:
		emp.gold += (effect as GoldEventEffect).amount
	elif effect is FoodEventEffect:
		emp.food += (effect as FoodEventEffect).amount
	elif effect is ScaledGoldEffect:
		var e := effect as ScaledGoldEffect
		emp.gold += int(e.base + state.turn_number * e.turn_factor
			+ emp.gold_per_turn * e.gpt_percent)
	elif effect is ScaledFoodEffect:
		var e := effect as ScaledFoodEffect
		emp.food += int(e.base + state.turn_number * e.turn_factor
			+ emp.food * e.food_percent)
	elif effect is ApplyModifierEffect:
		_add_modifier(emp, (effect as ApplyModifierEffect).modifier.duplicate_modifier())
	elif effect is ScaledStatModifierEffect:
		var e := effect as ScaledStatModifierEffect
		var ref_stat := _scaled_stat_reference(e, emp)
		var value := e.base_value + state.turn_number * e.turn_factor + ref_stat * e.stat_percent
		_add_modifier(emp, StatModifier.new(e.modifier_id, e.modifier_name,
			e.stat_type, value, e.duration))
	elif effect is ScaledBuildCostModifierEffect:
		var e := effect as ScaledBuildCostModifierEffect
		var percent := e.base_percent + state.turn_number * e.turn_factor
		_add_modifier(emp, BuildCostModifier.new(e.modifier_id, e.modifier_name,
			percent, e.duration))
	elif effect is AddCardEffect:
		emp.deck.append((effect as AddCardEffect).card.duplicate())
	elif effect is AddToCardPoolEffect:
		_add_to_card_pool(emp, (effect as AddToCardPoolEffect).entry)
	elif effect is AddRandomPoolCardEffect:
		var card := _weighted_pick_pool_card(emp, state.turn_number, rng)
		if card != null:
			emp.deck.append(card.duplicate())
	elif effect is UnlockBuildingEffect:
		var b := (effect as UnlockBuildingEffect).building
		if b != null and b not in emp.possible_buildings:
			emp.possible_buildings.append(b)
	elif effect is RemoveCardEventEffect:
		var e := effect as RemoveCardEventEffect
		if e.auto_filter != null:
			_filter_remove_first(e.auto_filter, emp)
		if e.player_filter != null:
			_remove_most_expendable(e.player_filter, emp)
	elif effect is ColonizeAdjacentEffect:
		_apply_colonize_adjacent(state, p_owner, (effect as ColonizeAdjacentEffect).preferred_biome, rng)
	elif effect is UrbanizeToMegalopolisEffect:
		_apply_urbanize_megalopolis(state, p_owner, (effect as UrbanizeToMegalopolisEffect).min_buildings)
	# Otros efectos sin impacto en el estado modelado → no-op.


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
	AIRealSimulator.apply_colonize(state, chosen, p_owner)


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
		var surviving := 0.0
		var demolished := 0.0
		for b in t.buildings:
			var survives := true
			if not b.allowed_location_type.is_empty():
				survives = false
				for lt in b.allowed_location_type:
					if lt.type >= Tile.location_type.Megalopolis:
						survives = true
						break
			var val := b.gold_produced * 2.0 + b.food_produced * 1.5 + b.flat_defense_bonus
			if survives:
				surviving += val
			else:
				demolished += val
		var res_val := 0.0
		if t.natural_resource != null:
			res_val = t.natural_resource.gold_produced * 1.5 + t.natural_resource.food_produced * 1.2
		var tile_score := surviving + res_val - demolished
		if tile_score > best_score:
			best_score = tile_score
			best_id = id
	if best_id >= 0:
		AIRealSimulator.apply_change_location(state, best_id, MEGALOPOLIS, p_owner)


# ============================================================
#  Tienda (F2.5c — espejo de ShopGenerator + AIEventResolver._resolve_shop_event)
# ============================================================

## Resuelve un ShopEvent sobre el snapshot: genera la oferta desde el pool de
## tienda (unlocked + exclusivas), compra los ítems que la heurística considera
## valiosos y purga las cartas más débiles. El efecto que importa es que `deck`
## refleje las compras/purgas (PLAN §3.7); la decisión exacta es suelo heurístico.
static func _resolve_shop(event: ShopEvent, emp: AIRealState.EmpireSnap,
		turn: int, rng: RandomNumberGenerator) -> void:
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
		if emp.gold >= price and _should_buy(card, emp):
			emp.gold -= price
			emp.deck.append(card.duplicate())

	# --- Purga ---
	var purge_cost := ShopGenerator._get_purge_cost(emp.total_purges_done)
	var purges_done := 0
	while not emp.deck.is_empty() and purges_done < max_purges and emp.gold >= purge_cost:
		var worst := _pick_weakest_card(emp)
		if worst == null:
			break
		if _score_card_for_deck(worst, emp) >= _purge_threshold(emp):
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


## ¿Comprar este ítem? Umbral que escala con el tamaño del mazo (espejo de
## AIHeuristic.should_buy_shop_item): mazo pequeño compra casi todo, mazo grande
## solo lo realmente valioso.
static func _should_buy(card: Card, emp: AIRealState.EmpireSnap) -> bool:
	var ratio := clampf(float(emp.deck.size() - 5) / 15.0, 0.0, 1.0)
	var threshold := lerpf(5.0, 12.0, ratio)
	return _score_card_for_deck(card, emp) >= threshold


## Umbral de purga dinámico (espejo de AIHeuristic.dynamic_purge_threshold).
static func _purge_threshold(emp: AIRealState.EmpireSnap) -> float:
	var ratio := clampf(float(emp.deck.size() - 5) / 15.0, 0.0, 1.0)
	return lerpf(3.0, 10.0, ratio)


## Carta más prescindible del mazo (menor score). Protege una ColonizeCard si es
## la única (espejo de la protección de expansión de pick_card_to_remove).
static func _pick_weakest_card(emp: AIRealState.EmpireSnap) -> Card:
	var colonize_count := 0
	for c in emp.deck:
		if c is ColonizeCard:
			colonize_count += 1
	var worst: Card = null
	var worst_score := INF
	for c in emp.deck:
		if c is ColonizeCard and colonize_count <= 1:
			continue   # conservar al menos una ColonizeCard
		var s := _score_card_for_deck(c, emp)
		if s < worst_score:
			worst_score = s
			worst = c
	return worst


## Valor aproximado de una carta para el mazo (suelo heurístico, espejo
## simplificado de AIHeuristic.score_card_for_deck sobre el snapshot: no dispone
## del detalle de tiles/urgencias de escena, así que usa magnitudes por tipo
## moduladas por urgencia económica y saturación de tipo en el mazo).
static func _score_card_for_deck(card: Card, emp: AIRealState.EmpireSnap) -> float:
	if card == null:
		return 0.0
	var gu := _gold_urgency(emp.gold_per_turn)
	var fu := _food_urgency(emp.food)
	var sat := 1.0 / (1.0 + _count_same_script(emp.deck, card) * 0.15)
	var base := 5.0
	# El orden respeta la jerarquía de score_card_for_deck (DirectBuild antes que Build).
	if card is GenerateGoldCard:
		base = (card as GenerateGoldCard).amount * 0.3 * gu
	elif card is ColonizeCard:
		base = 11.0
	elif card is DirectBuildCard:
		var db := card as DirectBuildCard
		if not db.buildings.is_empty() and db.buildings[0] != null:
			var b := db.buildings[0]
			base = b.gold_produced * 5.0 * gu + b.food_produced * 4.0 * fu \
				+ b.flat_defense_bonus * 8.0
		else:
			base = 5.0
	elif card is BuildCard:
		base = 12.0
	elif card is UpgradeBuildingCard:
		base = 10.0
	elif card is RecruitCard:
		base = 9.0
	elif card is CardDrawCard:
		base = lerpf(8.0, 14.0, clampf(float(emp.deck.size()) / 20.0, 0.0, 1.0))
	elif card is OpenFrontCard:
		base = 7.0
	elif card is TacticCard:
		base = 6.0
	elif card is ChangeLocationTypeCard:
		base = 8.0
	elif card is RecoverCard:
		base = 8.0
	return base * sat


static func _count_same_script(deck: Array[Card], card: Card) -> int:
	var script := card.get_script() as Script
	var n := 0
	for c in deck:
		if c.get_script() == script:
			n += 1
	return n


# ============================================================
#  Internals
# ============================================================

static func _empire_of(state: AIRealState, p_owner: int) -> AIRealState.EmpireSnap:
	if p_owner == AIRealState.OWNER_SELF:
		return state.own
	if p_owner == AIRealState.OWNER_RIVAL:
		return state.rival
	return null


static func _active_front_count(state: AIRealState, p_owner: int) -> int:
	var n := 0
	for f in state.fronts:
		var front := f as AIRealState.FrontSnap
		if not front.is_resolved and front.involves(p_owner):
			n += 1
	return n
