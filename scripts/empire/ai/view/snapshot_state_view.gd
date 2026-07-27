extends AIStateView
class_name SnapshotStateView

## Implementación de AIStateView sobre el SNAPSHOT puro (AIRealState). Camino
## CALIENTE del MCTS: se construye por jugada dentro de score_move (miles de veces
## por decisión), así que se mantiene barata (solo referencias + fase perezosa) y
## sin asignar wrappers por-tile. `empire()` se resuelve una vez en el ctor.

var _state: AIRealState
var _owner: int
var _w: HeuristicWeights
var _emp: AIRealState.EmpireSnap
var _phase: int = -1   # AIGamePhase.Phase perezosa (-1 = sin calcular)


func _init(state: AIRealState, owner: int, w: HeuristicWeights) -> void:
	_state = state
	_owner = owner
	_w = w
	_emp = state.empire(owner)


## True si el imperio propio existe en el snapshot; los scorers devuelven 0.0 si no.
func is_valid() -> bool:
	return _emp != null


func weights() -> HeuristicWeights:
	return _w


func gold_per_turn() -> int:
	return _emp.gold_per_turn


func food() -> int:
	return _emp.food


func phase() -> AIGamePhase.Phase:
	if _phase < 0:
		_phase = AIRealEval.detect_phase(_state, _owner)
	return _phase


func deck_urgency_size() -> int:
	return _emp.deck.size()


func gold_urgency() -> float:
	return AIUrgency.gold_urgency(_emp.gold_per_turn, phase(), _w)


func food_urgency() -> float:
	return AIUrgency.food_urgency(_emp.food, phase(), _w)


func expansion_factor() -> float:
	return AIRealEvalStrong._expansion_factor(_state, _owner, _w)


func encirclement_pressure() -> float:
	return AIRealEvalStrong._encirclement_pressure(_state, _owner, _w)


func territory_race_factor(mode: StringName) -> float:
	return AIRealEvalStrong._territory_race_factor(_state, _owner, mode, _w)


func frontier_value(tile) -> int:
	return AIRealEvalStrong._frontier_value(_state, (tile as AIRealState.TileSnap).id, _owner)


func tile_gold_production(tile) -> int:
	return (tile as AIRealState.TileSnap).gold_production()


func tile_food_production(tile) -> int:
	return (tile as AIRealState.TileSnap).food_production()


func tile_adjacent_to_rival(tile) -> bool:
	var rival := AIRealState.OWNER_RIVAL if _owner == AIRealState.OWNER_SELF else AIRealState.OWNER_SELF
	for nid in (tile as AIRealState.TileSnap).neighbor_ids:
		var nb := _state.tiles.get(nid) as AIRealState.TileSnap
		if nb != null and nb.owner == rival:
			return true
	return false


func military_urgency() -> float:
	return AIRealEvalStrong._military_urgency(_state, _owner, _w)


func gold() -> int:
	return _emp.gold


func effective_build_cost(b: Building) -> int:
	return AIRealSimulator._effective_build_cost(b, _emp)


func score_building_effects(effects: Array[BuildingEffect], gu: float, fu: float, mu: float) -> float:
	return AIRealEvalStrong._score_building_effects(effects, _state, _owner, _emp, phase(), gu, fu, mu, _w)


func tile_natural_resource(tile):
	return (tile as AIRealState.TileSnap).natural_resource


func tile_adjacent_to_enemy(tile) -> bool:
	var enemy := AIRealState.OWNER_RIVAL if _owner == AIRealState.OWNER_SELF else AIRealState.OWNER_SELF
	for nid in (tile as AIRealState.TileSnap).neighbor_ids:
		var nb := _state.tiles.get(nid) as AIRealState.TileSnap
		if nb != null and nb.owner == enemy:
			return true
	return false


func troop_pool() -> Array[Troop]:
	return _emp.troop_pool


func resource_surplus_factor() -> float:
	return AIRealEvalStrong._resource_surplus_factor(_emp, phase(), _w)


func complement_bonus(troop: Troop) -> float:
	return AIRealEvalStrong._complement_bonus(troop, _emp.troop_pool, _state, _owner, _w)


func recruit_front_max_troops() -> int:
	# Gate del snapshot: participamos en algún frente activo (has_front).
	var has_front := false
	var max_own := 0
	for f in _state.fronts:
		var front := f as AIRealState.FrontSnap
		if front.is_resolved:
			continue
		var side := front.side_of(_owner)
		if side == BattleFront.Side.NONE:
			continue
		has_front = true
		var side_troops := front.attacker_troops if side == BattleFront.Side.ATTACKER else front.defender_troops
		max_own = maxi(max_own, side_troops.size())
	return max_own if has_front else -1


func tile_resource_gold(tile) -> int:
	return (tile as AIRealState.TileSnap).resource_gold


func tile_resource_food(tile) -> int:
	return (tile as AIRealState.TileSnap).resource_food


func tile_attack_biome_factor(tile) -> float:
	return AIRealSimulator._biome().get_attack_multiplier((tile as AIRealState.TileSnap).biome)


func open_front_source_value(source_tile) -> float:
	if source_tile == null:
		return 0.0
	var source := source_tile as AIRealState.TileSnap
	return float(source.buildings.size()) * _w.openfront_source_building \
		+ float(source.resource_gold) * _w.openfront_source_gold \
		+ float(source.resource_food) * _w.openfront_source_food


func tile_food_consumption(tile) -> int:
	return (tile as AIRealState.TileSnap).food_consumption


func tile_max_buildings(tile) -> int:
	return (tile as AIRealState.TileSnap).max_buildings


func change_location_adjust(base: float, tile, new_loc, gu: float, fu: float, _mu: float) -> float:
	# Aproximación-suelo del snapshot: solo penalización por demolición (omite los
	# bonos de recurso mejorado y de desbloqueo, acoplados a escena en el mundo vivo).
	var t := tile as AIRealState.TileSnap
	var loc := new_loc as LocationType
	var demolished_penalty := 0.0
	for building in t.buildings:
		if building == null:
			continue
		if not AIRealSimulator._building_survives(building, loc.type):
			demolished_penalty += float(building.gold_produced) * _w.changeloc_demo_gold * gu \
				+ float(building.food_produced) * _w.changeloc_demo_food * fu \
				+ float(building.flat_defense_bonus) * _w.changeloc_demo_defense
	return base - demolished_penalty


func open_front_win_factor(enemy_tile, biome_factor: float) -> float:
	var e := enemy_tile as AIRealState.TileSnap
	var enemy := AIRealState.OWNER_RIVAL if _owner == AIRealState.OWNER_SELF else AIRealState.OWNER_SELF
	var win_factor := _w.openfront_win_default
	var own_atk := 0.0
	for t in _emp.troop_pool:
		own_atk += float(t.attack)
	own_atk *= biome_factor
	var rival_def := 0.0
	for b in e.buildings:
		if b != null:
			rival_def += float(b.flat_defense_bonus)
	rival_def *= AIRealSimulator._biome().get_defense_multiplier(e.biome)
	for f in _state.fronts:
		var front := f as AIRealState.FrontSnap
		if front.is_resolved:
			continue
		if front.defender_tile_id == e.id and front.defender_owner == enemy:
			for t in front.defender_troops:
				rival_def += float(t.defense)
			break
	if own_atk + rival_def > 0.0:
		var ratio := own_atk / maxf(rival_def, 1.0)
		win_factor = clampf(ratio / (ratio + 1.0), _w.openfront_win_min, _w.openfront_win_max)
	else:
		win_factor = _w.openfront_win_neutral
	return win_factor
