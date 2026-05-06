extends GutTest

## Tests para el sistema de tropas: reclutamiento, pool, mantenimiento.

var stats: Stats


func _create_troop(atk: int, def: int, gold_cost: int = 20,
		maint_gold: int = 2, maint_food: int = 1,
		troop_type: int = Troop.TroopType.INFANTERIA_LIGERA) -> Troop:
	var troop := Troop.new()
	troop.name = "Test Troop"
	troop.type = troop_type
	troop.attack = atk
	troop.defense = def
	troop.recruitment_cost_gold = gold_cost
	troop.maintenance_gold = maint_gold
	troop.maintenance_food = maint_food
	return troop


func before_each() -> void:
	stats = Stats.new()
	stats.total_gold = 100
	stats.food = 50
	stats.troop_pool = []


# --- Tests de reclutamiento ---

func test_recruit_troop_success() -> void:
	var troop := _create_troop(3, 3, 20)
	var success := stats.recruit_troop(troop)
	assert_true(success, "Debe poder reclutar con recursos suficientes")
	assert_eq(stats.troop_pool.size(), 1)
	assert_eq(stats.total_gold, 80, "Debe restar coste de oro")


func test_recruit_troop_insufficient_gold() -> void:
	stats.total_gold = 5
	var troop := _create_troop(3, 3, 20)
	var success := stats.recruit_troop(troop)
	assert_false(success, "No debe poder reclutar sin oro suficiente")
	assert_eq(stats.troop_pool.size(), 0)
	assert_eq(stats.total_gold, 5, "No debe restar nada si falla")


func test_recruit_emits_signal() -> void:
	var troop := _create_troop(3, 3)
	watch_signals(stats)
	stats.recruit_troop(troop)
	assert_signal_emitted(stats, "troop_recruited")


func test_recruit_emits_troop_pool_changed_with_size() -> void:
	var troop := _create_troop(3, 3)
	watch_signals(stats)
	stats.recruit_troop(troop)
	assert_signal_emitted(stats, "troop_pool_changed")
	# El payload debe ser el tamaño nuevo del pool.
	assert_signal_emitted_with_parameters(stats, "troop_pool_changed", [1])


func test_recruit_failure_does_not_emit_pool_changed() -> void:
	stats.total_gold = 0
	var troop := _create_troop(3, 3, 20)
	watch_signals(stats)
	var success := stats.recruit_troop(troop)
	assert_false(success)
	assert_signal_not_emitted(stats, "troop_pool_changed",
		"Si no se reclutaa, no debe emitir troop_pool_changed")


func test_pool_changed_payload_grows_with_each_recruit() -> void:
	var t1 := _create_troop(3, 3)
	var t2 := _create_troop(4, 2)
	var t3 := _create_troop(2, 5)
	watch_signals(stats)
	stats.recruit_troop(t1)
	stats.recruit_troop(t2)
	stats.recruit_troop(t3)
	# La señal se emite con el tamaño en cada llamada
	assert_signal_emit_count(stats, "troop_pool_changed", 3)


func test_recruit_multiple_troops() -> void:
	var t1 := _create_troop(3, 3, 20)
	var t2 := _create_troop(6, 1, 20)
	stats.recruit_troop(t1)
	stats.recruit_troop(t2)
	assert_eq(stats.troop_pool.size(), 2)
	assert_eq(stats.total_gold, 60)


# --- Tests de can_afford_troop ---

func test_can_afford_troop_true() -> void:
	var troop := _create_troop(3, 3, 20)
	assert_true(stats.can_afford_troop(troop))


func test_can_afford_troop_exact() -> void:
	stats.total_gold = 20
	var troop := _create_troop(3, 3, 20)
	assert_true(stats.can_afford_troop(troop), "Debe poder pagar con recursos justos")


func test_can_afford_troop_false() -> void:
	stats.total_gold = 0
	var troop := _create_troop(3, 3, 20)
	assert_false(stats.can_afford_troop(troop))


# --- Tests de remove_troop ---

func test_remove_troop() -> void:
	var troop := _create_troop(3, 3, 20)
	stats.recruit_troop(troop)
	assert_eq(stats.troop_pool.size(), 1)

	watch_signals(stats)
	stats.remove_troop(troop)
	assert_eq(stats.troop_pool.size(), 0)
	assert_signal_emitted(stats, "troop_lost")
	# Tras eliminar la única tropa, el payload debe ser 0.
	assert_signal_emitted_with_parameters(stats, "troop_pool_changed", [0])


func test_remove_troop_not_in_pool() -> void:
	var troop := _create_troop(3, 3)
	watch_signals(stats)
	stats.remove_troop(troop)
	assert_eq(stats.troop_pool.size(), 0, "No debe fallar al eliminar tropa inexistente")
	assert_signal_not_emitted(stats, "troop_pool_changed",
		"Eliminar una tropa que no está en el pool no debe disparar la señal")


# --- Tests de mantenimiento ---

func test_maintenance_calculation() -> void:
	var t1 := _create_troop(3, 3, 20, 2, 1)
	var t2 := _create_troop(6, 1, 20, 3, 2)
	stats.recruit_troop(t1)
	stats.recruit_troop(t2)

	assert_eq(stats.get_troop_maintenance_gold(), 5, "2 + 3 = 5 oro de mantenimiento")
	assert_eq(stats.get_troop_maintenance_food(), 3, "1 + 2 = 3 comida de mantenimiento")


func test_maintenance_empty_pool() -> void:
	assert_eq(stats.get_troop_maintenance_gold(), 0)
	assert_eq(stats.get_troop_maintenance_food(), 0)


func test_maintenance_after_removal() -> void:
	var t1 := _create_troop(3, 3, 20, 2, 1)
	var t2 := _create_troop(6, 1, 20, 3, 2)
	stats.recruit_troop(t1)
	stats.recruit_troop(t2)
	stats.remove_troop(t1)

	assert_eq(stats.get_troop_maintenance_gold(), 3, "Solo queda t2: 3 oro")
	assert_eq(stats.get_troop_maintenance_food(), 2, "Solo queda t2: 2 comida")


# --- Tests del tipo de tropa ---

func test_troop_type_defaults_to_infanteria_ligera() -> void:
	var t := Troop.new()
	assert_eq(t.type, Troop.TroopType.INFANTERIA_LIGERA,
		"Las tropas creadas sin tipo explícito deben caer en INFANTERIA_LIGERA")


func test_troop_type_label_matches_enum() -> void:
	# Sanity check: cada valor del enum tiene una etiqueta legible.
	for v in Troop.TroopType.values():
		var label := Troop.type_label_for(v)
		assert_ne(label, "?",
			"Todos los TroopType deben tener etiqueta legible (tipo %d)" % v)


func test_troop_get_type_label_uses_instance_type() -> void:
	var t := Troop.new()
	t.type = Troop.TroopType.A_DISTANCIA
	assert_eq(t.get_type_label(), "A Distancia")
