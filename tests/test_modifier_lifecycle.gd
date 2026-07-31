extends GutTest

## Ciclo de vida de [ModifierManager]: alta, `tick()`, caducidad y acumulación.
##
## HUECO REAL (refactor §4.7): `test_modifier.gd` cubre bien el ALTA y las
## CONSULTAS, pero medido sobre toda la suite, `modifier_manager.tick()` no lo
## llamaba NINGÚN test — los únicos `.tick()` eran de BattleFront. O sea que el
## descuento de duración y la caducidad, que corren una vez por turno en toda
## partida, no estaban cubiertos.


var mm: ModifierManager
var stats: Stats


func before_each() -> void:
	mm = ModifierManager.new()
	add_child_autofree(mm)
	stats = TestBuilders.stats().build()


func _gold_percent(id: String, value: float, duration: int) -> StatModifier:
	return StatModifier.new(id, id, StatModifier.StatType.PERCENT_GOLD, value, duration)


# ---------------------------------------------------------------------------
# Duración y caducidad
# ---------------------------------------------------------------------------

func test_tick_descuenta_un_turno() -> void:
	var mod := _gold_percent("temporal", 10.0, 3)
	mm.add_modifier(mod, stats)

	mm.tick()

	assert_eq(mod.duration, 2, "cada tick descuenta exactamente un turno")
	assert_eq(mm.active_modifiers.size(), 1, "aun no caduca")


func test_el_modificador_caduca_al_agotar_su_duracion() -> void:
	var mod := _gold_percent("dos_turnos", 10.0, 2)
	mm.add_modifier(mod, stats)

	mm.tick()
	assert_eq(mm.active_modifiers.size(), 1, "tras 1 tick sigue vivo")
	mm.tick()
	assert_eq(mm.active_modifiers.size(), 0, "al llegar a 0 se retira")


func test_un_modificador_de_un_turno_dura_ese_turno() -> void:
	# Frontera: duración 1 debe sobrevivir al turno en que se aplica y caer en el
	# siguiente tick, no desaparecer antes de surtir efecto.
	var mod := _gold_percent("fugaz", 25.0, 1)
	mm.add_modifier(mod, stats)
	assert_almost_eq(mm.get_percent_gold(), 25.0, 0.001, "activo nada mas darlo de alta")

	mm.tick()

	assert_eq(mm.active_modifiers.size(), 0)
	assert_almost_eq(mm.get_percent_gold(), 0.0, 0.001, "ya no aporta")


func test_los_permanentes_no_caducan() -> void:
	# duration == -1 es permanente: el Tratado Comercial, las habilidades de imperio.
	var mod := _gold_percent("permanente", 10.0, -1)
	mm.add_modifier(mod, stats)

	for _i in range(50):
		mm.tick()

	assert_eq(mm.active_modifiers.size(), 1, "un permanente sobrevive a 50 turnos")
	assert_eq(mod.duration, -1, "y su duracion no se toca")


func test_caducan_solo_los_que_toca() -> void:
	mm.add_modifier(_gold_percent("corto", 10.0, 1), stats)
	mm.add_modifier(_gold_percent("largo", 20.0, 5), stats)
	mm.add_modifier(_gold_percent("eterno", 30.0, -1), stats)

	mm.tick()

	assert_eq(mm.active_modifiers.size(), 2, "solo cae el de duracion 1")
	assert_almost_eq(mm.get_percent_gold(), 50.0, 0.001, "quedan largo(20) + eterno(30)")


func test_tick_sin_modificadores_no_rompe() -> void:
	mm.tick()
	assert_eq(mm.active_modifiers.size(), 0)


# ---------------------------------------------------------------------------
# Acumulación
# ---------------------------------------------------------------------------

func test_los_porcentajes_del_mismo_tipo_se_suman() -> void:
	mm.add_modifier(_gold_percent("a", 10.0, -1), stats)
	mm.add_modifier(_gold_percent("b", 15.0, -1), stats)
	assert_almost_eq(mm.get_percent_gold(), 25.0, 0.001)


func test_un_porcentaje_negativo_resta_del_total() -> void:
	mm.add_modifier(_gold_percent("bonus", 20.0, -1), stats)
	mm.add_modifier(_gold_percent("penalizacion", -30.0, -1), stats)
	assert_almost_eq(mm.get_percent_gold(), -10.0, 0.001)


func test_el_descuento_de_construccion_se_acumula_y_topa() -> void:
	# Regla de juego: por mucho que se apilen descuentos nunca se paga menos del
	# MIN_COST_MULTIPLIER. Es lo que evita edificios gratis.
	for i in range(4):
		mm.add_modifier(BuildCostModifier.new("d%d" % i, "D", 30.0, -1), stats)

	var mult := mm.get_build_cost_multiplier()
	assert_almost_eq(mult, ModifierManager.MIN_COST_MULTIPLIER, 0.001,
		"4 descuentos del 30%% (120%%) deben quedarse en el suelo, no en negativo")


func test_retirar_un_modificador_deja_de_aportar() -> void:
	var mod := _gold_percent("quitable", 40.0, -1)
	mm.add_modifier(mod, stats)
	assert_almost_eq(mm.get_percent_gold(), 40.0, 0.001)

	mm.remove_modifier(mod)

	assert_eq(mm.active_modifiers.size(), 0)
	assert_almost_eq(mm.get_percent_gold(), 0.0, 0.001)


# ---------------------------------------------------------------------------
# Enlace con las stats
# ---------------------------------------------------------------------------

func test_alta_y_baja_enlazan_y_desenlazan_las_stats() -> void:
	# activate/deactivate son el punto por el que un modifier puede leer las stats
	# de su dueño; si la baja no desenlaza, queda una referencia viva.
	var mod := _gold_percent("enlazado", 10.0, -1)
	mm.add_modifier(mod, stats)
	assert_eq(mod.stats, stats, "el alta enlaza las stats del dueno")

	mm.remove_modifier(mod)
	assert_null(mod.stats, "la baja las desenlaza")


func test_la_caducidad_tambien_desenlaza() -> void:
	# La caducidad pasa por remove_modifier, así que debe limpiar igual que una
	# baja manual: si no, un modifier caducado seguiría apuntando a las stats.
	var mod := _gold_percent("caduco", 10.0, 1)
	mm.add_modifier(mod, stats)

	mm.tick()

	assert_null(mod.stats, "un modifier caducado no debe retener las stats")


func test_avisa_de_los_cambios() -> void:
	watch_signals(mm)
	var mod := _gold_percent("observado", 10.0, 1)

	mm.add_modifier(mod, stats)
	assert_signal_emitted(mm, "modifier_added")
	assert_signal_emitted(mm, "modifiers_changed")

	mm.tick()
	assert_signal_emitted(mm, "modifier_removed", "la caducidad debe notificar la baja")
