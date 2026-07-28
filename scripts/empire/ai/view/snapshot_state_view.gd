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


## `w` es opcional: la ENUMERACIÓN de jugadas (AIRealOptions) no usa pesos, solo
## legalidad; el scoring (AIMoveScorer) sí pasa el `w` del config.
func _init(state: AIRealState, owner: int, w: HeuristicWeights = null) -> void:
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
	# Se pasa `self` para que la rama AddCardToDeckEffect valore la carta con
	# AIDeckScorer sin asignar otra vista en el camino caliente (C6 §1.6.5b).
	return AIRealEvalStrong._score_building_effects(effects, _state, _owner, _emp, phase(), gu, fu, mu, _w, self)


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


func troops_per_recruit_bonus(troop: Troop) -> int:
	return ModifierQuery.troops_per_recruit_bonus(_emp.modifiers, troop)


func owned_tiles() -> Array:
	var result: Array = []
	for id in _state.tiles:
		var t := _state.tiles[id] as AIRealState.TileSnap
		if t.owner == _owner:
			result.append(t)
	return result


func can_build(tile, building: Building) -> bool:
	return (tile as AIRealState.TileSnap).can_build(building)


func tile_buildings(tile) -> Array[Building]:
	return (tile as AIRealState.TileSnap).buildings


## Edificios construibles del imperio (refleja unlocks). Solo el snapshot lo usa: el
## enumerador BUILD del vivo parte de card.buildings.
func possible_buildings() -> Array[Building]:
	return _emp.possible_buildings


func can_be_upgraded(_old_building: Building) -> bool:
	# El snapshot no comprueba old.can_be_upgraded (divergencia con el vivo).
	return true


## Espejo de Tile.can_upgrade sobre el snapshot (compara LocationType por enum, no
## por objeto). Sin la comprobación de coste, que se filtra aparte.
func can_upgrade(tile, old_building: Building, new_building: Building) -> bool:
	var t := tile as AIRealState.TileSnap
	if new_building not in old_building.upgrades_to:
		return false
	if not new_building.allowed_biomes.is_empty() and t.biome not in new_building.allowed_biomes:
		return false
	if new_building.required_natural_resource != null \
			and t.natural_resource != new_building.required_natural_resource:
		return false
	if not new_building.allowed_location_type.is_empty():
		var fits := false
		for lt in new_building.allowed_location_type:
			if lt.type == t.location_type:
				fits = true
				break
		if not fits:
			return false
	return true


func colonizable_tiles() -> Array:
	# Recorrido propio→vecinos libres con dedup (primer visto), como AdjacentRule.
	var seen := {}
	var result: Array = []
	for id in _state.tiles:
		var t := _state.tiles[id] as AIRealState.TileSnap
		if t.owner != _owner:
			continue
		for nid in t.neighbor_ids:
			if seen.has(nid):
				continue
			var nb := _state.tiles.get(nid) as AIRealState.TileSnap
			if nb != null and nb.owner == AIRealState.OWNER_NONE:
				seen[nid] = true
				result.append(nb)
	return result


func tile_location_type(tile) -> int:
	return (tile as AIRealState.TileSnap).location_type


func open_front_pairs(_card) -> Array:
	if AIRealSimulator._active_front_count(_state, _owner) \
			>= AIRealSimulator._get_max_fronts(_state, _owner):
		return []
	var enemy := AIRealState.OWNER_RIVAL if _owner == AIRealState.OWNER_SELF \
		else AIRealState.OWNER_SELF
	var result: Array = []
	for id in _state.tiles:
		var t := _state.tiles[id] as AIRealState.TileSnap
		if t.owner != _owner or _tile_in_front(id):
			continue
		for nid in t.neighbor_ids:
			var nb := _state.tiles.get(nid) as AIRealState.TileSnap
			if nb == null or nb.owner != enemy or _tile_in_front(nid):
				continue
			result.append({"source": t, "def": nb})
	return result


func tactic_targets() -> Array:
	var result: Array = []
	for i in range(_state.fronts.size()):
		var front := _state.fronts[i] as AIRealState.FrontSnap
		if front.is_resolved or front.side_of(_owner) == BattleFront.Side.NONE:
			continue
		result.append(i)
	return result


func _tile_in_front(tile_id: int) -> bool:
	for f in _state.fronts:
		var front := f as AIRealState.FrontSnap
		if front.is_resolved:
			continue
		if front.attacker_tile_id == tile_id or front.defender_tile_id == tile_id:
			return true
	return false


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


# --- valoración de carta para el mazo (C6 §1.6.5b) ---
# El snapshot modela un ÚNICO mazo combinado (emp.deck), mientras el vivo separa
# draw/discard; ambas medidas representan "el mazo activo" en su mundo.

func same_type_card_count(card: Card) -> int:
	var script := card.get_script() as Script
	var count := 0
	for c in _emp.deck:
		if c != null and c.get_script() == script:
			count += 1
	return maxi(count, 1)   # ≥1, igual que el vivo (evita dividir por cero)


func colonizable_count() -> int:
	return AIRealEvalStrong._colonizable_count(_state, _owner)


func upgradeable_count() -> int:
	var count := 0
	for id in _state.tiles:
		var t := _state.tiles[id] as AIRealState.TileSnap
		if t.owner != _owner:
			continue
		for building in t.buildings:
			if building != null and not building.upgrades_to.is_empty():
				count += 1
	return count


func buildable_slots() -> int:
	var total := 0
	for id in _state.tiles:
		var t := _state.tiles[id] as AIRealState.TileSnap
		if t.owner == _owner:
			total += maxi(0, t.max_buildings - t.buildings.size())
	return total


func change_location_target_count(target_type: int) -> int:
	var count := 0
	for id in _state.tiles:
		var t := _state.tiles[id] as AIRealState.TileSnap
		if t.owner == _owner and t.location_type + 1 == target_type:
			count += 1
	return count


func deck_size() -> int:
	return _emp.deck.size()


func recoverable_cards() -> Array[Card]:
	return _emp.deck


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
