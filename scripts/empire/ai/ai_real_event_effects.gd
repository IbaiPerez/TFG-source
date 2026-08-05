extends RefCounted
class_name AIRealEventEffects

## Cobro del coste y aplicación de los efectos de un evento sobre el snapshot.
##
## El despacho es una tabla `Script → Callable`, no una cadena de `if effect is`:
## los 14 efectos extienden TurnEventEffect DIRECTAMENTE, así que casar por tipo
## exacto es equivalente y no degrada con el número de efectos.
##
## Los efectos de CASILLA (colonizar adyacente, urbanizar a megalópolis) son
## propios del snapshot a propósito y no reusan los del juego: los reales mutan
## vía el bus `Events`, que aquí dispararía los trackers de la partida en curso,
## y además difieren en el RNG (global `pick_random` frente al inyectado y
## determinista del MCTS) y en quién elige la casilla.

const MEGALOPOLIS: LocationType = preload("res://resources/location_type/megalopolis.tres")


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
	_effect_handlers[GoldEventEffect]              = Callable(AIRealEventEffects, "_eff_gold")
	_effect_handlers[FoodEventEffect]              = Callable(AIRealEventEffects, "_eff_food")
	_effect_handlers[ScaledGoldEffect]             = Callable(AIRealEventEffects, "_eff_scaled_gold")
	_effect_handlers[ScaledFoodEffect]             = Callable(AIRealEventEffects, "_eff_scaled_food")
	_effect_handlers[ApplyModifierEffect]          = Callable(AIRealEventEffects, "_eff_apply_modifier")
	_effect_handlers[ScaledStatModifierEffect]     = Callable(AIRealEventEffects, "_eff_scaled_stat_modifier")
	_effect_handlers[ScaledBuildCostModifierEffect] = Callable(AIRealEventEffects, "_eff_scaled_build_cost")
	_effect_handlers[AddCardEffect]                = Callable(AIRealEventEffects, "_eff_add_card")
	_effect_handlers[AddToCardPoolEffect]          = Callable(AIRealEventEffects, "_eff_add_to_pool")
	_effect_handlers[AddRandomPoolCardEffect]      = Callable(AIRealEventEffects, "_eff_add_random_pool_card")
	_effect_handlers[UnlockBuildingEffect]         = Callable(AIRealEventEffects, "_eff_unlock_building")
	_effect_handlers[RemoveCardEventEffect]        = Callable(AIRealEventEffects, "_eff_remove_card")
	_effect_handlers[ColonizeAdjacentEffect]       = Callable(AIRealEventEffects, "_eff_colonize_adjacent")
	_effect_handlers[UrbanizeToMegalopolisEffect]  = Callable(AIRealEventEffects, "_eff_urbanize")


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
