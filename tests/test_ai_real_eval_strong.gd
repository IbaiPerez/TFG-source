extends GutTest

## Tests del prior FUERTE sobre el snapshot (Fase C v2 — F3c): AIRealEvalStrong.
## Valida las propiedades DISCRIMINANTES del port de COLONIZE que el prior débil
## (AIRealEval.score_move) no captura — producción, frontera, negación y carrera
## territorial — más la delegación sin regresión de los tipos aún no portados.


# ============================================================
#  Helpers
# ============================================================

func _snap(id: int, owner: int, res_gold: int = 0, res_food: int = 0,
		neighbors: Array[int] = []) -> AIRealState.TileSnap:
	var s := AIRealState.TileSnap.new()
	s.id = id
	s.owner = owner
	s.biome = 0
	s.location_type = Tile.location_type.Village
	s.max_buildings = 3
	s.resource_gold = res_gold
	s.resource_food = res_food
	s.neighbor_ids = neighbors
	return s


func _colonize(tile_id: int) -> AIRealOptions.Move:
	var m := AIRealOptions.Move.new()
	m.kind = &"COLONIZE"
	m.tile_id = tile_id
	return m


# ============================================================
#  Casos base
# ============================================================

func test_pass_is_zero() -> void:
	var s := AIRealState.new()
	assert_eq(AIRealEvalStrong.score_move(AIRealOptions.Move.pass_move(), s), 0.0)


func test_colonize_positive() -> void:
	var s := AIRealState.new()
	s.total_map_tiles = 20
	s.tiles[0] = _snap(0, AIRealState.OWNER_SELF, 0, 0, [1] as Array[int])
	s.tiles[1] = _snap(1, AIRealState.OWNER_NONE)
	assert_gt(AIRealEvalStrong.score_move(_colonize(1), s), 0.0,
		"Colonizar tiene valor positivo")


# ============================================================
#  Propiedades discriminantes
# ============================================================

func test_colonize_scales_with_production() -> void:
	# Dos casillas libres adyacentes a territorio propio; una mucho más rica.
	var s := AIRealState.new()
	s.total_map_tiles = 20
	s.tiles[0] = _snap(0, AIRealState.OWNER_SELF, 0, 0, [1, 2] as Array[int])
	s.tiles[1] = _snap(1, AIRealState.OWNER_NONE, 20, 0, [0] as Array[int])  # rica
	s.tiles[2] = _snap(2, AIRealState.OWNER_NONE, 2, 0, [0] as Array[int])   # pobre
	assert_gt(AIRealEvalStrong.score_move(_colonize(1), s),
		AIRealEvalStrong.score_move(_colonize(2), s),
		"Colonizar una casilla más productiva puntúa más alto")


func test_colonize_denial_bonus_next_to_rival() -> void:
	# Misma producción y frontera; solo una es adyacente al rival (bonus de negación).
	var s := AIRealState.new()
	s.total_map_tiles = 20
	s.tiles[0] = _snap(0, AIRealState.OWNER_SELF, 0, 0, [1, 2] as Array[int])
	s.tiles[1] = _snap(1, AIRealState.OWNER_NONE, 0, 0, [0, 3] as Array[int]) # junto a rival
	s.tiles[2] = _snap(2, AIRealState.OWNER_NONE, 0, 0, [0] as Array[int])
	s.tiles[3] = _snap(3, AIRealState.OWNER_RIVAL)
	assert_gt(AIRealEvalStrong.score_move(_colonize(1), s),
		AIRealEvalStrong.score_move(_colonize(2), s),
		"Colonizar junto al rival puntúa más (niega su expansión)")


func test_colonize_frontier_bonus_opens_space() -> void:
	# La casilla 1 abre dos casillas libres nuevas; la 2 no abre ninguna.
	var s := AIRealState.new()
	s.total_map_tiles = 20
	s.tiles[0] = _snap(0, AIRealState.OWNER_SELF, 0, 0, [1, 2] as Array[int])
	s.tiles[1] = _snap(1, AIRealState.OWNER_NONE, 0, 0, [0, 10, 11] as Array[int])
	s.tiles[2] = _snap(2, AIRealState.OWNER_NONE, 0, 0, [0] as Array[int])
	# Libres solo alcanzables a través de la casilla 1.
	s.tiles[10] = _snap(10, AIRealState.OWNER_NONE, 0, 0, [1] as Array[int])
	s.tiles[11] = _snap(11, AIRealState.OWNER_NONE, 0, 0, [1] as Array[int])
	assert_gt(AIRealEvalStrong.score_move(_colonize(1), s),
		AIRealEvalStrong.score_move(_colonize(2), s),
		"Colonizar una casilla que abre espacio nuevo puntúa más (valor de frontera)")


func test_territory_race_amplifies_when_dominating() -> void:
	# my_share ≥ 0.60 → modo cierre, factor ×2.
	var s := AIRealState.new()
	s.total_map_tiles = 10
	for i in range(6):
		s.tiles[i] = _snap(i, AIRealState.OWNER_SELF)
	s.tiles[9] = _snap(9, AIRealState.OWNER_RIVAL)
	assert_eq(AIRealEvalStrong._territory_race_factor(s, AIRealState.OWNER_SELF, &"colonize"),
		2.0, "Dominando (≥60% de la carrera) el factor territorial es ×2")


func test_territory_race_neutral_when_balanced() -> void:
	# Reparto equilibrado y espacio libre → factor neutro ×1.
	var s := AIRealState.new()
	s.total_map_tiles = 10
	s.tiles[0] = _snap(0, AIRealState.OWNER_SELF, 0, 0, [2, 3] as Array[int])
	s.tiles[1] = _snap(1, AIRealState.OWNER_RIVAL)
	s.tiles[2] = _snap(2, AIRealState.OWNER_NONE)
	s.tiles[3] = _snap(3, AIRealState.OWNER_NONE)
	assert_eq(AIRealEvalStrong._territory_race_factor(s, AIRealState.OWNER_SELF, &"colonize"),
		1.0, "Con reparto equilibrado el factor territorial es neutro")


# ============================================================
#  Build / Recruit (portados en F3c.2)
# ============================================================

func _building(p_name: String, gold: int = 0, food: int = 0) -> Building:
	var b := Building.new()
	b.name = p_name
	b.gold_produced = gold
	b.food_produced = food
	b.construction_cost = 40
	return b


func _build_move(tile_id: int, building: Building) -> AIRealOptions.Move:
	var m := AIRealOptions.Move.new()
	m.kind = &"BUILD"
	m.tile_id = tile_id
	m.building = building
	return m


func test_build_scales_with_production() -> void:
	var s := AIRealState.new()
	s.total_map_tiles = 20
	s.tiles[0] = _snap(0, AIRealState.OWNER_SELF)
	s.own.gold = 500
	var rich := _build_move(0, _building("rica", 20, 0))
	var poor := _build_move(0, _building("pobre", 2, 0))
	assert_gt(AIRealEvalStrong.score_move(rich, s), AIRealEvalStrong.score_move(poor, s),
		"Un edificio más productivo puntúa más alto")


func test_recruit_positive_when_affordable() -> void:
	var s := AIRealState.new()
	s.total_map_tiles = 20
	s.own.gold = 200
	s.own.gold_per_turn = 50
	s.own.food = 10
	var troop := Troop.new()
	troop.type = Troop.TroopType.INFANTERIA_LIGERA
	troop.attack = 5
	troop.defense = 5
	troop.recruitment_cost_gold = 30
	troop.maintenance_gold = 2
	troop.maintenance_food = 0
	var m := AIRealOptions.Move.new()
	m.kind = &"RECRUIT"
	m.troop = troop
	assert_gt(AIRealEvalStrong.score_move(m, s), 0.0,
		"Reclutar una tropa asumible tiene valor positivo")


func test_recruit_vetoed_when_food_would_collapse() -> void:
	var s := AIRealState.new()
	s.total_map_tiles = 20
	s.own.gold = 200
	s.own.gold_per_turn = 50
	s.own.food = 0
	var troop := Troop.new()
	troop.type = Troop.TroopType.INFANTERIA_LIGERA
	troop.attack = 5
	troop.defense = 5
	troop.recruitment_cost_gold = 30
	troop.maintenance_gold = 0
	troop.maintenance_food = 10   # hundiría la comida muy por debajo del margen
	var m := AIRealOptions.Move.new()
	m.kind = &"RECRUIT"
	m.troop = troop
	assert_eq(AIRealEvalStrong.score_move(m, s), -10.0,
		"Reclutar se veta si el mantenimiento hunde la comida")


# ============================================================
#  Open front / Generate gold / Change location (portados en F3c.3)
# ============================================================

func test_open_front_zero_without_free_troops() -> void:
	var s := AIRealState.new()
	s.total_map_tiles = 20
	s.tiles[0] = _snap(0, AIRealState.OWNER_SELF)
	s.tiles[1] = _snap(1, AIRealState.OWNER_RIVAL)
	var m := AIRealOptions.Move.new()
	m.kind = &"OPEN_FRONT"
	m.tile_id = 0
	m.def_tile_id = 1
	assert_eq(AIRealEvalStrong.score_move(m, s), 0.0,
		"Sin tropas libres, abrir un frente no tiene valor")


func test_generate_gold_scales_with_amount() -> void:
	var s := AIRealState.new()
	s.total_map_tiles = 20
	s.tiles[0] = _snap(0, AIRealState.OWNER_SELF)
	var big := AIRealOptions.Move.new()
	big.kind = &"GENERATE_GOLD"
	big.amount = 200
	var small := AIRealOptions.Move.new()
	small.kind = &"GENERATE_GOLD"
	small.amount = 20
	assert_gt(AIRealEvalStrong.score_move(big, s), AIRealEvalStrong.score_move(small, s),
		"Más oro inmediato puntúa más alto")


func _location(type_enum: int, food_consumption: int, max_building: int) -> LocationType:
	var loc := LocationType.new()
	loc.type = type_enum
	loc.food_consumption = food_consumption
	loc.max_building = max_building
	return loc


func test_change_location_vetoed_when_food_negative() -> void:
	var s := AIRealState.new()
	s.total_map_tiles = 20
	s.tiles[0] = _snap(0, AIRealState.OWNER_SELF)
	s.own.food = 0
	var m := AIRealOptions.Move.new()
	m.kind = &"CHANGE_LOCATION"
	m.tile_id = 0
	m.location = _location(2, 10, 5)   # +10 de consumo con 0 de comida
	assert_eq(AIRealEvalStrong.score_move(m, s), -20.0,
		"Change location se veta si deja la comida en negativo")


func test_change_location_positive_for_new_slots() -> void:
	var s := AIRealState.new()
	s.total_map_tiles = 20
	s.tiles[0] = _snap(0, AIRealState.OWNER_SELF)
	s.own.food = 10
	var m := AIRealOptions.Move.new()
	m.kind = &"CHANGE_LOCATION"
	m.tile_id = 0
	m.location = _location(2, 0, 5)    # +2 slots (max_buildings 3→5), sin coste de comida
	assert_gt(AIRealEvalStrong.score_move(m, s), 0.0,
		"Ganar slots de edificio sin coste de comida tiene valor positivo")


# ============================================================
#  Delegación sin regresión (tipos no cubiertos)
# ============================================================

func test_unhandled_kind_delegates_to_weak_prior() -> void:
	# RECOVER no lo modela AIRealOptions ni AIRealEvalStrong → debe delegar.
	var s := AIRealState.new()
	s.total_map_tiles = 20
	s.tiles[0] = _snap(0, AIRealState.OWNER_SELF)
	var m := AIRealOptions.Move.new()
	m.kind = &"RECOVER"
	assert_eq(AIRealEvalStrong.score_move(m, s), AIRealEval.score_move(m, s),
		"Un tipo no cubierto delega en el prior débil (sin regresión)")
