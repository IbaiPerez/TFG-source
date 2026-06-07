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
	autofree(tile)
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


func test_get_build_cost_multiplier_clamps_at_min():
	# Regla de juego: por mucho que apilemos descuentos, el coste minimo
	# siempre es 20% del original. Apilamos 4 modifiers de -30% (= -120%
	# combinado, que sin clamp daria un multiplier de -0.2, oro al cobrar
	# por construir!). El clamp lo dispara MIN_COST_MULTIPLIER.
	var stats := _make_stats()
	for i in 4:
		manager.add_modifier(BuildCostModifier.new("d%d" % i, "D%d" % i, 30.0, -1), stats)
	# Sin clamp: 1 - 1.20 = -0.20. Con clamp: 0.20.
	assert_almost_eq(manager.get_build_cost_multiplier(),
			ModifierManager.MIN_COST_MULTIPLIER, 0.001,
		"Multiplicador debe quedar topado en MIN_COST_MULTIPLIER (0.2)")


func test_get_build_cost_multiplier_does_not_clamp_surcharges():
	# Encarecimientos (percent negativo) NO se topan. Un modifier de
	# -50% (encarece 50%) debe dar multiplier 1.5 sin recorte.
	var stats := _make_stats()
	manager.add_modifier(BuildCostModifier.new("sur", "Surcharge", -50.0, -1), stats)
	assert_almost_eq(manager.get_build_cost_multiplier(), 1.5, 0.001,
		"Los encarecimientos suben sin tope superior")


func test_clamp_cost_multiplier_helper():
	# El helper estatico aplica la misma regla con cualquier multiplier
	# precalculado (lo usa EmpireController para mantenimiento de tropas).
	assert_almost_eq(ModifierManager.clamp_cost_multiplier(0.5), 0.5, 0.001,
		"Multiplicadores sobre el minimo no se tocan")
	assert_almost_eq(ModifierManager.clamp_cost_multiplier(0.05),
			ModifierManager.MIN_COST_MULTIPLIER, 0.001,
		"Por debajo del minimo, se topa a MIN_COST_MULTIPLIER")
	assert_almost_eq(ModifierManager.clamp_cost_multiplier(1.5), 1.5, 0.001,
		"Encarecimientos no se topan")
	assert_almost_eq(ModifierManager.clamp_cost_multiplier(-1.0),
			ModifierManager.MIN_COST_MULTIPLIER, 0.001,
		"Valores negativos (caso degenerado) tambien se topan a 0.2")


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


# ============================================================
#  TROOPS_PER_RECRUIT y TROOP_MAINTENANCE_PERCENT
# ============================================================

func test_get_troops_per_recruit_bonus_empty():
	assert_eq(manager.get_troops_per_recruit_bonus(), 0,
		"Sin modifiers, el bonus es 0")


func test_get_troops_per_recruit_bonus_single():
	var stats := _make_stats()
	var m := StatModifier.new("cuartel", "Cuartel",
		StatModifier.StatType.TROOPS_PER_RECRUIT, 1.0, -1)
	manager.add_modifier(m, stats)
	assert_eq(manager.get_troops_per_recruit_bonus(), 1,
		"Un Cuartel = +1 al bonus")


func test_get_troops_per_recruit_bonus_stacks():
	# Cuartel + Academia → +1 + +1 = +2
	var stats := _make_stats()
	manager.add_modifier(StatModifier.new("cuartel", "Cuartel",
		StatModifier.StatType.TROOPS_PER_RECRUIT, 1.0, -1), stats)
	manager.add_modifier(StatModifier.new("academia", "Academia",
		StatModifier.StatType.TROOPS_PER_RECRUIT, 1.0, -1), stats)
	assert_eq(manager.get_troops_per_recruit_bonus(), 2,
		"Cuartel + Academia stackean a +2 troops_per_recruit")


func test_get_troops_per_recruit_bonus_ignores_other_types():
	# Un FLAT_GOLD no debe contar para troops_per_recruit.
	var stats := _make_stats()
	manager.add_modifier(StatModifier.new("g", "G",
		StatModifier.StatType.FLAT_GOLD, 5.0, -1), stats)
	assert_eq(manager.get_troops_per_recruit_bonus(), 0)


func test_get_troop_maintenance_percent_empty():
	assert_almost_eq(manager.get_troop_maintenance_percent(), 0.0, 0.001)


func test_get_troop_maintenance_percent_single():
	var stats := _make_stats()
	manager.add_modifier(StatModifier.new("ac", "Academia",
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT, -20.0, -1), stats)
	assert_almost_eq(manager.get_troop_maintenance_percent(), -20.0, 0.001)


func test_get_troop_maintenance_percent_stacks():
	# Dos Academias acumulan -20 + -20 = -40 (antes del clamp del consumer).
	var stats := _make_stats()
	manager.add_modifier(StatModifier.new("ac1", "Acad1",
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT, -20.0, -1), stats)
	manager.add_modifier(StatModifier.new("ac2", "Acad2",
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT, -20.0, -1), stats)
	assert_almost_eq(manager.get_troop_maintenance_percent(), -40.0, 0.001)
	# El clamp [-80, 0] lo hace EmpireController, no el manager — el manager
	# devuelve la suma cruda. Verificamos eso para que cualquier consumidor
	# que necesite la suma cruda (UI de modifiers, debug) la reciba sin
	# truncar.


# ============================================================
#  StatModifier.troop_type_filter y applies_to_troop
# ============================================================

func _make_troop(p_type: int = Troop.TroopType.INFANTERIA_LIGERA) -> Troop:
	var t := Troop.new()
	t.name = "T"
	t.type = p_type
	t.attack = 1
	t.defense = 1
	t.recruitment_cost_gold = 10
	t.maintenance_gold = 2
	t.maintenance_food = 1
	return t


func test_stat_modifier_troop_type_filter_defaults_to_minus_one():
	var mod := StatModifier.new("m", "M",
		StatModifier.StatType.TROOPS_PER_RECRUIT, 1.0, -1)
	assert_eq(mod.troop_type_filter, -1,
		"Sin pasar filtro, troop_type_filter debe ser -1 (todas las tropas)")


func test_stat_modifier_troop_type_filter_set_to_cavalry():
	var mod := StatModifier.new("m", "M",
		StatModifier.StatType.TROOPS_PER_RECRUIT, 1.0, -1,
		null, null, Troop.TroopType.CABALLERIA)
	assert_eq(mod.troop_type_filter, Troop.TroopType.CABALLERIA)


func test_stat_modifier_duplicate_preserves_filter():
	var mod := StatModifier.new("m", "M",
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT, -25.0, -1,
		null, null, Troop.TroopType.CABALLERIA)
	var dup := mod.duplicate_modifier() as StatModifier
	assert_not_null(dup)
	assert_eq(dup.troop_type_filter, Troop.TroopType.CABALLERIA,
		"duplicate_modifier debe preservar troop_type_filter")


func test_applies_to_troop_no_filter_accepts_any_troop():
	var mod := StatModifier.new("m", "M",
		StatModifier.StatType.TROOPS_PER_RECRUIT, 1.0, -1)
	assert_true(mod.applies_to_troop(_make_troop(Troop.TroopType.INFANTERIA_LIGERA)))
	assert_true(mod.applies_to_troop(_make_troop(Troop.TroopType.CABALLERIA)))
	assert_true(mod.applies_to_troop(_make_troop(Troop.TroopType.PIQUEROS)))


func test_applies_to_troop_no_filter_accepts_null():
	var mod := StatModifier.new("m", "M",
		StatModifier.StatType.TROOPS_PER_RECRUIT, 1.0, -1)
	assert_true(mod.applies_to_troop(null),
		"Sin filtro, null se acepta (comportamiento de consulta sin tropa concreta)")


func test_applies_to_troop_cavalry_filter_accepts_cavalry():
	var mod := StatModifier.new("m", "M",
		StatModifier.StatType.TROOPS_PER_RECRUIT, 1.0, -1,
		null, null, Troop.TroopType.CABALLERIA)
	var cav := _make_troop(Troop.TroopType.CABALLERIA)
	assert_true(mod.applies_to_troop(cav))


func test_applies_to_troop_cavalry_filter_rejects_infantry():
	var mod := StatModifier.new("m", "M",
		StatModifier.StatType.TROOPS_PER_RECRUIT, 1.0, -1,
		null, null, Troop.TroopType.CABALLERIA)
	var inf := _make_troop(Troop.TroopType.INFANTERIA_LIGERA)
	assert_false(mod.applies_to_troop(inf),
		"Filtro de caballería no debe aplicar a infantería")


func test_applies_to_troop_cavalry_filter_rejects_null():
	var mod := StatModifier.new("m", "M",
		StatModifier.StatType.TROOPS_PER_RECRUIT, 1.0, -1,
		null, null, Troop.TroopType.CABALLERIA)
	assert_false(mod.applies_to_troop(null),
		"Filtro de caballería no debe aplicar cuando no hay tropa concreta")


func test_stat_modifier_description_troops_per_recruit_unfiltered():
	var mod := StatModifier.new("m", "M",
		StatModifier.StatType.TROOPS_PER_RECRUIT, 1.0, -1)
	assert_true(mod.description.contains("troop"),
		"Descripción sin filtro debe mencionar 'troop'")


func test_stat_modifier_description_troops_per_recruit_filtered():
	var mod := StatModifier.new("m", "M",
		StatModifier.StatType.TROOPS_PER_RECRUIT, 1.0, -1,
		null, null, Troop.TroopType.CABALLERIA)
	assert_true(mod.description.to_lower().contains("caball"),
		"Descripción filtrada debe mencionar el tipo de tropa (caballería)")


func test_stat_modifier_description_maintenance_filtered():
	var mod := StatModifier.new("m", "M",
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT, -25.0, -1,
		null, null, Troop.TroopType.CABALLERIA)
	assert_true(mod.description.to_lower().contains("caball"),
		"Descripción filtrada de mantenimiento debe mencionar el tipo")
	assert_true(mod.description.contains("-25%"),
		"Descripción debe incluir el porcentaje")


# ============================================================
#  ModifierManager.get_troops_per_recruit_bonus con filtros
# ============================================================

func test_get_troops_per_recruit_bonus_unfiltered_no_troop_counts():
	# Modifier sin filtro debe contar aunque no se pase tropa.
	var stats := _make_stats()
	manager.add_modifier(StatModifier.new("cuartel", "Cuartel",
		StatModifier.StatType.TROOPS_PER_RECRUIT, 1.0, -1), stats)
	assert_eq(manager.get_troops_per_recruit_bonus(), 1)


func test_get_troops_per_recruit_bonus_filtered_with_matching_troop():
	# Modifier filtrado a CABALLERIA solo cuenta cuando se pasa un jinete.
	var stats := _make_stats()
	manager.add_modifier(StatModifier.new("horde", "Horda",
		StatModifier.StatType.TROOPS_PER_RECRUIT, 1.0, -1,
		null, null, Troop.TroopType.CABALLERIA), stats)
	var cav := _make_troop(Troop.TroopType.CABALLERIA)
	assert_eq(manager.get_troops_per_recruit_bonus(cav), 1,
		"Filtro de caballería debe aplicar al pasar un jinete")


func test_get_troops_per_recruit_bonus_filtered_with_non_matching_troop():
	var stats := _make_stats()
	manager.add_modifier(StatModifier.new("horde", "Horda",
		StatModifier.StatType.TROOPS_PER_RECRUIT, 1.0, -1,
		null, null, Troop.TroopType.CABALLERIA), stats)
	var inf := _make_troop(Troop.TroopType.INFANTERIA_LIGERA)
	assert_eq(manager.get_troops_per_recruit_bonus(inf), 0,
		"Filtro de caballería NO debe aplicar a infantería")


func test_get_troops_per_recruit_bonus_filtered_with_no_troop():
	var stats := _make_stats()
	manager.add_modifier(StatModifier.new("horde", "Horda",
		StatModifier.StatType.TROOPS_PER_RECRUIT, 1.0, -1,
		null, null, Troop.TroopType.CABALLERIA), stats)
	assert_eq(manager.get_troops_per_recruit_bonus(), 0,
		"Modifier filtrado no debe contar si no se especifica tropa")


func test_get_troops_per_recruit_bonus_mixed_modifiers_cavalry():
	# Cuartel (sin filtro) + Horda (filtro caballería): jinete recibe ambos.
	var stats := _make_stats()
	manager.add_modifier(StatModifier.new("cuartel", "Cuartel",
		StatModifier.StatType.TROOPS_PER_RECRUIT, 1.0, -1), stats)
	manager.add_modifier(StatModifier.new("horde", "Horda",
		StatModifier.StatType.TROOPS_PER_RECRUIT, 1.0, -1,
		null, null, Troop.TroopType.CABALLERIA), stats)
	var cav := _make_troop(Troop.TroopType.CABALLERIA)
	assert_eq(manager.get_troops_per_recruit_bonus(cav), 2,
		"Jinete debe recibir Cuartel (+1) + Horda (+1) = +2")


func test_get_troops_per_recruit_bonus_mixed_modifiers_infantry():
	# Cuartel (sin filtro) + Horda (filtro caballería): infantería solo recibe Cuartel.
	var stats := _make_stats()
	manager.add_modifier(StatModifier.new("cuartel", "Cuartel",
		StatModifier.StatType.TROOPS_PER_RECRUIT, 1.0, -1), stats)
	manager.add_modifier(StatModifier.new("horde", "Horda",
		StatModifier.StatType.TROOPS_PER_RECRUIT, 1.0, -1,
		null, null, Troop.TroopType.CABALLERIA), stats)
	var inf := _make_troop(Troop.TroopType.INFANTERIA_LIGERA)
	assert_eq(manager.get_troops_per_recruit_bonus(inf), 1,
		"Infantería solo recibe Cuartel (+1), Horda filtrada no aplica")


# ============================================================
#  ModifierManager.get_troop_maintenance_percent con filtros
# ============================================================

func test_get_troop_maintenance_percent_filtered_with_matching_troop():
	var stats := _make_stats()
	manager.add_modifier(StatModifier.new("horde", "Horda",
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT, -25.0, -1,
		null, null, Troop.TroopType.CABALLERIA), stats)
	var cav := _make_troop(Troop.TroopType.CABALLERIA)
	assert_almost_eq(manager.get_troop_maintenance_percent(cav), -25.0, 0.001,
		"Filtro de caballería debe aplicar al mantenimiento de un jinete")


func test_get_troop_maintenance_percent_filtered_with_non_matching_troop():
	var stats := _make_stats()
	manager.add_modifier(StatModifier.new("horde", "Horda",
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT, -25.0, -1,
		null, null, Troop.TroopType.CABALLERIA), stats)
	var inf := _make_troop(Troop.TroopType.INFANTERIA_LIGERA)
	assert_almost_eq(manager.get_troop_maintenance_percent(inf), 0.0, 0.001,
		"Filtro de caballería NO debe aplicar al mantenimiento de infantería")


func test_get_troop_maintenance_percent_filtered_with_no_troop():
	var stats := _make_stats()
	manager.add_modifier(StatModifier.new("horde", "Horda",
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT, -25.0, -1,
		null, null, Troop.TroopType.CABALLERIA), stats)
	assert_almost_eq(manager.get_troop_maintenance_percent(), 0.0, 0.001,
		"Modifier filtrado no debe contar si no se especifica tropa")


func test_get_troop_maintenance_percent_mixed_cavalry_gets_both():
	# Academia (sin filtro, -20%) + Horda (caballería, -25%): jinete suma -45%.
	var stats := _make_stats()
	manager.add_modifier(StatModifier.new("ac", "Academia",
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT, -20.0, -1), stats)
	manager.add_modifier(StatModifier.new("horde", "Horda",
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT, -25.0, -1,
		null, null, Troop.TroopType.CABALLERIA), stats)
	var cav := _make_troop(Troop.TroopType.CABALLERIA)
	assert_almost_eq(manager.get_troop_maintenance_percent(cav), -45.0, 0.001,
		"Jinete recibe Academia (-20%) + Horda (-25%) = -45%")


func test_get_troop_maintenance_percent_mixed_infantry_gets_only_general():
	# Academia (sin filtro) aplica a infantería; Horda (filtro cav) no.
	var stats := _make_stats()
	manager.add_modifier(StatModifier.new("ac", "Academia",
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT, -20.0, -1), stats)
	manager.add_modifier(StatModifier.new("horde", "Horda",
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT, -25.0, -1,
		null, null, Troop.TroopType.CABALLERIA), stats)
	var inf := _make_troop(Troop.TroopType.INFANTERIA_LIGERA)
	assert_almost_eq(manager.get_troop_maintenance_percent(inf), -20.0, 0.001,
		"Infantería solo recibe Academia (-20%), Horda filtrada no aplica")
