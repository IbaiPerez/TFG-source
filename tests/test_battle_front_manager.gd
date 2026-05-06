extends GutTest

## Tests para BattleFrontManager: apertura, límites, asignación.

var manager: BattleFrontManager
var stats: Stats
var atk_empire: Empire
var def_empire: Empire
var atk_tile: Tile
var def_tile: Tile
var isolated_tile: Tile


func _create_tile(biome: Tile.biome_type, empire: Empire) -> Tile:
	var tile := Tile.new()
	tile.mesh_data = TileMeshData.new()
	tile.mesh_data.type = biome
	tile.natural_resource = NaturalResource.new()
	tile.buildings = []
	tile.controller = empire
	return tile


func _create_troop(atk: int = 3, def: int = 3) -> Troop:
	var troop := Troop.new()
	troop.name = "Test"
	troop.attack = atk
	troop.defense = def
	troop.recruitment_cost_gold = 10
	troop.maintenance_gold = 2
	troop.maintenance_food = 1
	return troop


func before_each() -> void:
	# Limpiar el registro global de frentes para evitar interferencias entre tests
	BattleFront.clear_active_instances()

	atk_empire = Empire.new()
	atk_empire.name = "Atacante"
	def_empire = Empire.new()
	def_empire.name = "Defensor"

	atk_tile = _create_tile(Tile.biome_type.Grassland, atk_empire)
	def_tile = _create_tile(Tile.biome_type.Grassland, def_empire)
	atk_tile.neighbors = [def_tile]
	def_tile.neighbors = [atk_tile]

	isolated_tile = _create_tile(Tile.biome_type.Forest, def_empire)
	isolated_tile.neighbors = []

	atk_empire.controlled_tiles = [atk_tile]

	stats = Stats.new()
	stats.total_gold = 100
	stats.food = 50
	stats.troop_pool = []
	stats.empire = atk_empire

	manager = BattleFrontManager.new()
	manager.stats = stats
	manager.base_max_fronts = 1
	manager.tiles_per_extra_front = 5
	add_child(manager)


func after_each() -> void:
	BattleFront.clear_active_instances()
	if is_instance_valid(manager):
		manager.queue_free()
	for tile in [atk_tile, def_tile, isolated_tile]:
		if is_instance_valid(tile):
			tile.free()


# --- Tests de apertura de frentes ---

func test_open_front_success() -> void:
	var front := manager.open_front(atk_tile, def_tile)
	assert_not_null(front, "Debe poder abrir frente entre tiles adyacentes")
	assert_eq(manager.active_fronts.size(), 1)
	assert_eq(front.attacker_tile, atk_tile)
	assert_eq(front.defender_tile, def_tile)


func test_open_front_not_adjacent() -> void:
	var front := manager.open_front(atk_tile, isolated_tile)
	assert_null(front, "No debe abrir frente entre tiles no adyacentes")
	assert_eq(manager.active_fronts.size(), 0)


func test_open_front_duplicate_rejected() -> void:
	manager.open_front(atk_tile, def_tile)
	var duplicate := manager.open_front(atk_tile, def_tile)
	assert_null(duplicate, "No debe abrir frente duplicado entre mismas tiles")
	assert_eq(manager.active_fronts.size(), 1)


# --- Tests de exclusividad de tiles entre frentes ---

func test_cannot_open_front_with_attacker_tile_already_in_other_front() -> void:
	# El atacante ya tiene atk_tile metida en un frente
	manager.base_max_fronts = 5  # Asegurar que no es el límite quien rechaza
	manager.open_front(atk_tile, def_tile)

	# Otra tile defensora adyacente a atk_tile
	var other_def_tile := _create_tile(Tile.biome_type.Grassland, def_empire)
	atk_tile.neighbors.append(other_def_tile)
	other_def_tile.neighbors = [atk_tile]
	autofree(other_def_tile)

	var second := manager.open_front(atk_tile, other_def_tile)
	assert_null(second, "No debe permitir reusar atk_tile en otro frente")
	assert_eq(manager.active_fronts.size(), 1)


func test_cannot_open_front_with_defender_tile_already_in_other_front() -> void:
	# Imperio externo abre un frente sobre def_tile (frente fuera del manager local)
	var other_atk_empire := Empire.new()
	other_atk_empire.name = "Otro atacante"
	var other_atk_tile := _create_tile(Tile.biome_type.Grassland, other_atk_empire)
	other_atk_tile.neighbors = [def_tile]
	def_tile.neighbors.append(other_atk_tile)
	other_atk_empire.controlled_tiles = [other_atk_tile]
	autofree(other_atk_tile)

	var other_stats := Stats.new()
	other_stats.empire = other_atk_empire
	other_stats.troop_pool = []

	var other_manager := BattleFrontManager.new()
	other_manager.stats = other_stats
	other_manager.base_max_fronts = 1
	add_child(other_manager)
	# Frente externo: atk_tile_externo vs def_tile
	other_manager.open_front(other_atk_tile, def_tile)

	# Nuestro manager intenta abrir un frente que reusa def_tile
	var result := manager.open_front(atk_tile, def_tile)
	assert_null(result, "No debe permitir abrir un frente sobre una tile que otro imperio ya está atacando")
	assert_eq(manager.active_fronts.size(), 0)

	other_manager.queue_free()


# --- Tests de límite de frentes ---

func test_max_fronts_base() -> void:
	assert_eq(manager.get_max_fronts(), 1, "Con 1 tile y base_max=1: max=1")


func test_max_fronts_scales_with_tiles() -> void:
	# Añadimos tiles para que sumen 6 (1 base + 5 extra = +1)
	for i in range(5):
		var t := _create_tile(Tile.biome_type.Grassland, atk_empire)
		autofree(t)
		atk_empire.controlled_tiles.append(t)
	# 6 tiles / 5 per extra = 1 extra
	assert_eq(manager.get_max_fronts(), 2, "Con 6 tiles: 1 base + 1 extra = 2")


func test_cannot_open_beyond_limit() -> void:
	manager.base_max_fronts = 1
	manager.extra_max_fronts = 0

	manager.open_front(atk_tile, def_tile)
	assert_false(manager.can_open_front(), "Ya no debe poder abrir más frentes")


func test_extra_max_fronts_modifier() -> void:
	manager.extra_max_fronts = 2
	assert_eq(manager.get_max_fronts(), 3, "1 base + 0 tiles + 2 extra = 3")


# --- Tests de asignación de tropas ---

func test_assign_troop_to_front() -> void:
	var front := manager.open_front(atk_tile, def_tile)
	var troop := _create_troop()
	stats.troop_pool.append(troop)

	var success := manager.assign_troop_to_front(front, troop, &"attacker")
	assert_true(success)
	assert_eq(front.attacker_troops.size(), 1)
	assert_eq(stats.troop_pool.size(), 0, "Tropa debe salir del pool")


func test_assign_troop_not_in_pool() -> void:
	var front := manager.open_front(atk_tile, def_tile)
	var troop := _create_troop()  # No está en el pool

	var success := manager.assign_troop_to_front(front, troop, &"attacker")
	assert_false(success, "No debe asignar tropa que no está en el pool")


func test_assign_troop_to_resolved_front() -> void:
	var front := manager.open_front(atk_tile, def_tile)
	front.is_resolved = true
	var troop := _create_troop()
	stats.troop_pool.append(troop)

	var success := manager.assign_troop_to_front(front, troop, &"attacker")
	assert_false(success, "No debe asignar a frente resuelto")


# --- Tests de búsqueda ---

func test_get_front_for_tile() -> void:
	manager.open_front(atk_tile, def_tile)
	var found := manager.get_front_for_tile(atk_tile)
	assert_not_null(found)
	assert_eq(found.attacker_tile, atk_tile)


func test_get_front_for_tile_not_found() -> void:
	var found := manager.get_front_for_tile(isolated_tile)
	assert_null(found)
