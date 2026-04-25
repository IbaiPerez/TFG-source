extends GutTest
## Tests para el patrón Condition/Effect de las cartas y BuildingEffect.


# ============================================================
#  Helpers
# ============================================================

func _make_empire() -> Empire:
	var e := Empire.new()
	e.name = "Test"
	e.color = Color.RED
	e.controlled_tiles = []
	return e


func _make_tile(p_controller: Empire = null, p_biome: Tile.biome_type = Tile.biome_type.Grassland) -> Tile:
	var tile := Tile.new()
	tile.mesh_data = TileMeshData.new()
	tile.mesh_data.type = p_biome
	tile.mesh_data.color = Color.GREEN
	tile.natural_resource = NaturalResource.new()
	tile.natural_resource.gold_produced = 5
	tile.natural_resource.food_produced = 2
	var loc := LocationType.new()
	loc.type = Tile.location_type.Village
	loc.max_building = 2
	loc.food_consumption = 1
	tile.location = loc
	tile.max_buildings = 2
	tile.food_production = 1
	tile.gold_production = 5
	tile.controller = p_controller
	tile.neighbors = []
	tile.buildings = []
	return tile


func _make_stats(p_gold: int = 200) -> Stats:
	var s := Stats.new()
	s.total_gold = p_gold
	s.gold_per_turn = 10
	s.food = 5
	s.cards_per_turn = 3
	s.draw_pile = CardPile.new()
	s.discard_pile = CardPile.new()
	s.played_pile = CardPile.new()
	s.empire = _make_empire()
	s.possible_buildings = []
	return s


func _make_building(p_name: String = "Mine", p_cost: int = 50) -> Building:
	var b := Building.new()
	b.name = p_name
	b.construction_cost = p_cost
	b.gold_produced = 3
	b.food_produced = 0
	b.effects = []
	b.upgrades_to = []
	b.allowed_location_type = []
	b.allowed_biomes = []
	return b


# ============================================================
#  Condition base
# ============================================================

func test_base_condition_returns_empty_targets():
	var cond := Condition.new()
	assert_eq(cond.valid_targets().size(), 0)


func test_base_condition_is_valid_false():
	var cond := Condition.new()
	var node := Node.new()
	assert_false(cond.is_valid_target(node))
	node.free()


# ============================================================
#  BuildCondition
# ============================================================

func test_build_condition_valid_for_owned_tile():
	var stats := _make_stats(200)
	var tile := _make_tile(stats.empire)
	add_child_autoqfree(tile)
	var building := _make_building("Mine", 50)
	var cond := BuildCondition.new()
	cond.buildings = [building]
	cond.stats = stats
	assert_true(cond.is_valid_target(tile))


func test_build_condition_invalid_for_enemy_tile():
	var stats := _make_stats(200)
	var enemy := _make_empire()
	var tile := _make_tile(enemy)
	add_child_autoqfree(tile)
	var building := _make_building("Mine", 50)
	var cond := BuildCondition.new()
	cond.buildings = [building]
	cond.stats = stats
	assert_false(cond.is_valid_target(tile))


func test_build_condition_invalid_for_non_tile():
	var stats := _make_stats()
	var cond := BuildCondition.new()
	cond.buildings = [_make_building()]
	cond.stats = stats
	var node := Node.new()
	assert_false(cond.is_valid_target(node))
	node.free()


func test_build_condition_invalid_no_buildings():
	var stats := _make_stats()
	var tile := _make_tile(stats.empire)
	add_child_autoqfree(tile)
	var cond := BuildCondition.new()
	cond.buildings = []
	cond.stats = stats
	assert_false(cond.is_valid_target(tile))


func test_build_condition_invalid_not_enough_gold():
	var stats := _make_stats(10)
	var tile := _make_tile(stats.empire)
	add_child_autoqfree(tile)
	var building := _make_building("Mine", 50)
	var cond := BuildCondition.new()
	cond.buildings = [building]
	cond.stats = stats
	assert_false(cond.is_valid_target(tile))


func test_build_condition_valid_targets():
	var stats := _make_stats(200)
	var t1 := _make_tile(stats.empire)
	var t2 := _make_tile(stats.empire)
	add_child_autoqfree(t1)
	add_child_autoqfree(t2)
	stats.empire.controlled_tiles = [t1, t2]
	var building := _make_building("Mine", 50)
	var cond := BuildCondition.new()
	cond.buildings = [building]
	cond.stats = stats
	var targets := cond.valid_targets()
	assert_eq(targets.size(), 2)


# ============================================================
#  AdjacentCondition
# ============================================================

func test_adjacent_condition_valid_target():
	var empire := _make_empire()
	var owned := _make_tile(empire)
	var unowned := _make_tile(null)
	add_child_autoqfree(owned)
	add_child_autoqfree(unowned)
	unowned.neighbors = [owned]
	owned.neighbors = [unowned]
	empire.controlled_tiles = [owned]

	var cond := AdjacentCondition.new()
	cond.empire = empire
	assert_true(cond.is_valid_target(unowned))


func test_adjacent_condition_invalid_already_owned():
	var empire := _make_empire()
	var owned := _make_tile(empire)
	add_child_autoqfree(owned)
	empire.controlled_tiles = [owned]

	var cond := AdjacentCondition.new()
	cond.empire = empire
	assert_false(cond.is_valid_target(owned), "Already-controlled tile is not valid")


func test_adjacent_condition_invalid_not_adjacent():
	var empire := _make_empire()
	var owned := _make_tile(empire)
	var far := _make_tile(null)
	add_child_autoqfree(owned)
	add_child_autoqfree(far)
	far.neighbors = []  # not adjacent to owned
	empire.controlled_tiles = [owned]

	var cond := AdjacentCondition.new()
	cond.empire = empire
	assert_false(cond.is_valid_target(far))


func test_adjacent_condition_valid_targets():
	var empire := _make_empire()
	var owned := _make_tile(empire)
	var adj1 := _make_tile(null)
	var adj2 := _make_tile(null)
	add_child_autoqfree(owned)
	add_child_autoqfree(adj1)
	add_child_autoqfree(adj2)
	owned.neighbors = [adj1, adj2]
	adj1.neighbors = [owned]
	adj2.neighbors = [owned]
	empire.controlled_tiles = [owned]

	var cond := AdjacentCondition.new()
	cond.empire = empire
	var targets := cond.valid_targets()
	assert_eq(targets.size(), 2)


# ============================================================
#  UpgradeBuildingCondition
# ============================================================

func test_upgrade_condition_valid():
	var stats := _make_stats(200)
	var tile := _make_tile(stats.empire)
	add_child_autoqfree(tile)
	var old_b := _make_building("Mine", 50)
	var upgrade := _make_building("Better Mine", 80)
	old_b.upgrades_to = [upgrade]
	tile.buildings = [old_b]
	stats.empire.controlled_tiles = [tile]

	var cond := UpgradeBuildingCondition.new()
	cond.stats = stats
	assert_true(cond.is_valid_target(tile))


func test_upgrade_condition_invalid_no_upgradable():
	var stats := _make_stats(200)
	var tile := _make_tile(stats.empire)
	add_child_autoqfree(tile)
	var b := _make_building("Mine", 50)
	b.upgrades_to = []
	tile.buildings = [b]

	var cond := UpgradeBuildingCondition.new()
	cond.stats = stats
	assert_false(cond.is_valid_target(tile))


# ============================================================
#  GenerateGoldEffect
# ============================================================

func test_generate_gold_effect():
	var effect := GenerateGoldEffect.new()
	effect.amount = 75
	var stats := _make_stats(100)
	effect.stats = stats
	effect.execute([])
	assert_eq(stats.total_gold, 175)


func test_generate_gold_effect_no_stats():
	var effect := GenerateGoldEffect.new()
	effect.amount = 75
	# stats is null - should not crash
	effect.execute([])


# ============================================================
#  BuildEffect
# ============================================================

func test_build_effect_builds_on_tile():
	var stats := _make_stats(200)
	var tile := _make_tile(stats.empire)
	add_child_autoqfree(tile)
	var building := _make_building("Mine", 50)

	var effect := BuildEffect.new()
	effect.building = building
	effect.stats = stats
	var targets: Array[Node] = [tile]
	effect.execute(targets)

	assert_eq(tile.buildings.size(), 1)
	assert_eq(stats.total_gold, 150)


func test_build_effect_no_building():
	var stats := _make_stats(200)
	var tile := _make_tile(stats.empire)
	add_child_autoqfree(tile)

	var effect := BuildEffect.new()
	# building is null
	var targets: Array[Node] = [tile]
	effect.execute(targets)
	assert_eq(tile.buildings.size(), 0, "Should do nothing without building")


# ============================================================
#  BuildingEffect base
# ============================================================

func test_building_effect_base_does_nothing():
	var effect := BuildingEffect.new()
	var tile := _make_tile()
	add_child_autoqfree(tile)
	var stats := _make_stats()
	# Should not crash
	effect.apply_effect(tile, stats)
	effect.remove_effect(tile, stats)
