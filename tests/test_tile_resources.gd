extends GutTest
## Tests para Tile (propiedades), LocationType, NaturalResource, PositionData, TileMeshData.


# ============================================================
#  NaturalResource
# ============================================================

func test_natural_resource_defaults():
	var res := NaturalResource.new()
	assert_eq(res.food_produced, 0)
	assert_eq(res.gold_produced, 0)


func test_natural_resource_with_values():
	var res := NaturalResource.new()
	res.name = "Wheat"
	res.gold_produced = 3
	res.food_produced = 5
	assert_eq(res.name, "Wheat")
	assert_eq(res.gold_produced, 3)
	assert_eq(res.food_produced, 5)


func test_natural_resource_biome_dictionary():
	var res := NaturalResource.new()
	# Default biome dictionary should have all 7 biome types
	assert_eq(res.biomes.size(), 7)
	assert_true(res.biomes.has(Tile.biome_type.Grassland))
	assert_true(res.biomes.has(Tile.biome_type.Ocean))
	assert_true(res.biomes.has(Tile.biome_type.Mountain))


# ============================================================
#  LocationType
# ============================================================

func test_location_type_properties():
	var loc := LocationType.new()
	loc.type = Tile.location_type.Village
	loc.max_building = 1
	loc.food_consumption = 1
	assert_eq(loc.type, Tile.location_type.Village)
	assert_eq(loc.max_building, 1)
	assert_eq(loc.food_consumption, 1)


func test_location_type_uncolonized():
	var loc := LocationType.new()
	loc.type = Tile.location_type.Uncolonized
	loc.max_building = 0
	loc.food_consumption = 0
	assert_eq(loc.max_building, 0, "Uncolonized should have 0 building slots")


func test_location_type_megalopolis():
	var loc := LocationType.new()
	loc.type = Tile.location_type.Megalopolis
	loc.max_building = 3
	assert_eq(loc.max_building, 3, "Megalopolis should have 3 building slots")


# ============================================================
#  PositionData
# ============================================================

func test_position_data_defaults():
	var pd := PositionData.new()
	assert_false(pd.buffer)
	assert_false(pd.water)
	assert_false(pd.mountain)
	assert_eq(pd.noise, 0.0)


func test_position_data_with_values():
	var pd := PositionData.new()
	pd.grid_position = Vector2i(3, 5)
	pd.world_position = Vector3(4.5, 0.0, 8.66)
	pd.noise = 0.75
	pd.water = true
	assert_eq(pd.grid_position, Vector2i(3, 5))
	assert_eq(pd.world_position.x, 4.5)
	assert_true(pd.water)
	assert_almost_eq(pd.noise, 0.75, 0.01)


# ============================================================
#  TileMeshData
# ============================================================

func test_tile_mesh_data_biome_type():
	var md := TileMeshData.new()
	md.type = Tile.biome_type.Desert
	md.color = Color.YELLOW
	assert_eq(md.type, Tile.biome_type.Desert)
	assert_eq(md.color, Color.YELLOW)


# ============================================================
#  Tile enum values
# ============================================================

func test_biome_type_enum():
	assert_eq(Tile.biome_type.Grassland, 0)
	assert_eq(Tile.biome_type.Forest, 1)
	assert_eq(Tile.biome_type.Desert, 2)
	assert_eq(Tile.biome_type.Swamp, 3)
	assert_eq(Tile.biome_type.Tundra, 4)
	assert_eq(Tile.biome_type.Ocean, 5)
	assert_eq(Tile.biome_type.Mountain, 6)


func test_location_type_enum():
	assert_eq(Tile.location_type.Uncolonized, 0)
	assert_eq(Tile.location_type.Village, 1)
	assert_eq(Tile.location_type.Town, 2)
	assert_eq(Tile.location_type.Megalopolis, 3)


# ============================================================
#  Tile.recalculate_modifiers
# ============================================================

func _make_tile(p_biome: Tile.biome_type = Tile.biome_type.Grassland,
		p_gold: int = 5, p_food: int = 2, p_loc_type: Tile.location_type = Tile.location_type.Village,
		p_max_buildings: int = 2, p_food_consumption: int = 1) -> Tile:
	var tile := Tile.new()
	tile.mesh_data = TileMeshData.new()
	tile.mesh_data.type = p_biome
	tile.mesh_data.color = Color.GREEN
	tile.natural_resource = NaturalResource.new()
	tile.natural_resource.gold_produced = p_gold
	tile.natural_resource.food_produced = p_food
	var loc := LocationType.new()
	loc.type = p_loc_type
	loc.max_building = p_max_buildings
	loc.food_consumption = p_food_consumption
	tile.location = loc
	tile.max_buildings = p_max_buildings
	tile.buildings = []
	tile.recalculate_modifiers()
	return tile


func test_recalculate_modifiers_base_production():
	var tile := _make_tile(Tile.biome_type.Grassland, 5, 3, Tile.location_type.Village, 2, 1)
	assert_eq(tile.gold_production, 5)
	assert_eq(tile.food_production, 2, "food = 3 produced - 1 consumed")


func test_recalculate_modifiers_with_building():
	var tile := _make_tile(Tile.biome_type.Grassland, 5, 3, Tile.location_type.Village, 2, 1)
	var b := Building.new()
	b.gold_produced = 4
	b.food_produced = 2
	b.effects = []
	tile.buildings.append(b)
	tile.recalculate_modifiers()
	assert_eq(tile.gold_production, 9, "5 base + 4 building")
	assert_eq(tile.food_production, 4, "3 - 1 + 2 building")


func test_recalculate_max_buildings_from_location():
	var tile := _make_tile(Tile.biome_type.Grassland, 5, 2, Tile.location_type.Town, 2, 2)
	assert_eq(tile.max_buildings, 2)


# ============================================================
#  Tile.set_controller
# ============================================================

func test_set_controller():
	var tile := _make_tile()
	add_child_autoqfree(tile)
	var empire := Empire.new()
	empire.name = "Test"
	empire.color = Color.RED
	tile.set_controller(empire)
	assert_eq(tile.controller, empire)


func test_set_controller_null():
	var tile := _make_tile()
	add_child_autoqfree(tile)
	var empire := Empire.new()
	tile.set_controller(empire)
	tile.set_controller(null)
	assert_null(tile.controller)


# ============================================================
#  Tile.get_hex_vertices
# ============================================================

func test_hex_vertices_returns_six():
	var tile := _make_tile()
	var verts := tile.get_hex_vertices()
	assert_eq(verts.size(), 6, "Hexagon should have 6 vertices")


func test_hex_vertices_unit_radius():
	var tile := _make_tile()
	var verts := tile.get_hex_vertices()
	for v in verts:
		var dist := sqrt(v.x * v.x + v.z * v.z)
		assert_almost_eq(dist, 1.0, 0.001, "Each vertex should be at radius 1")
