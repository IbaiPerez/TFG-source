extends AIStateView
class_name LiveStateView

## Implementación de AIStateView sobre el estado VIVO (AITurnContext: Stats/Tile/
## BattleFront). Camino frío: la heurística real (AIHeuristic) la usa para los priors
## de la raíz, una vez por decisión, así que el coste de construirla es irrelevante.

var _ctx: AITurnContext


func _init(ctx: AITurnContext) -> void:
	_ctx = ctx


func weights() -> HeuristicWeights:
	return _ctx.get_weights()


func gold_per_turn() -> int:
	return _ctx.stats.gold_per_turn


func food() -> int:
	return _ctx.stats.food


func phase() -> AIGamePhase.Phase:
	return AIGamePhase.detect(_ctx.stats, _ctx.total_map_tiles, weights())


func turn_number() -> int:
	return _ctx.stats.turn_number if _ctx.stats != null else 0


func deck_urgency_size() -> int:
	return _ctx.stats.draw_pile.cards.size() if _ctx.stats.draw_pile else 0


func gold_urgency() -> float:
	return _ctx._cache_gu if _ctx._cache_valid \
		else AIUrgency.gold_urgency(_ctx.stats.gold_per_turn, phase(), weights())


func food_urgency() -> float:
	return _ctx._cache_fu if _ctx._cache_valid \
		else AIUrgency.food_urgency(_ctx.stats.food, phase(), weights())


func expansion_factor() -> float:
	return _ctx._cache_expansion if _ctx._cache_valid \
		else AITerritory.expansion_factor(_ctx.colonizable_tiles_count, weights())


func encirclement_pressure() -> float:
	return AILiveFacts._encirclement_pressure(_ctx)


func territory_race_factor(mode: StringName) -> float:
	return AILiveFacts._territory_race_factor(_ctx, mode)


func frontier_value(tile) -> int:
	return AILiveFacts._frontier_value(tile as Tile, _ctx)


func neighbor_bonus_yield(b: Building, tile) -> Vector2i:
	return AILiveFacts._neighbor_bonus_yield(b, tile as Tile)


func tile_gold_production(tile) -> int:
	return (tile as Tile).gold_production


func tile_food_production(tile) -> int:
	return (tile as Tile).food_production


func tile_adjacent_to_rival(tile) -> bool:
	if _ctx.world_view == null:
		return false
	var rival := _ctx.world_view.get_rival_view()
	if rival == null or rival.empire == null:
		return false
	for nb in (tile as Tile).neighbors:
		var nt := nb as Tile
		if nt != null and nt.controller == rival.empire:
			return true
	return false


func military_urgency() -> float:
	return _ctx._cache_mu if _ctx._cache_valid else AIDecisionCache._military_urgency(_ctx, phase())


func gold() -> int:
	return _ctx.stats.total_gold


func effective_build_cost(b: Building) -> int:
	return b.get_effective_construction_cost(_ctx.stats)


func score_building_effects(effects: Array[BuildingEffect], _gu: float, _fu: float, _mu: float) -> float:
	# El valorador vivo recalcula gu/fu/mu internamente (mismos valores) → se ignoran.
	return AIHeuristic._score_building_effects(effects, _ctx, phase())


func tile_natural_resource(tile):
	return (tile as Tile).natural_resource


func tile_adjacent_to_enemy(tile) -> bool:
	for nb in (tile as Tile).neighbors:
		var nt := nb as Tile
		if nt != null and nt.controller != null and nt.controller != _ctx.stats.empire:
			return true
	return false


func troop_pool() -> Array[Troop]:
	return _ctx.stats.troop_pool


func resource_surplus_factor() -> float:
	return _ctx._cache_surplus if _ctx._cache_valid \
		else AILiveFacts._resource_surplus_factor(_ctx, phase())


func complement_bonus(troop: Troop) -> float:
	return AILiveFacts._complement_bonus(troop, _ctx.stats.troop_pool, _ctx)


func troops_per_recruit_bonus(troop: Troop) -> int:
	# Espejo del guarda de RecruitCard.get_effective_troops_per_play: sin
	# modifier_manager (tests) el bonus es 0.
	if _ctx.stats == null or _ctx.stats.modifier_manager == null:
		return 0
	return _ctx.stats.modifier_manager.get_troops_per_recruit_bonus(troop)


func owned_tiles() -> Array:
	return _ctx.stats.empire.controlled_tiles


func can_build(tile, building: Building) -> bool:
	return (tile as Tile).can_build(building)


func tile_buildings(tile) -> Array[Building]:
	return (tile as Tile).buildings


func can_be_upgraded(old_building: Building) -> bool:
	return old_building.can_be_upgraded(_ctx.stats)


func can_upgrade(tile, old_building: Building, new_building: Building) -> bool:
	return (tile as Tile).can_upgrade(old_building, new_building)


func colonizable_tiles() -> Array:
	# Mismo mecanismo que ColonizeCard.get_valid_targets: AdjacentRule sobre el imperio.
	var rule := AdjacentRule.new()
	rule.empire = _ctx.stats.empire
	return rule.valid_targets()


func tile_location_type(tile) -> int:
	return (tile as Tile).location.type


func open_front_pairs(card) -> Array:
	var bfm = _ctx.battle_front_manager
	if bfm == null:
		return []
	if not bfm.can_open_front():
		return []
	# Inyectar el bfm en la carta para que EnemyAdjacentRule filtre tiles ya en frente
	# (mismo efecto colateral que el enumerador original).
	(card as OpenFrontCard).battle_front_manager = bfm
	var result: Array = []
	for enemy in (card as OpenFrontCard).get_valid_targets(_ctx.stats):
		for neighbor in (enemy as Tile).neighbors:
			if neighbor == null:
				continue
			if neighbor.controller != _ctx.stats.empire:
				continue
			if _ctx.get_front_registry().is_tile_in_active_front(neighbor):
				continue
			result.append({"source": neighbor as Tile, "def": enemy as Tile})
	return result


func tactic_targets() -> Array:
	var result: Array = []
	if _ctx.battle_front_manager == null:
		return result
	for front in _ctx.battle_front_manager.active_fronts:
		if front == null or front.is_resolved:
			continue
		if front.attacker_empire == _ctx.stats.empire \
				or front.defender_empire == _ctx.stats.empire:
			result.append(front)
	return result


func recruit_front_max_troops() -> int:
	# Gate del vivo: cualquier frente activo (caché=todos, o los propios sin caché).
	var fronts := _ctx._cache_active_fronts if _ctx._cache_valid \
		else AIDecisionCache._get_own_active_fronts(_ctx)
	if fronts.is_empty():
		return -1
	var max_own := 0
	for front in fronts:
		var is_att := front.attacker_empire == _ctx.stats.empire
		var is_def := front.defender_empire == _ctx.stats.empire
		if not is_att and not is_def:
			continue
		var side_troops: Array[Troop] = front.attacker_troops if is_att else front.defender_troops
		max_own = maxi(max_own, side_troops.size())
	return max_own


func tile_resource_gold(tile) -> int:
	var t := tile as Tile
	return t.natural_resource.gold_produced if t.natural_resource != null else 0


func tile_resource_food(tile) -> int:
	var t := tile as Tile
	return t.natural_resource.food_produced if t.natural_resource != null else 0


func tile_attack_biome_factor(tile) -> float:
	return AILiveFacts._attack_biome_factor(tile as Tile)


func open_front_source_value(source_tile) -> float:
	if source_tile == null:
		return 0.0
	var source := source_tile as Tile
	var sv := float(source.buildings.size()) * _ctx.get_weights().openfront_source_building
	if source.natural_resource != null:
		sv += source.natural_resource.gold_produced * _ctx.get_weights().openfront_source_gold \
			+ source.natural_resource.food_produced * _ctx.get_weights().openfront_source_food
	return sv


func tile_food_consumption(tile) -> int:
	return (tile as Tile).location.food_consumption


func tile_max_buildings(tile) -> int:
	return (tile as Tile).location.max_building


func change_location_adjust(base: float, tile, new_loc, gu: float, fu: float, mu: float) -> float:
	var t := tile as Tile
	var loc := new_loc as LocationType
	var old_loc := t.location
	var w := weights()
	# Penalización por edificios que serán demolidos + bonus de recurso mejorado que
	# sobrevive + bonus de edificios desbloueados en el nuevo tier (fórmula completa).
	var demolished_penalty := 0.0
	var resource_building_survives := false
	for building in t.buildings:
		if building == null:
			continue
		if AILiveFacts._building_demolished_by(building, loc):
			demolished_penalty += building.gold_produced * w.changeloc_demo_gold * gu \
							  + building.food_produced * w.changeloc_demo_food * fu \
							  + float(building.flat_defense_bonus) * w.changeloc_demo_defense
		else:
			if AILiveFacts._is_upgraded_resource_building(building, t, _ctx):
				resource_building_survives = true
	var resource_bonus := w.changeloc_resource_bonus if resource_building_survives else 0.0
	var unlock_bonus := AILiveFacts._score_unlocked_buildings(t, old_loc, loc, _ctx, gu, fu, mu)
	return base - demolished_penalty + resource_bonus + unlock_bonus


func same_type_card_count(card: Card) -> int:
	return AILiveFacts._card_type_count(card, _ctx)


func colonizable_count() -> int:
	return _ctx.colonizable_tiles_count


func upgradeable_count() -> int:
	return AILiveFacts._upgradeable_buildings(_ctx)


func buildable_slots() -> int:
	return AILiveFacts._buildable_slots(_ctx)


func change_location_target_count(target_type: int) -> int:
	var count := 0
	for t in _ctx.stats.empire.controlled_tiles:
		if t.location != null and t.location.type + 1 == target_type:
			count += 1
	return count


func deck_size() -> int:
	return AILiveFacts._current_deck_size(_ctx)


func recoverable_cards() -> Array[Card]:
	var result: Array[Card] = []
	if _ctx.stats == null:
		return result
	if _ctx.stats.draw_pile:
		result.append_array(_ctx.stats.draw_pile.cards)
	if _ctx.stats.discard_pile:
		result.append_array(_ctx.stats.discard_pile.cards)
	return result


## Penalización de combate por déficit económico. 1.0 si no hay imperio (tests
## aislados), que es el valor neutro del propio Empire.
func _combat_multiplier_of(e: Empire) -> float:
	return e.combat_multiplier if e != null else 1.0


func open_front_win_factor(enemy_tile, biome_factor: float) -> float:
	var w := weights()
	var win_factor := w.openfront_win_default
	if _ctx.world_view == null:
		return win_factor
	var rival := _ctx.world_view.get_rival_view()
	if rival == null or rival.empire == null:
		return win_factor
	var e := enemy_tile as Tile
	var own_atk := 0.0
	for t in _ctx.stats.troop_pool:
		own_atk += float(t.attack)
	# Espejo de CombatMath.total_attack: el ataque de TROPAS pasa por el bioma y
	# por la penalización económica del imperio.
	own_atk *= biome_factor * _combat_multiplier_of(_ctx.stats.empire)
	var rival_def := 0.0
	for b in e.buildings:
		if b != null:
			rival_def += float(b.flat_defense_bonus)
	var biome_def := 1.0
	if e.mesh_data != null:
		biome_def = BiomeConfig.shared().get_defense_multiplier(e.mesh_data.type)
	var rival_troop_def := 0.0
	var all_fronts := _ctx._cache_active_fronts if _ctx._cache_valid \
		else _ctx.get_front_registry().get_active_instances()
	for front in all_fronts:
		if front.is_resolved:
			continue
		if front.defender_tile == e and front.defender_empire == rival.empire:
			for t in front.defender_troops:
				rival_troop_def += float(t.defense)
			break
	# Espejo de CombatMath.total_defense: los edificios quedan PLANOS y solo la
	# defensa de tropas pasa por el bioma y por la penalización económica.
	rival_def += rival_troop_def * biome_def * _combat_multiplier_of(rival.empire)
	if own_atk + rival_def > 0.0:
		var ratio := own_atk / maxf(rival_def, 1.0)
		return clampf(ratio / (ratio + 1.0), w.openfront_win_min, w.openfront_win_max)
	return w.openfront_win_neutral
