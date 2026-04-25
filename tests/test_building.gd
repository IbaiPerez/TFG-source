extends GutTest
## Tests para Building y su lógica de construcción/mejora en tiles.


func _make_resource(p_name: String = "Iron") -> NaturalResource:
	var res := NaturalResource.new()
	res.name = p_name
	res.gold_produced = 5
	res.food_produced = 2
	return res


func _make_location(p_type: Tile.location_type = Tile.location_type.Village,
		p_max: int = 2) -> LocationType:
	var loc := LocationType.new()
	loc.type = p_type
	loc.max_building = p_max
	loc.food_consumption = 1
	return loc


func _make_mesh_data(p_biome: Tile.biome_type = Tile.biome_type.Grassland) -> TileMeshData:
	var md := TileMeshData.new()
	md.color = Color.GREEN
	md.type = p_biome
	return md


func _make_tile(p_biome: Tile.biome_type = Tile.biome_type.Grassland,
		p_resource_name: String = "Iron",
		p_location_type: Tile.location_type = Tile.location_type.Village,
		p_max_buildings: int = 2) -> Tile:
	var tile := Tile.new()
	tile.mesh_data = _make_mesh_data(p_biome)
	tile.natural_resource = _make_resource(p_resource_name)
	tile.location = _make_location(p_location_type, p_max_buildings)
	# Skip set_parameters (needs mesh children) - set values directly
	tile.max_buildings = p_max_buildings
	tile.food_production = tile.natural_resource.food_produced - tile.location.food_consumption
	tile.gold_production = tile.natural_resource.gold_produced
	return tile


func _make_building(p_name: String = "Mine", p_cost: int = 50,
		p_gold: int = 3, p_food: int = 0,
		p_required_resource: NaturalResource = null,
		p_allowed_locations: Array[LocationType] = [],
		p_allowed_biomes: Array[Tile.biome_type] = []) -> Building:
	var b := Building.new()
	b.name = p_name
	b.construction_cost = p_cost
	b.gold_produced = p_gold
	b.food_produced = p_food
	b.required_natural_resource = p_required_resource
	b.allowed_location_type = p_allowed_locations
	b.allowed_biomes = p_allowed_biomes
	b.effects = []
	b.upgrades_to = []
	return b


func _make_stats(p_gold: int = 200) -> Stats:
	var s := Stats.new()
	s.total_gold = p_gold
	s.gold_per_turn = 0
	s.food = 0
	s.draw_pile = CardPile.new()
	s.discard_pile = CardPile.new()
	s.played_pile = CardPile.new()
	s.empire = Empire.new()
	return s


# --- Building.can_be_upgraded ---

func test_can_be_upgraded_true_when_affordable():
	var upgrade := _make_building("Better Mine", 30)
	var building := _make_building("Mine", 50)
	building.upgrades_to = [upgrade]
	var stats := _make_stats(50)
	assert_true(building.can_be_upgraded(stats))


func test_can_be_upgraded_false_when_too_expensive():
	var upgrade := _make_building("Better Mine", 100)
	var building := _make_building("Mine", 50)
	building.upgrades_to = [upgrade]
	var stats := _make_stats(10)
	assert_false(building.can_be_upgraded(stats))


func test_can_be_upgraded_false_with_no_upgrades():
	var building := _make_building("Mine", 50)
	building.upgrades_to = []
	var stats := _make_stats(999)
	assert_false(building.can_be_upgraded(stats))


# --- Tile.can_build ---

func test_can_build_basic_success():
	var tile := _make_tile()
	var building := _make_building("Mine", 50)
	assert_true(tile.can_build(building))


func test_can_build_fails_when_max_buildings_reached():
	var tile := _make_tile(Tile.biome_type.Grassland, "Iron", Tile.location_type.Village, 1)
	var b1 := _make_building("Mine1")
	tile.buildings.append(b1)
	var b2 := _make_building("Mine2")
	assert_false(tile.can_build(b2), "Should not build beyond max_buildings")


func test_can_build_fails_when_building_already_exists():
	var tile := _make_tile()
	var building := _make_building("Mine")
	tile.buildings.append(building)
	assert_false(tile.can_build(building), "Duplicate building should fail")


func test_can_build_fails_wrong_natural_resource():
	var tile := _make_tile(Tile.biome_type.Grassland, "Iron")
	var gold_resource := _make_resource("Gold")
	var building := _make_building("Gold Mine", 50, 3, 0, gold_resource)
	assert_false(tile.can_build(building), "Wrong resource should fail")


func test_can_build_succeeds_matching_natural_resource():
	var iron := _make_resource("Iron")
	var tile := _make_tile()
	tile.natural_resource = iron
	var building := _make_building("Iron Mine", 50, 3, 0, iron)
	assert_true(tile.can_build(building))


func test_can_build_fails_wrong_location_type():
	var village_loc := _make_location(Tile.location_type.Village)
	var town_loc := _make_location(Tile.location_type.Town)
	var tile := _make_tile()
	tile.location = village_loc
	var building := _make_building()
	building.allowed_location_type = [town_loc]
	assert_false(tile.can_build(building))


func test_can_build_fails_wrong_biome():
	var tile := _make_tile(Tile.biome_type.Desert)
	var building := _make_building()
	building.allowed_biomes = [Tile.biome_type.Forest]
	assert_false(tile.can_build(building))


func test_can_build_succeeds_matching_biome():
	var tile := _make_tile(Tile.biome_type.Forest)
	var building := _make_building()
	building.allowed_biomes = [Tile.biome_type.Forest, Tile.biome_type.Grassland]
	assert_true(tile.can_build(building))


# --- Tile.build ---

func test_build_adds_building_to_tile():
	var tile := _make_tile()
	var building := _make_building("Mine", 50, 3, 0)
	var stats := _make_stats(200)
	tile.build(building, stats)
	assert_eq(tile.buildings.size(), 1)


func test_build_deducts_gold():
	var tile := _make_tile()
	var building := _make_building("Mine", 50)
	var stats := _make_stats(200)
	tile.build(building, stats)
	assert_eq(stats.total_gold, 150)


func test_build_does_nothing_if_cannot_build():
	var tile := _make_tile(Tile.biome_type.Grassland, "Iron", Tile.location_type.Village, 0)
	var building := _make_building("Mine", 50)
	var stats := _make_stats(200)
	tile.build(building, stats)
	assert_eq(tile.buildings.size(), 0)
	assert_eq(stats.total_gold, 200, "Gold should not be deducted")


func test_build_recalculates_production():
	var tile := _make_tile()
	var building := _make_building("Mine", 50, 10, 5)
	var stats := _make_stats(200)
	var old_gold := tile.gold_production
	tile.build(building, stats)
	assert_gt(tile.gold_production, old_gold, "Gold production should increase")


# --- Tile.get_valid_buildings ---

func test_get_valid_buildings_filters_correctly():
	var tile := _make_tile(Tile.biome_type.Grassland)
	var valid := _make_building("Valid")
	var invalid := _make_building("Invalid")
	invalid.allowed_biomes = [Tile.biome_type.Desert]
	var options: Array[Building] = [valid, invalid]
	var result := tile.get_valid_buildings(options)
	assert_eq(result.size(), 1)
	assert_eq(result[0].name, "Valid")


# --- Tile.can_upgrade ---

func test_can_upgrade_success():
	var old_b := _make_building("Mine", 50)
	var new_b := _make_building("Better Mine", 80)
	old_b.upgrades_to = [new_b]
	var tile := _make_tile()
	tile.buildings.append(old_b)
	assert_true(tile.can_upgrade(old_b, new_b))


func test_can_upgrade_fails_building_not_on_tile():
	var old_b := _make_building("Mine")
	var new_b := _make_building("Better Mine")
	old_b.upgrades_to = [new_b]
	var tile := _make_tile()
	# old_b not in tile.buildings
	assert_false(tile.can_upgrade(old_b, new_b))


func test_can_upgrade_fails_not_in_upgrade_path():
	var old_b := _make_building("Mine")
	var new_b := _make_building("Unrelated")
	old_b.upgrades_to = []
	var tile := _make_tile()
	tile.buildings.append(old_b)
	assert_false(tile.can_upgrade(old_b, new_b))


# --- Tile.upgrade ---

func test_upgrade_replaces_building():
	var old_b := _make_building("Mine", 50, 3, 0)
	var new_b := _make_building("Better Mine", 80, 8, 0)
	old_b.upgrades_to = [new_b]
	var tile := _make_tile()
	tile.buildings.append(old_b)
	var stats := _make_stats(200)
	tile.upgrade(old_b, new_b, stats)
	assert_eq(tile.buildings.size(), 1)
	assert_eq(tile.buildings[0].name, "Better Mine")


func test_upgrade_deducts_new_building_cost():
	var old_b := _make_building("Mine", 50, 3, 0)
	var new_b := _make_building("Better Mine", 80, 8, 0)
	old_b.upgrades_to = [new_b]
	var tile := _make_tile()
	tile.buildings.append(old_b)
	var stats := _make_stats(200)
	tile.upgrade(old_b, new_b, stats)
	assert_eq(stats.total_gold, 120)


# --- Tile.demolish ---

func test_demolish_removes_building():
	var building := _make_building("Mine")
	var tile := _make_tile()
	tile.buildings.append(building)
	var stats := _make_stats()
	tile.demolish(building, stats)
	assert_eq(tile.buildings.size(), 0)


func test_demolish_does_nothing_for_missing_building():
	var building := _make_building("Mine")
	var tile := _make_tile()
	var stats := _make_stats()
	tile.demolish(building, stats)
	assert_eq(tile.buildings.size(), 0)


# --- Tile.recalculate_modifiers ---

func test_recalculate_modifiers_includes_buildings():
	var tile := _make_tile()
	var b := _make_building("Mine", 50, 10, 5)
	tile.buildings.append(b)
	tile.recalculate_modifiers()
	assert_eq(tile.gold_production, tile.natural_resource.gold_produced + 10)
