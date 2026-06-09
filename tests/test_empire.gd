extends GutTest
## Tests para Empire, EmpireAbility, y las habilidades específicas (Banking, Horde, Gardens).


# ============================================================
#  Helpers
# ============================================================

func _make_empire(p_name: String = "Test", p_color: Color = Color.RED) -> Empire:
	var e := Empire.new()
	e.name = p_name
	e.color = p_color
	e.controlled_tiles = []
	return e


func _make_tile() -> Tile:
	var tile := Tile.new()
	tile.mesh_data = TileMeshData.new()
	tile.mesh_data.type = Tile.biome_type.Grassland
	tile.mesh_data.color = Color.GREEN
	tile.natural_resource = NaturalResource.new()
	tile.natural_resource.gold_produced = 5
	tile.natural_resource.food_produced = 2
	var loc := LocationType.new()
	loc.type = Tile.location_type.Village
	loc.max_building = 1
	loc.food_consumption = 1
	tile.location = loc
	tile.max_buildings = 1
	tile.food_production = 1
	tile.gold_production = 5
	tile.neighbors = []
	return tile


# ============================================================
#  Empire base
# ============================================================

func test_empire_add_tile():
	var empire := _make_empire()
	var tile := _make_tile()
	add_child_autoqfree(tile)
	empire.add_tile(tile)
	assert_eq(empire.controlled_tiles.size(), 1)
	assert_eq(tile.controller, empire)


func test_empire_add_tile_emits_signal():
	var empire := _make_empire()
	var tile := _make_tile()
	add_child_autoqfree(tile)
	watch_signals(empire)
	empire.add_tile(tile)
	assert_signal_emitted(empire, "tile_conquered")


func test_empire_add_tile_no_duplicate():
	var empire := _make_empire()
	var tile := _make_tile()
	add_child_autoqfree(tile)
	empire.add_tile(tile)
	empire.add_tile(tile)
	assert_eq(empire.controlled_tiles.size(), 1)


func test_empire_remove_tile():
	var empire := _make_empire()
	var tile := _make_tile()
	add_child_autoqfree(tile)
	empire.add_tile(tile)
	empire.remove_tile(tile)
	assert_eq(empire.controlled_tiles.size(), 0)
	assert_null(tile.controller)


func test_empire_remove_tile_emits_signal():
	var empire := _make_empire()
	var tile := _make_tile()
	add_child_autoqfree(tile)
	empire.add_tile(tile)
	watch_signals(empire)
	empire.remove_tile(tile)
	assert_signal_emitted(empire, "tile_lost")


func test_empire_remove_tile_not_controlled_no_error():
	var empire := _make_empire()
	var tile := _make_tile()
	add_child_autoqfree(tile)
	# Should not crash
	empire.remove_tile(tile)
	assert_eq(empire.controlled_tiles.size(), 0)


func test_empire_reset_controlled_tiles():
	var empire := _make_empire()
	var t1 := _make_tile()
	var t2 := _make_tile()
	add_child_autoqfree(t1)
	add_child_autoqfree(t2)
	empire.add_tile(t1)
	empire.add_tile(t2)
	empire.reset_controlled_tiles()
	assert_eq(empire.controlled_tiles.size(), 0)


func test_empire_create_instance():
	var empire := _make_empire("Original", Color.BLUE)
	var instance := empire.create_instance()
	assert_eq(instance.name, "Original")
	assert_eq(instance.color, Color.BLUE)
	assert_eq(instance.controlled_tiles.size(), 0)
	assert_true(instance != empire, "Should be a different object")


# ============================================================
#  EmpireAbility base
# ============================================================

func test_base_ability_creates_no_modifiers():
	var ability := EmpireAbility.new()
	var mods := ability.create_modifiers()
	assert_eq(mods.size(), 0)


# ============================================================
#  BankingAbility
# ============================================================

func test_banking_ability_creates_two_modifiers():
	var ability := BankingAbility.new()
	var mods := ability.create_modifiers()
	assert_eq(mods.size(), 2, "Banking should create gold% + build cost modifiers")


func test_banking_ability_has_gold_percent_modifier():
	var ability := BankingAbility.new()
	var mods := ability.create_modifiers()
	var has_gold := false
	for mod in mods:
		if mod is StatModifier and mod.type == StatModifier.StatType.PERCENT_GOLD:
			has_gold = true
			assert_eq(mod.value, 15.0)
	assert_true(has_gold, "Should have a PERCENT_GOLD modifier")


func test_banking_ability_has_build_cost_modifier():
	var ability := BankingAbility.new()
	var mods := ability.create_modifiers()
	var has_cost := false
	for mod in mods:
		if mod is BuildCostModifier:
			has_cost = true
			assert_eq(mod.percent, 20.0)
	assert_true(has_cost, "Should have a BuildCostModifier")


# ============================================================
#  HordeAbility
# ============================================================

func test_horde_ability_creates_four_modifiers():
	# cards_per_turn + card_return + cavalry_maintenance (filtrado)
	var ability := HordeAbility.new()
	var mods := ability.create_modifiers()
	assert_eq(mods.size(), 3, "Horde should create 3 modifiers: cards, return, cavalry maintenance")


func test_horde_ability_has_cards_per_turn_modifier():
	var ability := HordeAbility.new()
	var mods := ability.create_modifiers()
	var has_cards := false
	for mod in mods:
		if mod is StatModifier and mod.type == StatModifier.StatType.CARDS_PER_TURN:
			has_cards = true
			assert_eq(mod.value, 1.0)
	assert_true(has_cards, "Should have a CARDS_PER_TURN modifier")


func test_horde_ability_has_card_return_modifier():
	var ability := HordeAbility.new()
	var mods := ability.create_modifiers()
	var has_return := false
	for mod in mods:
		if mod is CardReturnModifier:
			has_return = true
			assert_eq(mod.card_id, "Colonize")
			assert_almost_eq(mod.chance, 0.3, 0.01)
	assert_true(has_return, "Should have a CardReturnModifier for Colonize")


func test_horde_ability_has_no_cavalry_recruit_modifier():
	var ability := HordeAbility.new()
	var mods := ability.create_modifiers()
	for mod in mods:
		if mod is StatModifier:
			assert_ne(mod.type, StatModifier.StatType.TROOPS_PER_RECRUIT,
				"Horde no debe tener el modificador de reclutar caballería extra")


func test_horde_ability_has_cavalry_maintenance_modifier():
	var ability := HordeAbility.new()
	var mods := ability.create_modifiers()
	var found := false
	for mod in mods:
		if mod is StatModifier and mod.type == StatModifier.StatType.TROOP_MAINTENANCE_PERCENT:
			found = true
			assert_almost_eq(mod.value, -25.0, 0.001)
			assert_eq(mod.troop_type_filter, Troop.TroopType.CABALLERIA,
				"El modifier de mantenimiento debe estar filtrado a caballería")
	assert_true(found, "Horde should have a TROOP_MAINTENANCE_PERCENT modifier filtered to cavalry")


# ============================================================
#  GardensAbility
# ============================================================

func test_gardens_ability_without_wheat_creates_two_modifiers():
	# gold_on_card (Build Card) + PERCENT_GOLD (Rutas de Mesopotamia)
	var ability := GardensAbility.new()
	var mods := ability.create_modifiers()
	assert_eq(mods.size(), 2, "Without wheat resource: gold_on_card + trade_gold modifiers")


func test_gardens_ability_with_wheat_creates_three_modifiers():
	# TILE_RESOURCE_FOOD (trigo) + gold_on_card + PERCENT_GOLD (comercio)
	var ability := GardensAbility.new()
	ability.wheat_resource = NaturalResource.new()
	ability.wheat_resource.name = "Wheat"
	var mods := ability.create_modifiers()
	assert_eq(mods.size(), 3, "With wheat resource: food + gold_on_card + trade_gold modifiers")


func test_gardens_ability_has_gold_on_card_modifier():
	var ability := GardensAbility.new()
	var mods := ability.create_modifiers()
	var has_gold := false
	for mod in mods:
		if mod is GoldOnCardModifier:
			has_gold = true
			assert_eq(mod.card_id, "Build Card")
			assert_eq(mod.gold_amount, 3)
	assert_true(has_gold, "Should have a GoldOnCardModifier for Build Card")


func test_gardens_ability_wheat_food_modifier():
	var ability := GardensAbility.new()
	var wheat := NaturalResource.new()
	wheat.name = "Wheat"
	ability.wheat_resource = wheat
	var mods := ability.create_modifiers()
	var has_food := false
	for mod in mods:
		if mod is StatModifier and mod.type == StatModifier.StatType.TILE_RESOURCE_FOOD:
			has_food = true
			assert_eq(mod.value, 2.0)
			assert_eq(mod.target_resource, wheat)
	assert_true(has_food, "Should have a TILE_RESOURCE_FOOD modifier targeting wheat")


func test_gardens_ability_has_trade_gold_modifier():
	# Rutas de Mesopotamia: +10% producción de oro global (PERCENT_GOLD)
	var ability := GardensAbility.new()
	var mods := ability.create_modifiers()
	var has_trade := false
	for mod in mods:
		if mod is StatModifier and mod.type == StatModifier.StatType.PERCENT_GOLD:
			has_trade = true
			assert_almost_eq(mod.value, 10.0, 0.001,
				"Rutas de Mesopotamia debe dar +10% de oro")
	assert_true(has_trade, "GardensAbility debe incluir un modifier PERCENT_GOLD")
