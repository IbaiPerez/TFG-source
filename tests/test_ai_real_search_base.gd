extends GutTest

## Tests para los cimientos de la búsqueda MCTS v2 (Fase C v2 — F3a):
## AIRealEval (score_state/detect_phase/score_move) y AIRealOptions
## (enumeración y aplicación de jugadas carta+target sobre el snapshot).


# ============================================================
#  Helpers
# ============================================================

func _resource(gold: int, food: int) -> NaturalResource:
	var r := NaturalResource.new()
	r.gold_produced = gold
	r.food_produced = food
	return r


func _snap(id: int, owner: int, biome: int = 0,
		location: int = Tile.location_type.Village, max_b: int = 3) -> AIRealState.TileSnap:
	var s := AIRealState.TileSnap.new()
	s.id = id
	s.owner = owner
	s.biome = biome
	s.location_type = location
	s.max_buildings = max_b
	s.natural_resource = _resource(0, 0)
	s.neighbor_ids = []
	return s


func _building(p_name: String, gold: int = 0, food: int = 0) -> Building:
	var b := Building.new()
	b.name = p_name
	b.gold_produced = gold
	b.food_produced = food
	b.construction_cost = 40
	return b


func _troop(cost: int = 30, maint_g: int = 2, maint_f: int = 0) -> Troop:
	var t := Troop.new()
	t.name = "t"
	t.type = Troop.TroopType.INFANTERIA_LIGERA
	t.attack = 5
	t.defense = 5
	t.recruitment_cost_gold = cost
	t.maintenance_gold = maint_g
	t.maintenance_food = maint_f
	return t


# ============================================================
#  score_state — condiciones terminales
# ============================================================

func test_score_state_domination_win() -> void:
	var s := AIRealState.new()
	s.total_map_tiles = 10
	for i in range(7):
		s.tiles[i] = _snap(i, AIRealState.OWNER_SELF)
	assert_eq(AIRealEval.score_state(s), 1.0, "≥70% del mapa = victoria (+1)")


func test_score_state_domination_loss() -> void:
	var s := AIRealState.new()
	s.total_map_tiles = 10
	for i in range(7):
		s.tiles[i] = _snap(i, AIRealState.OWNER_RIVAL)
	s.tiles[7] = _snap(7, AIRealState.OWNER_SELF)
	assert_eq(AIRealEval.score_state(s), -1.0, "Rival con ≥70% = derrota (−1)")


func test_score_state_elimination() -> void:
	var s := AIRealState.new()
	s.total_map_tiles = 10
	s.tiles[0] = _snap(0, AIRealState.OWNER_SELF)
	# Rival sin tiles → victoria.
	assert_eq(AIRealEval.score_state(s), 1.0, "Rival eliminado = victoria")


# ============================================================
#  score_state — diferencial
# ============================================================

func test_score_state_in_range() -> void:
	var s := AIRealState.new()
	s.total_map_tiles = 20
	s.tiles[0] = _snap(0, AIRealState.OWNER_SELF)
	s.tiles[1] = _snap(1, AIRealState.OWNER_RIVAL)
	s.own.gold_per_turn = 100
	s.rival.gold_per_turn = 50
	var v := AIRealEval.score_state(s)
	assert_between(v, -1.0, 1.0, "score_state siempre en [-1, 1]")


func test_score_state_favors_more_territory_and_economy() -> void:
	var strong := AIRealState.new()
	strong.total_map_tiles = 20
	for i in range(5):
		strong.tiles[i] = _snap(i, AIRealState.OWNER_SELF)
	strong.tiles[10] = _snap(10, AIRealState.OWNER_RIVAL)
	strong.own.gold_per_turn = 300
	strong.rival.gold_per_turn = 50

	var weak := AIRealState.new()
	weak.total_map_tiles = 20
	weak.tiles[0] = _snap(0, AIRealState.OWNER_SELF)
	for i in range(5):
		weak.tiles[10 + i] = _snap(10 + i, AIRealState.OWNER_RIVAL)
	weak.own.gold_per_turn = 50
	weak.rival.gold_per_turn = 300

	assert_gt(AIRealEval.score_state(strong), AIRealEval.score_state(weak),
		"Más territorio y economía → mayor valor")


# ============================================================
#  detect_phase
# ============================================================

func test_detect_phase_early() -> void:
	var s := AIRealState.new()
	s.total_map_tiles = 100
	s.tiles[0] = _snap(0, AIRealState.OWNER_SELF)  # 1% del mapa
	s.own.gold_per_turn = 40
	assert_eq(AIRealEval.detect_phase(s), AIGamePhase.Phase.EARLY)


func test_detect_phase_late_by_share() -> void:
	var s := AIRealState.new()
	s.total_map_tiles = 10
	for i in range(4):  # 40% del mapa
		s.tiles[i] = _snap(i, AIRealState.OWNER_SELF)
	s.own.gold_per_turn = 50
	assert_eq(AIRealEval.detect_phase(s), AIGamePhase.Phase.LATE)


# ============================================================
#  score_move (prior)
# ============================================================

func _state_with_owned() -> AIRealState:
	var s := AIRealState.new()
	s.total_map_tiles = 20
	s.tiles[0] = _snap(0, AIRealState.OWNER_SELF)
	s.own.gold = 500
	return s


func test_score_move_pass_is_zero() -> void:
	assert_eq(AIRealEval.score_move(AIRealOptions.Move.pass_move(), _state_with_owned()), 0.0)


func test_score_move_colonize_positive() -> void:
	var m := AIRealOptions.Move.new()
	m.kind = &"COLONIZE"
	m.tile_id = 0
	assert_gt(AIRealEval.score_move(m, _state_with_owned()), 0.0,
		"Colonizar tiene valor positivo")


func test_score_move_build_scales_with_production() -> void:
	var s := _state_with_owned()
	var rich := AIRealOptions.Move.new()
	rich.kind = &"BUILD"
	rich.building = _building("rich", 20, 0)
	var poor := AIRealOptions.Move.new()
	poor.kind = &"BUILD"
	poor.building = _building("poor", 2, 0)
	assert_gt(AIRealEval.score_move(rich, s), AIRealEval.score_move(poor, s),
		"Un edificio más productivo puntúa más alto")


# ============================================================
#  Enumeración de jugadas
# ============================================================

func test_enumerate_colonize_adjacent_uncolonized() -> void:
	var s := AIRealState.new()
	s.tiles[0] = _snap(0, AIRealState.OWNER_SELF)
	s.tiles[1] = _snap(1, AIRealState.OWNER_NONE, 0, Tile.location_type.Uncolonized)
	s.tiles[2] = _snap(2, AIRealState.OWNER_NONE, 0, Tile.location_type.Uncolonized)
	(s.tiles[0] as AIRealState.TileSnap).neighbor_ids = [1]   # solo 1 es adyacente
	var moves := AIRealOptions.enumerate(s, [ColonizeCard.new()] as Array[Card])
	assert_eq(moves.size(), 1, "Solo la casilla adyacente libre es colonizable")
	assert_eq((moves[0] as AIRealOptions.Move).tile_id, 1)


func test_enumerate_build_over_owned_tiles() -> void:
	var s := AIRealState.new()
	s.tiles[0] = _snap(0, AIRealState.OWNER_SELF)
	s.tiles[1] = _snap(1, AIRealState.OWNER_RIVAL)
	s.own.gold = 500
	s.own.possible_buildings = [_building("mina", 10)] as Array[Building]
	var moves := AIRealOptions.enumerate(s, [BuildCard.new()] as Array[Card])
	assert_eq(moves.size(), 1, "Build solo en la casilla propia construible")
	assert_eq((moves[0] as AIRealOptions.Move).tile_id, 0)


func test_enumerate_build_filters_unaffordable() -> void:
	var s := AIRealState.new()
	s.tiles[0] = _snap(0, AIRealState.OWNER_SELF)
	s.own.gold = 10   # menos que el coste (40)
	s.own.possible_buildings = [_building("mina", 10)] as Array[Building]
	var moves := AIRealOptions.enumerate(s, [BuildCard.new()] as Array[Card])
	assert_eq(moves.size(), 0, "Sin oro suficiente no hay opciones de Build")


func test_enumerate_recruit_per_affordable_troop() -> void:
	var s := AIRealState.new()
	s.own.gold = 200
	s.own.gold_per_turn = 50
	s.own.food = 10
	var card := RecruitCard.new()
	card.available_troops = [_troop(30), _troop(30)] as Array[Troop]
	var moves := AIRealOptions.enumerate(s, [card] as Array[Card])
	assert_eq(moves.size(), 2, "Una opción por tropa asequible")


func test_enumerate_open_front_enemy_adjacent() -> void:
	var s := AIRealState.new()
	s.tiles[0] = _snap(0, AIRealState.OWNER_SELF)
	s.tiles[1] = _snap(1, AIRealState.OWNER_RIVAL)
	(s.tiles[0] as AIRealState.TileSnap).neighbor_ids = [1]
	var moves := AIRealOptions.enumerate(s, [OpenFrontCard.new()] as Array[Card])
	assert_eq(moves.size(), 1, "Open Front contra la casilla rival adyacente")
	var m := moves[0] as AIRealOptions.Move
	assert_eq(m.tile_id, 0, "Atacante = casilla propia")
	assert_eq(m.def_tile_id, 1, "Defensora = casilla rival")


# ============================================================
#  Aplicación de jugadas
# ============================================================

func test_apply_colonize_move() -> void:
	var s := AIRealState.new()
	s.tiles[0] = _snap(0, AIRealState.OWNER_SELF)
	s.tiles[1] = _snap(1, AIRealState.OWNER_NONE, 0, Tile.location_type.Uncolonized)
	(s.tiles[0] as AIRealState.TileSnap).neighbor_ids = [1]
	var moves := AIRealOptions.enumerate(s, [ColonizeCard.new()] as Array[Card])
	AIRealOptions.apply(s, moves[0] as AIRealOptions.Move)
	assert_eq((s.tiles[1] as AIRealState.TileSnap).owner, AIRealState.OWNER_SELF,
		"Aplicar la jugada COLONIZE toma la casilla")


func test_apply_build_move() -> void:
	var s := AIRealState.new()
	s.tiles[0] = _snap(0, AIRealState.OWNER_SELF)
	s.own.gold = 500
	s.own.possible_buildings = [_building("mina", 10)] as Array[Building]
	var moves := AIRealOptions.enumerate(s, [BuildCard.new()] as Array[Card])
	AIRealOptions.apply(s, moves[0] as AIRealOptions.Move)
	assert_eq((s.tiles[0] as AIRealState.TileSnap).buildings.size(), 1,
		"Aplicar la jugada BUILD construye el edificio")
	assert_lt(s.own.gold, 500, "Se descuenta el coste")
