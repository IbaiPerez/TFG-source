extends GutTest

## Tests para ProductionCalculator, enfocados en _calculate_troop_maintenance.
## Verifica que los modifiers con troop_type_filter se apliquen solo al tipo
## correcto y que los modifiers sin filtro afecten a todas las tropas.


# ============================================================
#  Helpers
# ============================================================

func _make_stats() -> Stats:
	var s := Stats.new()
	s.total_gold = 200
	s.gold_per_turn = 0
	s.food = 50
	s.cards_per_turn = 3
	s.empire = Empire.new()
	s.empire.controlled_tiles = []
	s.troop_pool = []
	return s


func _make_troop(p_type: int, p_maint_gold: int, p_maint_food: int) -> Troop:
	var t := Troop.new()
	t.name = "T"
	t.type = p_type
	t.attack = 1
	t.defense = 1
	t.recruitment_cost_gold = 10
	t.maintenance_gold = p_maint_gold
	t.maintenance_food = p_maint_food
	return t


func _make_calc(stats: Stats, mm: ModifierManager) -> ProductionCalculator:
	return ProductionCalculator.new(stats, mm, null)


# ============================================================
#  Sin tropas
# ============================================================

func test_no_troops_zero_maintenance() -> void:
	var stats := _make_stats()
	var mm := add_child_autofree(ModifierManager.new()) as ModifierManager
	var calc := _make_calc(stats, mm)

	var result := calc.calculate_turn()
	assert_eq(result["base_troop_gold"], 0)
	assert_eq(result["base_troop_food"], 0)


# ============================================================
#  Modifier sin filtro: aplica a todas las tropas
# ============================================================

func test_unfiltered_discount_applies_to_infantry() -> void:
	var stats := _make_stats()
	var mm := add_child_autofree(ModifierManager.new()) as ModifierManager
	# -20% mantenimiento a todas las tropas (sin filtro)
	var mod := StatModifier.new("ac", "Academia",
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT, -20.0, -1)
	mm.add_modifier(mod, stats)

	var infantry := _make_troop(Troop.TroopType.INFANTERIA_LIGERA, 4, 2)
	stats.troop_pool.append(infantry)

	var calc := _make_calc(stats, mm)
	var result := calc.calculate_turn()
	# multiplier = clamp(1 - 0.20) = 0.80
	# gold = int(4 * 0.80) = 3, food = int(2 * 0.80) = 1
	assert_eq(result["base_troop_gold"], 3)
	assert_eq(result["base_troop_food"], 1)


func test_unfiltered_discount_applies_to_cavalry() -> void:
	var stats := _make_stats()
	var mm := add_child_autofree(ModifierManager.new()) as ModifierManager
	var mod := StatModifier.new("ac", "Academia",
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT, -20.0, -1)
	mm.add_modifier(mod, stats)

	var cavalry := _make_troop(Troop.TroopType.CABALLERIA, 4, 2)
	stats.troop_pool.append(cavalry)

	var calc := _make_calc(stats, mm)
	var result := calc.calculate_turn()
	assert_eq(result["base_troop_gold"], 3)
	assert_eq(result["base_troop_food"], 1)


# ============================================================
#  Modifier con filtro CABALLERIA: solo afecta a jinetes
# ============================================================

func test_cavalry_filtered_discount_applies_to_cavalry() -> void:
	var stats := _make_stats()
	var mm := add_child_autofree(ModifierManager.new()) as ModifierManager
	var mod := StatModifier.new("horde", "Horda",
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT, -25.0, -1,
		null, null, Troop.TroopType.CABALLERIA)
	mm.add_modifier(mod, stats)

	var cavalry := _make_troop(Troop.TroopType.CABALLERIA, 4, 2)
	stats.troop_pool.append(cavalry)

	var calc := _make_calc(stats, mm)
	var result := calc.calculate_turn()
	# multiplier = clamp(1 - 0.25) = 0.75
	# gold = int(4 * 0.75) = 3, food = int(2 * 0.75) = 1
	assert_eq(result["base_troop_gold"], 3)
	assert_eq(result["base_troop_food"], 1)


func test_cavalry_filtered_discount_does_not_apply_to_infantry() -> void:
	var stats := _make_stats()
	var mm := add_child_autofree(ModifierManager.new()) as ModifierManager
	var mod := StatModifier.new("horde", "Horda",
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT, -25.0, -1,
		null, null, Troop.TroopType.CABALLERIA)
	mm.add_modifier(mod, stats)

	var infantry := _make_troop(Troop.TroopType.INFANTERIA_LIGERA, 4, 2)
	stats.troop_pool.append(infantry)

	var calc := _make_calc(stats, mm)
	var result := calc.calculate_turn()
	# El filtro excluye a la infantería: sin descuento, multiplier = 1.0
	assert_eq(result["base_troop_gold"], 4)
	assert_eq(result["base_troop_food"], 2)


# ============================================================
#  Pool mixto: caballería + infantería, filtro solo en caballería
# ============================================================

func test_mixed_pool_cavalry_filter_affects_only_cavalry() -> void:
	var stats := _make_stats()
	var mm := add_child_autofree(ModifierManager.new()) as ModifierManager
	var mod := StatModifier.new("horde", "Horda",
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT, -25.0, -1,
		null, null, Troop.TroopType.CABALLERIA)
	mm.add_modifier(mod, stats)

	# 2 jinetes (maint 3g, 2f cada uno) + 1 infantería (maint 2g, 1f)
	var cav1 := _make_troop(Troop.TroopType.CABALLERIA, 3, 2)
	var cav2 := _make_troop(Troop.TroopType.CABALLERIA, 3, 2)
	var inf := _make_troop(Troop.TroopType.INFANTERIA_LIGERA, 2, 1)
	stats.troop_pool.append(cav1)
	stats.troop_pool.append(cav2)
	stats.troop_pool.append(inf)

	var calc := _make_calc(stats, mm)
	var result := calc.calculate_turn()
	# cav1: int(3*0.75)=2 gold, int(2*0.75)=1 food
	# cav2: 2 gold, 1 food
	# inf:  int(2*1.0)=2 gold, int(1*1.0)=1 food
	assert_eq(result["base_troop_gold"], 6, "2+2+2 = 6 gold")
	assert_eq(result["base_troop_food"], 3, "1+1+1 = 3 food")


func test_mixed_pool_unfiltered_discount_affects_all() -> void:
	var stats := _make_stats()
	var mm := add_child_autofree(ModifierManager.new()) as ModifierManager
	# Misma tasa pero sin filtro: aplica a todos
	var mod := StatModifier.new("ac", "Academia",
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT, -25.0, -1)
	mm.add_modifier(mod, stats)

	var cav := _make_troop(Troop.TroopType.CABALLERIA, 3, 2)
	var inf := _make_troop(Troop.TroopType.INFANTERIA_LIGERA, 2, 1)
	stats.troop_pool.append(cav)
	stats.troop_pool.append(inf)

	var calc := _make_calc(stats, mm)
	var result := calc.calculate_turn()
	# Ambos con multiplier 0.75
	# cav: int(3*0.75)=2 gold, int(2*0.75)=1 food
	# inf: int(2*0.75)=1 gold, int(1*0.75)=0 food
	assert_eq(result["base_troop_gold"], 3, "2+1 = 3 gold")
	assert_eq(result["base_troop_food"], 1, "1+0 = 1 food")


# ============================================================
#  Clamp: descuento masivo no baja del mínimo
# ============================================================

func test_massive_cavalry_discount_clamped_at_minimum() -> void:
	var stats := _make_stats()
	var mm := add_child_autofree(ModifierManager.new()) as ModifierManager
	# -90% filtrado a caballería: multiplier sin clamp sería 0.10 < MIN (0.20)
	var mod := StatModifier.new("op", "OP",
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT, -90.0, -1,
		null, null, Troop.TroopType.CABALLERIA)
	mm.add_modifier(mod, stats)

	var cavalry := _make_troop(Troop.TroopType.CABALLERIA, 10, 4)
	stats.troop_pool.append(cavalry)

	var calc := _make_calc(stats, mm)
	var result := calc.calculate_turn()
	# multiplier clamped a 0.20: gold=int(10*0.20)=2, food=int(4*0.20)=0
	assert_eq(result["base_troop_gold"], 2)
	assert_eq(result["base_troop_food"], 0)


func test_massive_cavalry_discount_does_not_clamp_infantry() -> void:
	var stats := _make_stats()
	var mm := add_child_autofree(ModifierManager.new()) as ModifierManager
	var mod := StatModifier.new("op", "OP",
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT, -90.0, -1,
		null, null, Troop.TroopType.CABALLERIA)
	mm.add_modifier(mod, stats)

	# Infantería: sin descuento (filtro excluye), paga mantenimiento completo
	var infantry := _make_troop(Troop.TroopType.INFANTERIA_LIGERA, 10, 4)
	stats.troop_pool.append(infantry)

	var calc := _make_calc(stats, mm)
	var result := calc.calculate_turn()
	assert_eq(result["base_troop_gold"], 10)
	assert_eq(result["base_troop_food"], 4)


# ============================================================
#  total_troop_maint incluye mantenimiento + recargo de frentes
# ============================================================

func test_total_troop_maint_with_no_fronts_equals_base() -> void:
	var stats := _make_stats()
	var mm := add_child_autofree(ModifierManager.new()) as ModifierManager

	var t := _make_troop(Troop.TroopType.INFANTERIA_LIGERA, 3, 1)
	stats.troop_pool.append(t)

	var calc := _make_calc(stats, mm)
	var result := calc.calculate_turn()
	# Sin frentes, total_troop_maint = base_gold + base_food + 0 + 0
	assert_eq(result["total_troop_maint"],
		result["base_troop_gold"] + result["base_troop_food"])
