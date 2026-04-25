extends GutTest
## Tests para Modifier base, StatModifier, BuildCostModifier, CardReturnModifier,
## GoldOnCardModifier, y ModifierManager.


# ============================================================
#  Helpers
# ============================================================

func _make_stats(p_gold: int = 100) -> Stats:
	var s := Stats.new()
	s.total_gold = p_gold
	s.gold_per_turn = 10
	s.food = 5
	s.cards_per_turn = 3
	s.draw_pile = CardPile.new()
	s.discard_pile = CardPile.new()
	s.played_pile = CardPile.new()
	s.empire = Empire.new()
	return s


func _make_resource(p_name: String = "Iron") -> NaturalResource:
	var res := NaturalResource.new()
	res.name = p_name
	return res


func _make_tile_with_resource(res: NaturalResource) -> Tile:
	var tile := Tile.new()
	tile.natural_resource = res
	var md := TileMeshData.new()
	md.type = Tile.biome_type.Grassland
	tile.mesh_data = md
	var loc := LocationType.new()
	loc.type = Tile.location_type.Village
	loc.max_building = 1
	loc.food_consumption = 0
	tile.location = loc
	tile.max_buildings = 1
	return tile


# ============================================================
#  Modifier base
# ============================================================

func test_modifier_init_defaults():
	var mod := Modifier.new("test", "Test Mod", 3)
	assert_eq(mod.id, "test")
	assert_eq(mod.name, "Test Mod")
	assert_eq(mod.duration, 3)


func test_modifier_activate_sets_stats():
	var mod := Modifier.new("test", "Test", -1)
	var stats := _make_stats()
	mod.activate(stats)
	assert_eq(mod.stats, stats)


func test_modifier_deactivate_clears_stats():
	var mod := Modifier.new("test", "Test", -1)
	var stats := _make_stats()
	mod.activate(stats)
	mod.deactivate()
	assert_null(mod.stats)


func test_modifier_permanent_duration():
	var mod := Modifier.new("perm", "Permanent", -1)
	assert_eq(mod.duration, -1, "Duration -1 means permanent")


# ============================================================
#  StatModifier
# ============================================================

func test_stat_modifier_flat_gold():
	var mod := StatModifier.new("sg", "Gold", StatModifier.StatType.FLAT_GOLD, 10.0, 3)
	assert_eq(mod.type, StatModifier.StatType.FLAT_GOLD)
	assert_eq(mod.value, 10.0)
	assert_eq(mod.duration, 3)


func test_stat_modifier_description_flat_gold_positive():
	var mod := StatModifier.new("sg", "Gold", StatModifier.StatType.FLAT_GOLD, 5.0, -1)
	assert_true(mod.description.contains("+5"), "Description should contain +5")
	assert_true(mod.description.contains("gold"), "Description should mention gold")


func test_stat_modifier_description_flat_gold_negative():
	var mod := StatModifier.new("sg", "Gold", StatModifier.StatType.FLAT_GOLD, -3.0, -1)
	assert_true(mod.description.contains("-3"), "Description should contain -3")


func test_stat_modifier_description_percent_gold():
	var mod := StatModifier.new("sg", "Gold%", StatModifier.StatType.PERCENT_GOLD, 15.0, -1)
	assert_true(mod.description.contains("15%"), "Description should contain percentage")


func test_stat_modifier_description_cards_per_turn():
	var mod := StatModifier.new("sc", "Cards", StatModifier.StatType.CARDS_PER_TURN, 1.0, -1)
	assert_true(mod.description.contains("card"), "Description should mention card")


func test_stat_modifier_description_tile_resource():
	var iron := _make_resource("Iron")
	var mod := StatModifier.new("sr", "Iron Gold", StatModifier.StatType.TILE_RESOURCE_GOLD, 3.0, -1, null, iron)
	assert_true(mod.description.contains("Iron"), "Description should mention resource name")


func test_stat_modifier_duplicate():
	var mod := StatModifier.new("sg", "Gold", StatModifier.StatType.FLAT_GOLD, 10.0, 5)
	var dup := mod.duplicate_modifier()
	assert_eq(dup.id, "sg")
	assert_true(dup is StatModifier)
	assert_eq((dup as StatModifier).value, 10.0)


# ============================================================
#  BuildCostModifier
# ============================================================

func test_build_cost_modifier_discount():
	var mod := BuildCostModifier.new("bc", "Discount", 20.0, -1)
	assert_eq(mod.percent, 20.0)
	assert_true(mod.description.contains("20%"))


func test_build_cost_modifier_increase():
	var mod := BuildCostModifier.new("bc", "Tax", -15.0, -1)
	assert_eq(mod.percent, -15.0)
	assert_true(mod.description.contains("15%"))


func test_build_cost_modifier_duplicate():
	var mod := BuildCostModifier.new("bc", "Disc", 25.0, 3)
	var dup := mod.duplicate_modifier()
	assert_true(dup is BuildCostModifier)
	assert_eq((dup as BuildCostModifier).percent, 25.0)


# ============================================================
#  CardReturnModifier
# ============================================================

func test_card_return_should_return_matching_card():
	var mod := CardReturnModifier.new("cr", "Return", "Colonize", 1.0, -1)
	var card := Card.new()
	card.id = "Colonize"
	# chance is 1.0 so always returns
	assert_true(mod.should_return(card))


func test_card_return_does_not_return_wrong_card():
	var mod := CardReturnModifier.new("cr", "Return", "Colonize", 1.0, -1)
	var card := Card.new()
	card.id = "Build"
	assert_false(mod.should_return(card))


func test_card_return_only_once_per_turn():
	var mod := CardReturnModifier.new("cr", "Return", "Colonize", 1.0, -1)
	var card := Card.new()
	card.id = "Colonize"
	assert_true(mod.should_return(card), "First call should return true")
	assert_false(mod.should_return(card), "Second call same turn should return false")


func test_card_return_resets_on_turn_start():
	var mod := CardReturnModifier.new("cr", "Return", "Colonize", 1.0, -1)
	var card := Card.new()
	card.id = "Colonize"
	mod.should_return(card)  # use it
	mod.on_turn_start()  # reset
	assert_true(mod.should_return(card), "After reset should return true again")


# ============================================================
#  ModifierManager
# ============================================================

var manager: ModifierManager


func before_each():
	manager = ModifierManager.new()
	add_child_autoqfree(manager)


func test_add_modifier():
	var stats := _make_stats()
	var mod := Modifier.new("test", "Test", -1)
	manager.add_modifier(mod, stats)
	assert_eq(manager.active_modifiers.size(), 1)


func test_add_modifier_emits_signals():
	var stats := _make_stats()
	var mod := Modifier.new("test", "Test", -1)
	watch_signals(manager)
	manager.add_modifier(mod, stats)
	assert_signal_emitted(manager, "modifier_added")
	assert_signal_emitted(manager, "modifiers_changed")


func test_remove_modifier():
	var stats := _make_stats()
	var mod := Modifier.new("test", "Test", -1)
	manager.add_modifier(mod, stats)
	manager.remove_modifier(mod)
	assert_eq(manager.active_modifiers.size(), 0)


func test_remove_modifier_emits_signals():
	var stats := _make_stats()
	var mod := Modifier.new("test", "Test", -1)
	manager.add_modifier(mod, stats)
	watch_signals(manager)
	manager.remove_modifier(mod)
	assert_signal_emitted(manager, "modifier_removed")
	assert_signal_emitted(manager, "modifiers_changed")


func test_tick_decreases_duration():
	var stats := _make_stats()
	var mod := Modifier.new("test", "Test", 3)
	manager.add_modifier(mod, stats)
	manager.tick()
	assert_eq(mod.duration, 2)


func test_tick_removes_expired_modifiers():
	var stats := _make_stats()
	var mod := Modifier.new("test", "Test", 1)
	manager.add_modifier(mod, stats)
	manager.tick()
	assert_eq(manager.active_modifiers.size(), 0, "Expired modifier should be removed")


func test_tick_does_not_touch_permanent():
	var stats := _make_stats()
	var mod := Modifier.new("perm", "Permanent", -1)
	manager.add_modifier(mod, stats)
	manager.tick()
	manager.tick()
	assert_eq(manager.active_modifiers.size(), 1, "Permanent modifier should remain")
	assert_eq(mod.duration, -1)


func test_get_flat_gold():
	var stats := _make_stats()
	var m1 := StatModifier.new("g1", "Gold1", StatModifier.StatType.FLAT_GOLD, 5.0, -1)
	var m2 := StatModifier.new("g2", "Gold2", StatModifier.StatType.FLAT_GOLD, 3.0, -1)
	manager.add_modifier(m1, stats)
	manager.add_modifier(m2, stats)
	assert_eq(manager.get_flat_gold(), 8)


func test_get_percent_gold():
	var stats := _make_stats()
	var mod := StatModifier.new("gp", "Gold%", StatModifier.StatType.PERCENT_GOLD, 15.0, -1)
	manager.add_modifier(mod, stats)
	assert_almost_eq(manager.get_percent_gold(), 15.0, 0.01)


func test_get_flat_food():
	var stats := _make_stats()
	var mod := StatModifier.new("f1", "Food", StatModifier.StatType.FLAT_FOOD, 4.0, -1)
	manager.add_modifier(mod, stats)
	assert_eq(manager.get_flat_food(), 4)


func test_get_percent_food():
	var stats := _make_stats()
	var mod := StatModifier.new("fp", "Food%", StatModifier.StatType.PERCENT_FOOD, 20.0, -1)
	manager.add_modifier(mod, stats)
	assert_almost_eq(manager.get_percent_food(), 20.0, 0.01)


func test_get_cards_per_turn_bonus():
	var stats := _make_stats()
	var mod := StatModifier.new("cp", "Cards", StatModifier.StatType.CARDS_PER_TURN, 2.0, -1)
	manager.add_modifier(mod, stats)
	assert_eq(manager.get_cards_per_turn_bonus(), 2)


func test_get_card_draw_bonus():
	var stats := _make_stats()
	var mod := StatModifier.new("cd", "Draw", StatModifier.StatType.CARD_DRAW_BONUS, 1.0, -1)
	manager.add_modifier(mod, stats)
	assert_eq(manager.get_card_draw_bonus(), 1)


func test_get_tile_gold_bonus():
	var iron := _make_resource("Iron")
	var tile := _make_tile_with_resource(iron)
	var stats := _make_stats()
	var mod := StatModifier.new("tg", "Tile Gold", StatModifier.StatType.TILE_RESOURCE_GOLD,
			5.0, -1, null, iron)
	manager.add_modifier(mod, stats)
	assert_eq(manager.get_tile_gold_bonus(tile), 5)


func test_get_tile_gold_bonus_no_match():
	var iron := _make_resource("Iron")
	var gold_res := _make_resource("Gold")
	var tile := _make_tile_with_resource(iron)
	var stats := _make_stats()
	var mod := StatModifier.new("tg", "Gold Tile", StatModifier.StatType.TILE_RESOURCE_GOLD,
			5.0, -1, null, gold_res)
	manager.add_modifier(mod, stats)
	assert_eq(manager.get_tile_gold_bonus(tile), 0, "Non-matching resource should give 0 bonus")


func test_get_build_cost_multiplier_discount():
	var stats := _make_stats()
	var mod := BuildCostModifier.new("bc", "Disc", 20.0, -1)
	manager.add_modifier(mod, stats)
	assert_almost_eq(manager.get_build_cost_multiplier(), 0.8, 0.001)


func test_get_build_cost_multiplier_increase():
	var stats := _make_stats()
	var mod := BuildCostModifier.new("bc", "Tax", -15.0, -1)
	manager.add_modifier(mod, stats)
	assert_almost_eq(manager.get_build_cost_multiplier(), 1.15, 0.001)


func test_get_build_cost_multiplier_stacked():
	var stats := _make_stats()
	var m1 := BuildCostModifier.new("bc1", "D1", 20.0, -1)
	var m2 := BuildCostModifier.new("bc2", "D2", 10.0, -1)
	manager.add_modifier(m1, stats)
	manager.add_modifier(m2, stats)
	# 20 + 10 = 30% discount => multiplier 0.7
	assert_almost_eq(manager.get_build_cost_multiplier(), 0.7, 0.001)


func test_should_return_to_hand():
	var stats := _make_stats()
	var mod := CardReturnModifier.new("cr", "Ret", "Colonize", 1.0, -1)
	manager.add_modifier(mod, stats)
	var card := Card.new()
	card.id = "Colonize"
	assert_true(manager.should_return_to_hand(card))


func test_should_return_to_hand_false_for_wrong_card():
	var stats := _make_stats()
	var mod := CardReturnModifier.new("cr", "Ret", "Colonize", 1.0, -1)
	manager.add_modifier(mod, stats)
	var card := Card.new()
	card.id = "Build"
	assert_false(manager.should_return_to_hand(card))


func test_multiple_ticks_expire_correctly():
	var stats := _make_stats()
	var m1 := Modifier.new("m1", "Short", 2)
	var m2 := Modifier.new("m2", "Long", 5)
	manager.add_modifier(m1, stats)
	manager.add_modifier(m2, stats)
	manager.tick()  # m1=1, m2=4
	assert_eq(manager.active_modifiers.size(), 2)
	manager.tick()  # m1 expires, m2=3
	assert_eq(manager.active_modifiers.size(), 1)
	assert_eq(manager.active_modifiers[0].id, "m2")
