extends GutTest
## Tests de ModifierSerializer: round-trip por subclase.


func test_stat_modifier_round_trip():
	var mod := StatModifier.new("flat_gold_test", "Test Gold",
			StatModifier.StatType.FLAT_GOLD, 5.0, 3)
	var d := ModifierSerializer.to_dict(mod)
	assert_eq(d["kind"], ModifierSerializer.Kind.STAT)
	assert_eq(d["id"], "flat_gold_test")
	assert_eq(d["name"], "Test Gold")
	assert_eq(int(d["type"]), int(StatModifier.StatType.FLAT_GOLD))
	assert_eq(d["value"], 5.0)
	assert_eq(d["duration"], 3)

	var restored:Modifier = ModifierSerializer.from_dict(d)
	assert_true(restored is StatModifier)
	var sm:StatModifier = restored
	assert_eq(sm.id, "flat_gold_test")
	assert_eq(sm.name, "Test Gold")
	assert_eq(sm.type, StatModifier.StatType.FLAT_GOLD)
	assert_eq(sm.value, 5.0)
	assert_eq(sm.duration, 3)


func test_build_cost_modifier_round_trip():
	var mod := BuildCostModifier.new("bcm_test", "Build Cheap", 20.0, 5)
	var d := ModifierSerializer.to_dict(mod)
	assert_eq(d["kind"], ModifierSerializer.Kind.BUILD_COST)
	assert_eq(d["percent"], 20.0)

	var restored:BuildCostModifier = ModifierSerializer.from_dict(d) as BuildCostModifier
	assert_not_null(restored)
	assert_eq(restored.percent, 20.0)
	assert_eq(restored.duration, 5)


func test_gold_on_card_modifier_round_trip():
	var mod := GoldOnCardModifier.new("gom_test", "Gold On Build", "build_card", 3, -1)
	var d := ModifierSerializer.to_dict(mod)
	assert_eq(d["kind"], ModifierSerializer.Kind.GOLD_ON_CARD)
	assert_eq(d["card_id"], "build_card")
	assert_eq(d["gold_amount"], 3)

	var restored:GoldOnCardModifier = ModifierSerializer.from_dict(d) as GoldOnCardModifier
	assert_not_null(restored)
	assert_eq(restored.card_id, "build_card")
	assert_eq(restored.gold_amount, 3)
	assert_eq(restored.duration, -1)


func test_card_return_modifier_round_trip():
	var mod := CardReturnModifier.new("crm_test", "Return Colonize", "colonize_card", 0.5, 4)
	var d := ModifierSerializer.to_dict(mod)
	assert_eq(d["kind"], ModifierSerializer.Kind.CARD_RETURN)
	assert_eq(d["card_id"], "colonize_card")
	assert_eq(d["chance"], 0.5)

	var restored:CardReturnModifier = ModifierSerializer.from_dict(d) as CardReturnModifier
	assert_not_null(restored)
	assert_eq(restored.card_id, "colonize_card")
	assert_eq(restored.chance, 0.5)
	assert_eq(restored.duration, 4)


func test_unknown_kind_returns_null():
	var d := { "kind": ModifierSerializer.Kind.UNKNOWN, "id": "x", "name": "x", "duration": 1 }
	var restored:Modifier = ModifierSerializer.from_dict(d)
	assert_null(restored)


func test_serialize_manager_returns_array_with_all_modifiers():
	# add_child_autofree libera el Node al terminar el test (ModifierManager
	# es Node y se queda como orphan si lo creamos con `new()` sin más).
	var manager := add_child_autofree(ModifierManager.new()) as ModifierManager
	var stats := Stats.new()

	manager.add_modifier(StatModifier.new("a", "A", StatModifier.StatType.FLAT_GOLD, 1.0, 2), stats)
	manager.add_modifier(BuildCostModifier.new("b", "B", 10.0, 3), stats)

	var data := ModifierSerializer.serialize_manager(manager)
	assert_eq(data.size(), 2)
	assert_eq(data[0]["kind"], ModifierSerializer.Kind.STAT)
	assert_eq(data[1]["kind"], ModifierSerializer.Kind.BUILD_COST)


func test_stat_modifier_round_trip_with_troop_type_filter():
	# Un StatModifier con filtro de caballería debe sobrevivir el ciclo
	# serialización → deserialización conservando troop_type_filter.
	var mod := StatModifier.new("horde_maint", "Horda Mantenimiento",
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT, -25.0, -1,
		null, null, Troop.TroopType.CABALLERIA)
	assert_eq(mod.troop_type_filter, Troop.TroopType.CABALLERIA)

	var d := ModifierSerializer.to_dict(mod)
	assert_true(d.has("troop_type_filter"),
		"El dict serializado debe incluir troop_type_filter")
	assert_eq(int(d["troop_type_filter"]), int(Troop.TroopType.CABALLERIA))

	var restored := ModifierSerializer.from_dict(d) as StatModifier
	assert_not_null(restored)
	assert_eq(restored.type, StatModifier.StatType.TROOP_MAINTENANCE_PERCENT)
	assert_almost_eq(restored.value, -25.0, 0.001)
	assert_eq(restored.troop_type_filter, Troop.TroopType.CABALLERIA,
		"troop_type_filter debe preservarse tras la deserialización")


func test_stat_modifier_round_trip_without_filter_defaults_to_minus_one():
	# Modifier sin filtro (el caso habitual de Cuartel/Academia): el campo
	# debe restaurarse a -1, no a 0 ni a otro valor.
	var mod := StatModifier.new("cuartel", "Cuartel",
		StatModifier.StatType.TROOPS_PER_RECRUIT, 1.0, -1)
	var d := ModifierSerializer.to_dict(mod)
	var restored := ModifierSerializer.from_dict(d) as StatModifier
	assert_not_null(restored)
	assert_eq(restored.troop_type_filter, -1,
		"Modifier sin filtro debe restaurarse con troop_type_filter = -1")


func test_apply_to_manager_restores_modifiers_in_order():
	var source_manager := add_child_autofree(ModifierManager.new()) as ModifierManager
	var stats := Stats.new()

	source_manager.add_modifier(StatModifier.new("a", "A", StatModifier.StatType.FLAT_FOOD, 2.0, -1), stats)
	source_manager.add_modifier(BuildCostModifier.new("b", "B", 15.0, 4), stats)

	var data := ModifierSerializer.serialize_manager(source_manager)

	var dest_manager := add_child_autofree(ModifierManager.new()) as ModifierManager
	var dest_stats := Stats.new()
	ModifierSerializer.apply_to_manager(dest_manager, data, dest_stats)

	assert_eq(dest_manager.active_modifiers.size(), 2)
	assert_true(dest_manager.active_modifiers[0] is StatModifier)
	assert_true(dest_manager.active_modifiers[1] is BuildCostModifier)
	assert_eq((dest_manager.active_modifiers[0] as StatModifier).value, 2.0)
	assert_eq((dest_manager.active_modifiers[1] as BuildCostModifier).percent, 15.0)
