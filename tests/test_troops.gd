extends GutTest

## Tests para el sistema de tropas: reclutamiento, pool, mantenimiento.

# Las etiquetas de tipo de tropa comparan contra texto en español
# ("A Distancia"). Fijamos el locale para que no dependa del idioma
# guardado en user://settings.cfg o del SO.
var _prev_locale: String

var stats: Stats


func before_all() -> void:
	_prev_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("es")


func after_all() -> void:
	TranslationServer.set_locale(_prev_locale)


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


# --- Tests de types_ever_recruited ---

func test_recruit_increments_types_ever_recruited() -> void:
	# Stats.new() arranca con el Dictionary vacio: solo recruit_troop()
	# lo toca, no se inicializa desde @export.
	stats.types_ever_recruited = {}
	var t := _create_troop(3, 3, 20, 2, 1, Troop.TroopType.CABALLERIA)
	stats.recruit_troop(t)
	assert_eq(int(stats.types_ever_recruited.get(Troop.TroopType.CABALLERIA, 0)), 1,
		"Reclutar una caballeria debe incrementar el contador del tipo a 1")


func test_recruit_failure_does_not_increment_types() -> void:
	# Si recruit_troop falla por falta de oro, el contador no se toca.
	stats.types_ever_recruited = {}
	stats.total_gold = 5
	var t := _create_troop(3, 3, 20, 2, 1, Troop.TroopType.PIQUEROS)
	stats.recruit_troop(t)
	assert_eq(stats.types_ever_recruited.size(), 0,
		"Un recruit fallido no debe tocar el contador historico")


func test_recruit_counts_persist_across_remove() -> void:
	# Una tropa reclutada y luego eliminada (muere en frente, etc.) sigue
	# contando para el historico. Este es el bug que motivo la fix: las
	# tacticas se desbloqueaban solo si la tropa seguia viva en el pool.
	stats.types_ever_recruited = {}
	var t := _create_troop(3, 3, 20, 2, 1, Troop.TroopType.A_DISTANCIA)
	stats.recruit_troop(t)
	stats.remove_troop(t)
	assert_eq(stats.troop_pool.size(), 0)
	assert_eq(int(stats.types_ever_recruited.get(Troop.TroopType.A_DISTANCIA, 0)), 1,
		"Eliminar la tropa NO debe decrementar el contador historico")


func test_recruit_counts_accumulate_per_type() -> void:
	stats.types_ever_recruited = {}
	stats.total_gold = 100
	stats.recruit_troop(_create_troop(3, 3, 20, 2, 1, Troop.TroopType.CABALLERIA))
	stats.recruit_troop(_create_troop(3, 3, 20, 2, 1, Troop.TroopType.CABALLERIA))
	stats.recruit_troop(_create_troop(3, 3, 20, 2, 1, Troop.TroopType.PIQUEROS))
	assert_eq(int(stats.types_ever_recruited.get(Troop.TroopType.CABALLERIA, 0)), 2)
	assert_eq(int(stats.types_ever_recruited.get(Troop.TroopType.PIQUEROS, 0)), 1)
	assert_eq(int(stats.types_ever_recruited.get(Troop.TroopType.A_DISTANCIA, 0)), 0,
		"Tipos no reclutados se quedan sin entrada (o devuelven 0)")


func test_pool_append_outside_recruit_does_not_increment() -> void:
	# `BattleFrontManager._return_surviving_troops` hace `troop_pool.append`
	# directamente para devolver supervivientes. Ese append NO debe contar
	# como recruit (la tropa ya estaba contada cuando se reclutó por
	# primera vez). Verificamos el contrato.
	stats.types_ever_recruited = {}
	var t := _create_troop(3, 3, 20, 2, 1, Troop.TroopType.INFANTERIA_PESADA)
	stats.troop_pool.append(t)  # Simula devolución desde frente.
	assert_eq(stats.troop_pool.size(), 1)
	assert_eq(stats.types_ever_recruited.size(), 0,
		"troop_pool.append directo (devolucion de frente) NO incrementa el historico")


# --- Tests de can_afford_troop ---

func test_can_afford_troop_true() -> void:
	# Recursos amplios: oro one-shot + gpt suficiente para mantenimiento +
	# comida suficiente. Debe poder reclutar.
	stats.gold_per_turn = 10
	stats.food = 5
	var troop := _create_troop(3, 3, 20, 2, 1)
	assert_true(stats.can_afford_troop(troop))


func test_can_afford_troop_exact() -> void:
	# Bordes en los tres ejes: gold == cost, gpt - maint == 0, food - maint == 0.
	stats.total_gold = 20
	stats.gold_per_turn = 2
	stats.food = 1
	var troop := _create_troop(3, 3, 20, 2, 1)
	assert_true(stats.can_afford_troop(troop),
		"Justos en oro/gpt/food debe permitirse — el `>= 0` post-recruit es valido")


func test_can_afford_troop_false() -> void:
	# Sin oro suficiente para el coste one-shot.
	stats.total_gold = 0
	stats.gold_per_turn = 10
	stats.food = 10
	var troop := _create_troop(3, 3, 20)
	assert_false(stats.can_afford_troop(troop))


# Opción 3b — gating por mantenimiento

func test_can_afford_troop_false_when_gpt_below_maintenance() -> void:
	# Oro suficiente para el cost one-shot pero gpt insuficiente para
	# mantenimiento: bloqueado.
	stats.total_gold = 100
	stats.gold_per_turn = 1
	stats.food = 10
	var troop := _create_troop(3, 3, 20, 2, 1)  # maint_gold = 2
	assert_false(stats.can_afford_troop(troop),
		"gpt=1 no cubre maint=2 → no se puede reclutar (Opcion 3b)")


func test_can_afford_troop_false_when_gpt_already_negative() -> void:
	# Imperio en colapso (gpt < 0 ya antes del recruit): cualquier nueva
	# tropa empeora la situacion, blocked.
	stats.total_gold = 100
	stats.gold_per_turn = -5
	stats.food = 10
	var troop := _create_troop(3, 3, 20, 2, 1)
	assert_false(stats.can_afford_troop(troop),
		"Imperio en deficit no puede reclutar mas tropas")


func test_can_afford_troop_false_when_food_below_maintenance() -> void:
	# gpt OK pero food al borde, no cubre maint_food.
	stats.total_gold = 100
	stats.gold_per_turn = 100
	stats.food = 1
	var troop := _create_troop(3, 3, 20, 2, 2)  # maint_food = 2
	assert_false(stats.can_afford_troop(troop),
		"food=1 no cubre maint_food=2 → no se puede reclutar")


func test_can_afford_troop_false_when_food_already_negative() -> void:
	stats.total_gold = 100
	stats.gold_per_turn = 100
	stats.food = -3
	var troop := _create_troop(3, 3, 20, 2, 1)
	assert_false(stats.can_afford_troop(troop),
		"food < 0 bloquea reclutamiento adicional")


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
