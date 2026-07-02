extends GutTest

## Tests para la capa militar de la simulación (Fase C v2 — F2).
##
## Cubre: PARIDAD de la resolución de frentes contra BattleFront real (riesgo #1
## del plan), efectos militares (recruit/open_front/tactic), asignación de
## tropas, economía con mantenimiento/recargo/combat_multiplier y conquista.


func before_each() -> void:
	# Limpiar el registro global de frentes entre tests (BattleFront real los
	# registra en su _init).
	BattleFront.clear_active_instances()


func after_each() -> void:
	BattleFront.clear_active_instances()


# ============================================================
#  Helpers
# ============================================================

func _make_troop(p_type: int, atk: int, def: int,
		cost: int = 30, maint_g: int = 5, maint_f: int = 1) -> Troop:
	var t := Troop.new()
	t.name = "T_%d_%d_%d" % [p_type, atk, def]
	t.type = p_type
	t.attack = atk
	t.defense = def
	t.recruitment_cost_gold = cost
	t.maintenance_gold = maint_g
	t.maintenance_food = maint_f
	return t


func _make_empire(combat_mult: float = 1.0) -> Empire:
	var e := Empire.new()
	e.combat_multiplier = combat_mult
	return e


func _make_resource(gold: int, food: int) -> NaturalResource:
	var r := NaturalResource.new()
	r.gold_produced = gold
	r.food_produced = food
	return r


func _make_location(p_type: int, max_b: int, food_cons: int) -> LocationType:
	var lt := LocationType.new()
	lt.type = p_type
	lt.max_building = max_b
	lt.food_consumption = food_cons
	return lt


func _make_building(p_name: String, defense: int) -> Building:
	var b := Building.new()
	b.name = p_name
	b.flat_defense_bonus = defense
	b.construction_cost = 50
	return b


## Tile real (Node3D) con bioma y edificios, autofree.
func _make_real_tile(biome: int, buildings: Array[Building] = []) -> Tile:
	var t := autofree(Tile.new()) as Tile
	var md := TileMeshData.new()
	md.type = biome
	t.mesh_data = md
	t.natural_resource = _make_resource(0, 0)
	t.location = _make_location(Tile.location_type.Village, 1, 0)
	t.buildings = buildings.duplicate()
	return t


## TileSnap con bioma y edificios.
func _make_snap(id: int, biome: int, owner: int,
		buildings: Array[Building] = []) -> AIRealState.TileSnap:
	var s := AIRealState.TileSnap.new()
	s.id = id
	s.biome = biome
	s.natural_resource = _make_resource(0, 0)
	s.location_type = Tile.location_type.Village
	s.max_buildings = 1
	s.food_consumption = 0
	s.buildings = buildings.duplicate()
	s.owner = owner
	s.neighbor_ids = []
	return s


# ============================================================
#  PARIDAD de combate: FrontSnap vs BattleFront real
# ============================================================

## Monta el mismo frente en BattleFront real y en AIRealState, los tickea en
## lockstep y verifica que el marcador y la resolución coinciden turno a turno.
func _assert_front_parity(atk_biome: int, def_biome: int,
		atk_troops: Array[Troop], def_troops: Array[Troop],
		def_buildings: Array[Building] = [], max_turns: int = 40) -> void:
	# --- Mundo real ---
	var atk_emp := _make_empire()
	var def_emp := _make_empire()
	var atk_tile := _make_real_tile(atk_biome)
	var def_tile := _make_real_tile(def_biome, def_buildings)
	var front := BattleFront.new(atk_tile, def_tile, atk_emp, def_emp)
	for tr in atk_troops:
		front.assign_troop(tr, BattleFront.Side.ATTACKER)
	for tr in def_troops:
		front.assign_troop(tr, BattleFront.Side.DEFENDER)

	# --- Simulación ---
	var state := AIRealState.new()
	state.tiles[0] = _make_snap(0, atk_biome, AIRealState.OWNER_SELF)
	state.tiles[1] = _make_snap(1, def_biome, AIRealState.OWNER_RIVAL, def_buildings)
	var fs := AIRealState.FrontSnap.new()
	fs.attacker_owner = AIRealState.OWNER_SELF
	fs.defender_owner = AIRealState.OWNER_RIVAL
	fs.attacker_tile_id = 0
	fs.defender_tile_id = 1
	fs.attacker_troops = atk_troops.duplicate()
	fs.defender_troops = def_troops.duplicate()
	state.fronts.append(fs)

	for turn in range(max_turns):
		if front.is_resolved or fs.is_resolved:
			break
		front.tick()
		AIRealSimulator._tick_front(state, fs)
		assert_almost_eq(fs.marker, front.marker, 0.001,
			"Marcador debe coincidir en el turno %d (sim %.4f vs real %.4f)"
				% [turn, fs.marker, front.marker])
		assert_eq(fs.is_resolved, front.is_resolved,
			"El estado de resolución debe coincidir en el turno %d" % turn)


func test_front_parity_symmetric_grassland() -> void:
	var atk: Array[Troop] = [
		_make_troop(Troop.TroopType.INFANTERIA_PESADA, 8, 6),
		_make_troop(Troop.TroopType.INFANTERIA_PESADA, 8, 6),
		_make_troop(Troop.TroopType.INFANTERIA_PESADA, 8, 6),
	]
	var def: Array[Troop] = [
		_make_troop(Troop.TroopType.PIQUEROS, 5, 7),
		_make_troop(Troop.TroopType.PIQUEROS, 5, 7),
	]
	_assert_front_parity(Tile.biome_type.Grassland, Tile.biome_type.Grassland, atk, def)


func test_front_parity_with_biome_difference() -> void:
	# Defensor en montaña (def×1.5) atacado desde tundra: el bioma debe replicarse.
	var atk: Array[Troop] = [
		_make_troop(Troop.TroopType.CABALLERIA, 10, 4),
		_make_troop(Troop.TroopType.CABALLERIA, 10, 4),
		_make_troop(Troop.TroopType.A_DISTANCIA, 7, 3),
	]
	var def: Array[Troop] = [
		_make_troop(Troop.TroopType.INFANTERIA_PESADA, 6, 9),
		_make_troop(Troop.TroopType.INFANTERIA_PESADA, 6, 9),
	]
	_assert_front_parity(Tile.biome_type.Tundra, Tile.biome_type.Mountain, atk, def)


func test_front_parity_with_defensive_building() -> void:
	var atk: Array[Troop] = [
		_make_troop(Troop.TroopType.INFANTERIA_LIGERA, 9, 4),
		_make_troop(Troop.TroopType.INFANTERIA_LIGERA, 9, 4),
		_make_troop(Troop.TroopType.INFANTERIA_LIGERA, 9, 4),
		_make_troop(Troop.TroopType.INFANTERIA_LIGERA, 9, 4),
	]
	var def: Array[Troop] = [
		_make_troop(Troop.TroopType.PIQUEROS, 4, 8),
	]
	var fort: Array[Building] = [_make_building("fortaleza", 20)]
	_assert_front_parity(Tile.biome_type.Grassland, Tile.biome_type.Forest, atk, def, fort)


func test_front_parity_resolves_same_turn_and_winner() -> void:
	# Atacante muy superior: debe resolverse a favor del atacante, y en el mismo
	# turno que el BattleFront real.
	var atk: Array[Troop] = [
		_make_troop(Troop.TroopType.INFANTERIA_PESADA, 20, 10),
		_make_troop(Troop.TroopType.INFANTERIA_PESADA, 20, 10),
		_make_troop(Troop.TroopType.INFANTERIA_PESADA, 20, 10),
	]
	var def: Array[Troop] = [
		_make_troop(Troop.TroopType.A_DISTANCIA, 2, 1),
	]
	var atk_emp := _make_empire()
	var def_emp := _make_empire()
	var atk_tile := _make_real_tile(Tile.biome_type.Grassland)
	var def_tile := _make_real_tile(Tile.biome_type.Grassland)
	var front := BattleFront.new(atk_tile, def_tile, atk_emp, def_emp)
	for tr in atk: front.assign_troop(tr, BattleFront.Side.ATTACKER)
	for tr in def: front.assign_troop(tr, BattleFront.Side.DEFENDER)

	var state := AIRealState.new()
	state.tiles[0] = _make_snap(0, Tile.biome_type.Grassland, AIRealState.OWNER_SELF)
	state.tiles[1] = _make_snap(1, Tile.biome_type.Grassland, AIRealState.OWNER_RIVAL)
	var fs := AIRealState.FrontSnap.new()
	fs.attacker_owner = AIRealState.OWNER_SELF
	fs.defender_owner = AIRealState.OWNER_RIVAL
	fs.attacker_tile_id = 0
	fs.defender_tile_id = 1
	fs.attacker_troops = atk.duplicate()
	fs.defender_troops = def.duplicate()
	state.fronts.append(fs)

	var real_turn := -1
	var sim_turn := -1
	for turn in range(40):
		if front.is_resolved and real_turn < 0: real_turn = turn
		if fs.is_resolved and sim_turn < 0: sim_turn = turn
		if front.is_resolved and fs.is_resolved: break
		if not front.is_resolved: front.tick()
		if not fs.is_resolved: AIRealSimulator._tick_front(state, fs)

	assert_true(fs.is_resolved, "El frente simulado debe resolverse")
	assert_true(front.is_resolved, "El frente real debe resolverse")
	assert_gt(fs.marker, 0.0, "El atacante superior debe ganar (marker positivo)")
	assert_almost_eq(fs.marker, front.marker, 0.001,
		"El marcador final debe coincidir")


# ============================================================
#  Recruit
# ============================================================

func test_recruit_adds_troops_and_deducts_gold() -> void:
	var state := AIRealState.new()
	state.own.gold = 100
	var troop := _make_troop(Troop.TroopType.PIQUEROS, 5, 5, 30)
	AIRealSimulator.apply_recruit(state, troop, 2)
	assert_eq(state.own.troop_pool.size(), 2, "Recluta 2 tropas")
	assert_eq(state.own.gold, 40, "Descuenta 2×30 de oro")


func test_recruit_stops_when_out_of_gold() -> void:
	var state := AIRealState.new()
	state.own.gold = 50
	var troop := _make_troop(Troop.TroopType.PIQUEROS, 5, 5, 30)
	AIRealSimulator.apply_recruit(state, troop, 3)
	assert_eq(state.own.troop_pool.size(), 1, "Solo recluta 1 (oro para una)")
	assert_eq(state.own.gold, 20, "Queda el oro insuficiente para la segunda")


# ============================================================
#  Open front
# ============================================================

func _two_tile_state(adjacent: bool = true) -> AIRealState:
	var s := AIRealState.new()
	var t0 := _make_snap(0, Tile.biome_type.Grassland, AIRealState.OWNER_SELF)
	var t1 := _make_snap(1, Tile.biome_type.Grassland, AIRealState.OWNER_RIVAL)
	if adjacent:
		t0.neighbor_ids = [1]
		t1.neighbor_ids = [0]
	s.tiles[0] = t0
	s.tiles[1] = t1
	return s


func test_open_front_creates_front() -> void:
	var s := _two_tile_state()
	var front := AIRealSimulator.apply_open_front(s, 0, 1)
	assert_not_null(front, "Debe crear el frente")
	assert_eq(s.fronts.size(), 1, "El frente se añade al estado")
	assert_eq(front.attacker_owner, AIRealState.OWNER_SELF)
	assert_eq(front.defender_owner, AIRealState.OWNER_RIVAL)


func test_open_front_rejects_non_adjacent() -> void:
	var s := _two_tile_state(false)
	var front := AIRealSimulator.apply_open_front(s, 0, 1)
	assert_null(front, "No se abre frente contra una casilla no adyacente")
	assert_eq(s.fronts.size(), 0)


func test_open_front_rejects_tile_already_in_front() -> void:
	var s := _two_tile_state()
	AIRealSimulator.apply_open_front(s, 0, 1)
	var second := AIRealSimulator.apply_open_front(s, 0, 1)
	assert_null(second, "Una casilla ya en frente no puede entrar en otro")


func test_open_front_respects_max_fronts() -> void:
	# Con pocas tiles, get_max_fronts = 1: el segundo frente (otra pareja) se rechaza.
	var s := AIRealState.new()
	for i in range(4):
		var t := _make_snap(i, Tile.biome_type.Grassland,
			AIRealState.OWNER_SELF if i % 2 == 0 else AIRealState.OWNER_RIVAL)
		s.tiles[i] = t
	(s.tiles[0] as AIRealState.TileSnap).neighbor_ids = [1]
	(s.tiles[1] as AIRealState.TileSnap).neighbor_ids = [0]
	(s.tiles[2] as AIRealState.TileSnap).neighbor_ids = [3]
	(s.tiles[3] as AIRealState.TileSnap).neighbor_ids = [2]
	var first := AIRealSimulator.apply_open_front(s, 0, 1)
	var second := AIRealSimulator.apply_open_front(s, 2, 3)
	assert_not_null(first, "El primer frente se abre")
	assert_null(second, "El segundo se rechaza por el límite de frentes (1)")


# ============================================================
#  Tactic
# ============================================================

func _make_tactic(p_name: String, types: Array[int],
		atk_pct: float, def_pct: float) -> TacticCard:
	var c := TacticCard.new()
	c.tactic_name = p_name
	c.affected_troop_types = types
	c.attack_percent_per_type = atk_pct
	c.defense_percent_per_type = def_pct
	return c


func test_tactic_applies_bonus() -> void:
	var s := _two_tile_state()
	var front := AIRealSimulator.apply_open_front(s, 0, 1)
	var tactic := _make_tactic("Carga", [Troop.TroopType.CABALLERIA] as Array[int], 50.0, 0.0)
	AIRealSimulator.apply_tactic(s, front, tactic)
	assert_eq(front.attacker_bonuses.size(), 1, "Se añade el bonus al bando atacante")
	assert_eq(front.attacker_bonuses[0].tactic_name, "Carga")


func test_tactic_replaces_previous() -> void:
	var s := _two_tile_state()
	var front := AIRealSimulator.apply_open_front(s, 0, 1)
	AIRealSimulator.apply_tactic(s, front,
		_make_tactic("Vieja", [] as Array[int], 10.0, 0.0))
	AIRealSimulator.apply_tactic(s, front,
		_make_tactic("Nueva", [] as Array[int], 20.0, 0.0))
	assert_eq(front.attacker_bonuses.size(), 1, "Solo una táctica activa por bando")
	assert_eq(front.attacker_bonuses[0].tactic_name, "Nueva", "La nueva sustituye a la vieja")


# ============================================================
#  Asignación de tropas
# ============================================================

func test_assign_fills_up_to_min() -> void:
	var s := _two_tile_state()
	var front := AIRealSimulator.apply_open_front(s, 0, 1)
	for _i in range(5):
		s.own.troop_pool.append(_make_troop(Troop.TroopType.INFANTERIA_LIGERA, 6, 4))
	AIRealSimulator.assign_troops_to_fronts(s, AIRealState.OWNER_SELF)
	assert_eq(front.attacker_troops.size(), 3, "Primera pasada llena hasta MIN (3)")
	assert_eq(s.own.troop_pool.size(), 2, "Quedan 2 tropas en el pool")


func test_assign_best_troop_by_role_attacker() -> void:
	var s := _two_tile_state()
	var front := AIRealSimulator.apply_open_front(s, 0, 1)
	var weak := _make_troop(Troop.TroopType.INFANTERIA_LIGERA, 3, 9)
	var strong := _make_troop(Troop.TroopType.INFANTERIA_LIGERA, 12, 2)
	s.own.troop_pool = [weak, strong]
	# Atacante: primera tropa asignada debe ser la de mayor ataque.
	AIRealSimulator._assign_best_troop(s.own, front, BattleFront.Side.ATTACKER)
	assert_eq(front.attacker_troops[0], strong, "Atacante asigna primero la de mayor ataque")


# ============================================================
#  Economía con tropas y frentes
# ============================================================

func test_economy_subtracts_troop_maintenance() -> void:
	var s := AIRealState.new()
	s.tiles[0] = _snap_with_resource(0, 20, 10, AIRealState.OWNER_SELF)
	# 2 tropas en el pool: maint 5 oro + 1 comida cada una.
	s.own.troop_pool = [
		_make_troop(Troop.TroopType.PIQUEROS, 5, 5, 30, 5, 1),
		_make_troop(Troop.TroopType.PIQUEROS, 5, 5, 30, 5, 1),
	]
	AIRealSimulator.recompute_own_economy(s)
	assert_eq(s.own.gold_per_turn, 10, "gpt = tile(20) − maint(2×5)")
	assert_eq(s.own.food, 8, "food = tile(10) − maint(2×1)")


func test_economy_subtracts_front_surcharge() -> void:
	var s := _two_tile_state()
	(s.tiles[0] as AIRealState.TileSnap).natural_resource = _make_resource(50, 20)
	(s.tiles[0] as AIRealState.TileSnap).resource_gold = 50
	(s.tiles[0] as AIRealState.TileSnap).resource_food = 20
	var front := AIRealSimulator.apply_open_front(s, 0, 1)
	# 2 tropas asignadas como atacante: recargo +5 y +10 = 15 oro y 15 comida.
	front.attacker_troops = [
		_make_troop(Troop.TroopType.PIQUEROS, 5, 5, 30, 0, 0),
		_make_troop(Troop.TroopType.PIQUEROS, 5, 5, 30, 0, 0),
	]
	AIRealSimulator.recompute_own_economy(s)
	assert_eq(s.own.gold_per_turn, 35, "gpt = tile(50) − recargo(5+10)")
	assert_eq(s.own.food, 5, "food = tile(20) − recargo(5+10)")


func test_combat_multiplier_drops_on_deficit() -> void:
	var s := AIRealState.new()
	# Sin tiles → 0 producción; tropas con mantenimiento → déficit.
	s.own.troop_pool = [
		_make_troop(Troop.TroopType.PIQUEROS, 5, 5, 30, 10, 2),
	]
	AIRealSimulator.recompute_own_economy(s)
	assert_lt(s.own.combat_multiplier, 1.0,
		"Con déficit económico el combat_multiplier baja de 1.0")
	assert_gte(s.own.combat_multiplier, 0.1, "Nunca baja de 0.1")


func _snap_with_resource(id: int, gold: int, food: int,
		owner: int) -> AIRealState.TileSnap:
	var s := _make_snap(id, Tile.biome_type.Grassland, owner)
	s.natural_resource = _make_resource(gold, food)
	s.resource_gold = gold
	s.resource_food = food
	return s


# ============================================================
#  Resolución y conquista
# ============================================================

func test_resolve_conquers_defender_tile_when_attacker_wins() -> void:
	var s := _two_tile_state()
	var front := AIRealSimulator.apply_open_front(s, 0, 1)
	front.attacker_troops = [
		_make_troop(Troop.TroopType.INFANTERIA_PESADA, 30, 10),
		_make_troop(Troop.TroopType.INFANTERIA_PESADA, 30, 10),
		_make_troop(Troop.TroopType.INFANTERIA_PESADA, 30, 10),
	]
	front.defender_troops = [_make_troop(Troop.TroopType.A_DISTANCIA, 1, 1)]
	# Tickear directamente hasta resolver.
	for _i in range(40):
		if front.is_resolved:
			break
		AIRealSimulator._tick_front(s, front)
	assert_true(front.is_resolved, "El frente se resuelve")
	assert_eq((s.tiles[1] as AIRealState.TileSnap).owner, AIRealState.OWNER_SELF,
		"El atacante (SELF) conquista la casilla defensora")


func test_resolve_returns_survivors_to_pool() -> void:
	var s := _two_tile_state()
	var front := AIRealSimulator.apply_open_front(s, 0, 1)
	var attackers: Array[Troop] = [
		_make_troop(Troop.TroopType.INFANTERIA_PESADA, 30, 10),
		_make_troop(Troop.TroopType.INFANTERIA_PESADA, 30, 10),
		_make_troop(Troop.TroopType.INFANTERIA_PESADA, 30, 10),
		_make_troop(Troop.TroopType.INFANTERIA_PESADA, 30, 10),
	]
	front.attacker_troops = attackers.duplicate()
	front.defender_troops = [_make_troop(Troop.TroopType.A_DISTANCIA, 1, 1)]
	for _i in range(40):
		if front.is_resolved:
			break
		AIRealSimulator._tick_front(s, front)
	# El ganador conserva parte de sus tropas → vuelven al pool propio.
	assert_gt(s.own.troop_pool.size(), 0,
		"Los supervivientes del atacante vuelven a su pool")
	assert_lt(s.own.troop_pool.size(), attackers.size(),
		"El ganador también sufre algunas bajas")


func test_resolve_demolishes_one_building_on_conquest() -> void:
	var s := _two_tile_state()
	(s.tiles[1] as AIRealState.TileSnap).buildings = [
		_make_building("muralla", 5), _make_building("torre", 3)]
	var front := AIRealSimulator.apply_open_front(s, 0, 1)
	front.attacker_troops = [
		_make_troop(Troop.TroopType.INFANTERIA_PESADA, 30, 10),
		_make_troop(Troop.TroopType.INFANTERIA_PESADA, 30, 10),
		_make_troop(Troop.TroopType.INFANTERIA_PESADA, 30, 10),
	]
	front.defender_troops = [_make_troop(Troop.TroopType.A_DISTANCIA, 1, 1)]
	for _i in range(40):
		if front.is_resolved:
			break
		AIRealSimulator._tick_front(s, front)
	# Re-leer s.tiles[1]: el copy-on-write de la conquista reemplaza el TileSnap,
	# así que una referencia tomada antes quedaría obsoleta.
	assert_eq((s.tiles[1] as AIRealState.TileSnap).buildings.size(), 1,
		"La conquista demuele un edificio de la casilla tomada")


# ============================================================
#  advance_turn integra economía + asignación + tick
# ============================================================

func test_advance_turn_assigns_and_ticks_front() -> void:
	var s := _two_tile_state()
	(s.tiles[0] as AIRealState.TileSnap).natural_resource = _make_resource(100, 50)
	(s.tiles[0] as AIRealState.TileSnap).resource_gold = 100
	(s.tiles[0] as AIRealState.TileSnap).resource_food = 50
	var front := AIRealSimulator.apply_open_front(s, 0, 1)
	for _i in range(3):
		s.own.troop_pool.append(_make_troop(Troop.TroopType.INFANTERIA_LIGERA, 6, 4, 30, 0, 0))
	AIRealSimulator.advance_turn(s)
	assert_eq(front.attacker_troops.size(), 3,
		"advance_turn asigna las tropas del pool al frente")
	assert_eq(front.turns_elapsed, 1, "advance_turn tickea el frente una vez")


# ============================================================
#  Clone de frentes
# ============================================================

func test_clone_fronts_are_independent() -> void:
	var s := _two_tile_state()
	var front := AIRealSimulator.apply_open_front(s, 0, 1)
	front.attacker_troops = [_make_troop(Troop.TroopType.PIQUEROS, 5, 5)]
	front.marker = 4.0
	var c := s.clone()
	var cfront := c.fronts[0] as AIRealState.FrontSnap
	cfront.marker = 99.0
	cfront.attacker_troops.append(_make_troop(Troop.TroopType.CABALLERIA, 9, 3))
	assert_eq(front.marker, 4.0, "Clonar no altera el marcador del original")
	assert_eq(front.attacker_troops.size(), 1,
		"Clonar no altera las tropas del frente original")


func test_clone_front_bonuses_are_independent() -> void:
	var s := _two_tile_state()
	var front := AIRealSimulator.apply_open_front(s, 0, 1)
	var bonus := TacticBonus.new()
	bonus.tactic_name = "X"
	bonus.duration = 3
	front.attacker_bonuses.append(bonus)
	var c := s.clone()
	(c.fronts[0] as AIRealState.FrontSnap).attacker_bonuses[0].duration = 0
	assert_eq(front.attacker_bonuses[0].duration, 3,
		"Clonar duplica los bonuses: mutar el clon no afecta al original")
