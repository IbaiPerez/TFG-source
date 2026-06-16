extends GutTest

## Tests para AIRealState y AIRealSimulator (Fase C v2 — F1).
##
## Cubre: paridad de la fórmula de producción por-tile contra el juego real
## (Tile.recalculate_modifiers), efectos puros (colonize/build/upgrade/
## change_location/generate_gold), advance_turn y clonado independiente.


# ============================================================
#  Helpers de construcción
# ============================================================

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


func _make_building(p_name: String, gold: int, food: int,
		defense: int = 0, food_pct: float = 0.0) -> Building:
	var b := Building.new()
	b.name = p_name
	b.gold_produced = gold
	b.food_produced = food
	b.flat_defense_bonus = defense
	b.food_percent_bonus = food_pct
	b.construction_cost = 50
	return b


## Crea un Tile REAL en memoria (Node3D) con los datos dados y lo recalcula.
## Se libera automáticamente al terminar el test (autofree).
func _make_real_tile(resource: NaturalResource, location: LocationType,
		buildings: Array[Building]) -> Tile:
	var t := autofree(Tile.new()) as Tile
	t.natural_resource = resource
	t.location = location
	t.buildings = buildings.duplicate()
	t.recalculate_modifiers()
	return t


## Crea un TileSnap espejo del Tile real (mismos recursos/location/edificios).
func _snap_from_tile(id: int, resource: NaturalResource, location: LocationType,
		buildings: Array[Building], owner: int = AIRealState.OWNER_SELF) -> AIRealState.TileSnap:
	var s := AIRealState.TileSnap.new()
	s.id = id
	s.natural_resource = resource
	s.resource_gold = resource.gold_produced
	s.resource_food = resource.food_produced
	s.location_type = location.type
	s.max_buildings = location.max_building
	s.food_consumption = location.food_consumption
	s.buildings = buildings.duplicate()
	s.owner = owner
	s.neighbor_ids = []
	return s


## Estado mínimo con una sola casilla propia ya colonizada (Village).
func _state_one_owned_tile(resource: NaturalResource) -> AIRealState:
	var s := AIRealState.new()
	var village := _make_location(Tile.location_type.Village, 1, 0)
	s.tiles[0] = _snap_from_tile(0, resource, village, [])
	s.total_map_tiles = 1
	AIRealSimulator.recompute_own_economy(s)
	return s


# ============================================================
#  Paridad de producción: TileSnap vs Tile real
# ============================================================

func test_production_parity_resource_only() -> void:
	var res := _make_resource(5, 3)
	var loc := _make_location(Tile.location_type.Village, 1, 0)
	var tile := _make_real_tile(res, loc, [])
	var snap := _snap_from_tile(0, res, loc, [])
	assert_eq(snap.gold_production(), tile.gold_production,
		"Oro de la casilla debe coincidir con Tile.recalculate_modifiers")
	assert_eq(snap.food_production(), tile.food_production,
		"Comida de la casilla debe coincidir con Tile.recalculate_modifiers")


func test_production_parity_with_buildings() -> void:
	var res := _make_resource(2, 1)
	var loc := _make_location(Tile.location_type.Town, 3, 5)
	var blds: Array[Building] = [
		_make_building("mina", 10, 0),
		_make_building("granja", 0, 4),
	]
	var tile := _make_real_tile(res, loc, blds)
	var snap := _snap_from_tile(0, res, loc, blds)
	assert_eq(snap.gold_production(), tile.gold_production,
		"Oro con edificios debe coincidir (got %d vs %d)"
			% [snap.gold_production(), tile.gold_production])
	assert_eq(snap.food_production(), tile.food_production,
		"Comida con edificios y consumo debe coincidir (got %d vs %d)"
			% [snap.food_production(), tile.food_production])


func test_production_parity_food_percent_bonus() -> void:
	var res := _make_resource(0, 8)
	var loc := _make_location(Tile.location_type.Village, 1, 0)
	# +50% sobre el food natural (8) → +4.
	var blds: Array[Building] = [_make_building("molino", 0, 0, 0, 50.0)]
	var tile := _make_real_tile(res, loc, blds)
	var snap := _snap_from_tile(0, res, loc, blds)
	assert_eq(snap.food_production(), tile.food_production,
		"Bonus porcentual de comida debe coincidir (got %d vs %d)"
			% [snap.food_production(), tile.food_production])


# ============================================================
#  recompute_economy
# ============================================================

func test_recompute_economy_sums_owned_tiles_only() -> void:
	var s := AIRealState.new()
	var village := _make_location(Tile.location_type.Village, 1, 0)
	s.tiles[0] = _snap_from_tile(0, _make_resource(5, 2), village, [], AIRealState.OWNER_SELF)
	s.tiles[1] = _snap_from_tile(1, _make_resource(7, 1), village, [], AIRealState.OWNER_SELF)
	s.tiles[2] = _snap_from_tile(2, _make_resource(9, 9), village, [], AIRealState.OWNER_RIVAL)
	AIRealSimulator.recompute_own_economy(s)
	assert_eq(s.own.gold_per_turn, 12, "gpt propio = 5+7 (no cuenta la rival)")
	assert_eq(s.own.food, 3, "food propio = 2+1 (no cuenta la rival)")


func test_recompute_economy_rival_independent() -> void:
	var s := AIRealState.new()
	var village := _make_location(Tile.location_type.Village, 1, 0)
	s.tiles[0] = _snap_from_tile(0, _make_resource(5, 2), village, [], AIRealState.OWNER_SELF)
	s.tiles[1] = _snap_from_tile(1, _make_resource(9, 4), village, [], AIRealState.OWNER_RIVAL)
	AIRealSimulator.recompute_economy(s, AIRealState.OWNER_RIVAL)
	assert_eq(s.rival.gold_per_turn, 9, "gpt rival = 9")
	assert_eq(s.rival.food, 4, "food rival = 4")


# ============================================================
#  apply_colonize
# ============================================================

func test_colonize_takes_tile_and_urbanizes() -> void:
	var s := AIRealState.new()
	var uncol := _make_location(Tile.location_type.Uncolonized, 0, 0)
	s.tiles[0] = _snap_from_tile(0, _make_resource(6, 3), uncol, [], AIRealState.OWNER_NONE)
	s.total_map_tiles = 1
	AIRealSimulator.apply_colonize(s, 0)
	var t := s.tiles[0] as AIRealState.TileSnap
	assert_eq(t.owner, AIRealState.OWNER_SELF, "La casilla pasa a ser propia")
	assert_eq(t.location_type, Tile.location_type.Village,
		"Una casilla Uncolonized se urbaniza a Village al colonizar")
	assert_eq(t.max_buildings, 1, "Village habilita 1 slot de edificio")


func test_colonize_adds_production() -> void:
	var s := AIRealState.new()
	var uncol := _make_location(Tile.location_type.Uncolonized, 0, 0)
	s.tiles[0] = _snap_from_tile(0, _make_resource(6, 3), uncol, [], AIRealState.OWNER_NONE)
	s.total_map_tiles = 1
	AIRealSimulator.apply_colonize(s, 0)
	assert_eq(s.own.gold_per_turn, 6, "Colonizar suma el oro del recurso (Village food_cons=0)")
	assert_eq(s.own.food, 3, "Colonizar suma la comida del recurso")


func test_colonize_increments_tile_count() -> void:
	var s := AIRealState.new()
	var uncol := _make_location(Tile.location_type.Uncolonized, 0, 0)
	s.tiles[0] = _snap_from_tile(0, _make_resource(1, 0), uncol, [], AIRealState.OWNER_NONE)
	AIRealSimulator.apply_colonize(s, 0)
	assert_eq(s.count_tiles(AIRealState.OWNER_SELF), 1)


# ============================================================
#  apply_build
# ============================================================

func test_build_adds_building_and_production() -> void:
	var s := _state_one_owned_tile(_make_resource(2, 0))
	s.own.gold = 100
	var b := _make_building("mina", 10, 0)
	AIRealSimulator.apply_build(s, 0, b)
	var t := s.tiles[0] as AIRealState.TileSnap
	assert_eq(t.buildings.size(), 1, "El edificio se añade a la casilla")
	assert_eq(s.own.gold_per_turn, 12, "gpt = recurso(2) + edificio(10)")


func test_build_deducts_construction_cost() -> void:
	var s := _state_one_owned_tile(_make_resource(2, 0))
	s.own.gold = 100
	var b := _make_building("mina", 10, 0)  # construction_cost = 50
	AIRealSimulator.apply_build(s, 0, b)
	assert_eq(s.own.gold, 50, "Construir descuenta el coste de construcción")


func test_build_blocked_when_no_free_slot() -> void:
	# Village con 1 slot ya ocupado: no se puede construir un segundo edificio.
	var s := AIRealState.new()
	var village := _make_location(Tile.location_type.Village, 1, 0)
	s.tiles[0] = _snap_from_tile(0, _make_resource(2, 0), village,
		[_make_building("existente", 5, 0)])
	s.own.gold = 100
	AIRealSimulator.recompute_own_economy(s)
	AIRealSimulator.apply_build(s, 0, _make_building("nuevo", 10, 0))
	var t := s.tiles[0] as AIRealState.TileSnap
	assert_eq(t.buildings.size(), 1, "Sin slots libres no se construye")
	assert_eq(s.own.gold, 100, "Build bloqueado no descuenta oro")


func test_build_blocked_when_duplicate_name() -> void:
	var s := AIRealState.new()
	var town := _make_location(Tile.location_type.Town, 3, 0)
	s.tiles[0] = _snap_from_tile(0, _make_resource(2, 0), town,
		[_make_building("mina", 5, 0)])
	s.own.gold = 100
	AIRealSimulator.apply_build(s, 0, _make_building("mina", 10, 0))
	var t := s.tiles[0] as AIRealState.TileSnap
	assert_eq(t.buildings.size(), 1, "No se permite un edificio con nombre duplicado")


# ============================================================
#  apply_upgrade
# ============================================================

func test_upgrade_replaces_building() -> void:
	var s := AIRealState.new()
	var town := _make_location(Tile.location_type.Town, 3, 0)
	var old_b := _make_building("mina", 5, 0)
	s.tiles[0] = _snap_from_tile(0, _make_resource(2, 0), town, [old_b])
	s.own.gold = 200
	AIRealSimulator.recompute_own_economy(s)
	var new_b := _make_building("mina_mejorada", 15, 0)
	AIRealSimulator.apply_upgrade(s, 0, old_b, new_b)
	var t := s.tiles[0] as AIRealState.TileSnap
	assert_eq(t.buildings.size(), 1, "El upgrade mantiene un solo edificio")
	assert_eq(t.buildings[0].name, "mina_mejorada", "El edificio viejo se sustituye")
	assert_eq(s.own.gold_per_turn, 17, "gpt = recurso(2) + nuevo edificio(15)")
	assert_eq(s.own.gold, 150, "Upgrade descuenta el coste del nuevo edificio (50)")


func test_upgrade_noop_when_old_not_present() -> void:
	var s := _state_one_owned_tile(_make_resource(2, 0))
	s.own.gold = 200
	var phantom := _make_building("inexistente", 5, 0)
	var new_b := _make_building("nuevo", 15, 0)
	AIRealSimulator.apply_upgrade(s, 0, phantom, new_b)
	assert_eq((s.tiles[0] as AIRealState.TileSnap).buildings.size(), 0,
		"Upgrade sobre un edificio ausente no hace nada")
	assert_eq(s.own.gold, 200, "Upgrade no-op no descuenta oro")


# ============================================================
#  apply_change_location
# ============================================================

func test_change_location_increases_slots_and_consumption() -> void:
	var s := AIRealState.new()
	var village := _make_location(Tile.location_type.Village, 1, 0)
	s.tiles[0] = _snap_from_tile(0, _make_resource(4, 6), village, [])
	AIRealSimulator.recompute_own_economy(s)
	var town := _make_location(Tile.location_type.Town, 3, 5)
	AIRealSimulator.apply_change_location(s, 0, town)
	var t := s.tiles[0] as AIRealState.TileSnap
	assert_eq(t.location_type, Tile.location_type.Town, "Sube a Town")
	assert_eq(t.max_buildings, 3, "Town habilita más slots")
	assert_eq(t.food_consumption, 5, "Town aumenta el consumo de comida")
	assert_eq(s.own.food, 1, "food = recurso(6) − consumo(5)")


func test_change_location_demolishes_incompatible_buildings() -> void:
	var s := AIRealState.new()
	var village_lt := _make_location(Tile.location_type.Village, 1, 0)
	# Edificio restringido a Village: debe demolerse al pasar a Town.
	var village_only := _make_building("choza", 5, 0)
	village_only.allowed_location_type = [_make_location(Tile.location_type.Village, 1, 0)]
	s.tiles[0] = _snap_from_tile(0, _make_resource(2, 0), village_lt, [village_only])
	AIRealSimulator.recompute_own_economy(s)
	var town := _make_location(Tile.location_type.Town, 3, 0)
	AIRealSimulator.apply_change_location(s, 0, town)
	var t := s.tiles[0] as AIRealState.TileSnap
	assert_eq(t.buildings.size(), 0, "El edificio restringido a Village se demuele")
	assert_eq(s.own.gold_per_turn, 2, "Tras demoler, gpt = solo el recurso")


func test_change_location_keeps_unrestricted_buildings() -> void:
	var s := AIRealState.new()
	var village_lt := _make_location(Tile.location_type.Village, 1, 0)
	# Edificio sin restricción de location: sobrevive.
	var anywhere := _make_building("almacen", 8, 0)
	s.tiles[0] = _snap_from_tile(0, _make_resource(2, 0), village_lt, [anywhere])
	var town := _make_location(Tile.location_type.Town, 3, 0)
	AIRealSimulator.apply_change_location(s, 0, town)
	var t := s.tiles[0] as AIRealState.TileSnap
	assert_eq(t.buildings.size(), 1, "Un edificio sin restricción sobrevive al cambio")


# ============================================================
#  apply_generate_gold
# ============================================================

func test_generate_gold_adds_immediate_gold() -> void:
	var s := _state_one_owned_tile(_make_resource(2, 0))
	s.own.gold = 100
	AIRealSimulator.apply_generate_gold(s, 75)
	assert_eq(s.own.gold, 175, "GenerateGold suma oro inmediato")
	assert_eq(s.own.gold_per_turn, 2, "GenerateGold no altera el gpt")


# ============================================================
#  advance_turn
# ============================================================

func test_advance_turn_accumulates_income() -> void:
	var s := _state_one_owned_tile(_make_resource(10, 0))
	s.own.gold = 50
	AIRealSimulator.advance_turn(s)
	assert_eq(s.own.gold, 60, "total_gold += gold_per_turn (50 + 10)")
	assert_eq(s.turn_number, 1, "advance_turn incrementa el contador de turno")


func test_advance_turn_recomputes_after_colonize() -> void:
	var s := AIRealState.new()
	var uncol := _make_location(Tile.location_type.Uncolonized, 0, 0)
	s.tiles[0] = _snap_from_tile(0, _make_resource(4, 0), uncol, [], AIRealState.OWNER_SELF)
	# Casilla ya propia pero todavía Uncolonized (sin producir): la colonizamos.
	s.tiles[0].owner = AIRealState.OWNER_NONE
	s.tiles[1] = _snap_from_tile(1, _make_resource(7, 0), uncol, [], AIRealState.OWNER_NONE)
	s.own.gold = 0
	AIRealSimulator.apply_colonize(s, 1)
	AIRealSimulator.advance_turn(s)
	assert_eq(s.own.gold_per_turn, 7, "Tras colonizar la tile 1, gpt = 7")
	assert_eq(s.own.gold, 7, "El ingreso del turno refleja la nueva casilla")


func test_advance_turn_progresses_rival_economy() -> void:
	var s := AIRealState.new()
	var village := _make_location(Tile.location_type.Village, 1, 0)
	s.tiles[0] = _snap_from_tile(0, _make_resource(8, 0), village, [], AIRealState.OWNER_RIVAL)
	s.rival.gold = 20
	AIRealSimulator.advance_turn(s)
	assert_eq(s.rival.gold_per_turn, 8, "El rival recalcula su gpt desde sus casillas")
	assert_eq(s.rival.gold, 28, "El rival acumula su ingreso (20 + 8)")


# ============================================================
#  clone
# ============================================================

func test_clone_is_independent_tiles() -> void:
	# Contrato copy-on-write: el clon comparte los TileSnap, pero mutarlo SOLO
	# vía AIRealSimulator (apply_*) clona la casilla, dejando el original intacto.
	var s := _state_one_owned_tile(_make_resource(5, 2))
	s.own.gold = 100
	var c := s.clone()
	AIRealSimulator.apply_build(c, 0, _make_building("x", 9, 0))
	var orig := s.tiles[0] as AIRealState.TileSnap
	assert_eq(orig.buildings.size(), 0, "Clonar (COW) no debe alterar los edificios del original")
	assert_eq((c.tiles[0] as AIRealState.TileSnap).buildings.size(), 1,
		"El clon sí refleja su propia mutación")


func test_clone_is_independent_empire() -> void:
	var s := _state_one_owned_tile(_make_resource(5, 2))
	s.own.gold = 100
	var c := s.clone()
	c.own.gold += 500
	c.turn_number += 3
	assert_eq(s.own.gold, 100, "Clonar no debe alterar el oro del original")
	assert_eq(s.turn_number, 0, "Clonar no debe alterar el turno del original")


func test_clone_shares_immutable_neighbor_ids() -> void:
	var s := _state_one_owned_tile(_make_resource(5, 2))
	(s.tiles[0] as AIRealState.TileSnap).neighbor_ids = [1, 2, 3]
	var c := s.clone()
	# Compartir por referencia es correcto porque neighbor_ids no se muta nunca.
	assert_eq((c.tiles[0] as AIRealState.TileSnap).neighbor_ids, [1, 2, 3],
		"El clon conserva la adyacencia")
