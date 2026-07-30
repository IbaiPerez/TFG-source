extends GutTest

## Cubre las dos reglas de asequibilidad que la §3.4 del refactor unificó:
## [method Building.is_affordable] (coste efectivo ≤ oro) y
## [method Troop.is_affordable] (oro one-shot + gating de mantenimiento).
##
## La regla de tropa estaba escrita DOS veces —`Stats.can_afford_troop` para el
## mundo vivo y un espejo estático en `AILegality` para el snapshot del MCTS—, así
## que aquí se fija además que ambas entradas coinciden: si alguien vuelve a
## bifurcar la regla, el test de equivalencia lo caza.


func _troop(cost: int, maint_gold: int, maint_food: int) -> Troop:
	return TestBuilders.troop() \
		.with_recruit_cost(cost) \
		.with_maintenance(maint_gold, maint_food) \
		.build()


# ---------------------------------------------------------------------------
# Building.is_affordable
# ---------------------------------------------------------------------------

func test_edificio_asequible_con_oro_de_sobra() -> void:
	var b := TestBuilders.building().with_cost(50).build()
	var s := TestBuilders.stats().with_gold(100).build()
	assert_true(b.is_affordable(s))


func test_edificio_asequible_con_el_oro_justo() -> void:
	# El borde es <=, no <: pagar hasta el último de oro debe permitirse.
	var b := TestBuilders.building().with_cost(50).build()
	var s := TestBuilders.stats().with_gold(50).build()
	assert_true(b.is_affordable(s), "coste == oro debe ser asequible")


func test_edificio_no_asequible_por_un_oro() -> void:
	var b := TestBuilders.building().with_cost(50).build()
	var s := TestBuilders.stats().with_gold(49).build()
	assert_false(b.is_affordable(s))


func test_edificio_sin_stats_no_es_asequible() -> void:
	# Sin imperio no hay oro contra el que comparar. Devolver false evita que un
	# slot huérfano (preview, test) se muestre como comprable.
	var b := TestBuilders.building().with_cost(50).build()
	assert_false(b.is_affordable(null))


func test_edificio_usa_el_coste_efectivo_no_el_crudo() -> void:
	# Es el motivo de que la regla exista: con descuento activo (Banca Florentina,
	# eventos) un edificio caro pasa a ser pagable, y la UI debe verlo igual.
	var b := TestBuilders.building().with_cost(100).build()
	var s := TestBuilders.stats().with_gold(60).build()
	assert_false(b.is_affordable(s), "sin descuento, 100 > 60")

	var mm := ModifierManager.new()
	add_child_autofree(mm)
	s.modifier_manager = mm
	mm.add_modifier(BuildCostModifier.new("banking", "Banca", 50.0, -1), s)

	assert_eq(b.get_effective_construction_cost(s), 50, "el descuento del 50% debe aplicarse")
	assert_true(b.is_affordable(s), "con el coste efectivo (50) sí entra en 60")


func test_can_be_upgraded_usa_la_misma_regla() -> void:
	var upgrade := TestBuilders.building().with_cost(80).build()
	var base := TestBuilders.building().with_cost(10).with_upgrades_to([upgrade]).build()

	assert_false(base.can_be_upgraded(TestBuilders.stats().with_gold(79).build()))
	assert_true(base.can_be_upgraded(TestBuilders.stats().with_gold(80).build()))


# ---------------------------------------------------------------------------
# Troop.is_affordable
# ---------------------------------------------------------------------------

func test_tropa_asequible_con_recursos_amplios() -> void:
	assert_true(_troop(20, 2, 1).is_affordable(100, 10, 5))


func test_tropa_asequible_en_los_tres_bordes_a_la_vez() -> void:
	# gold == cost, gpt - maint == 0, food - maint == 0: quedarse a cero es válido.
	assert_true(_troop(20, 2, 1).is_affordable(20, 2, 1))


func test_tropa_bloqueada_por_oro() -> void:
	assert_false(_troop(20, 2, 1).is_affordable(19, 10, 10))


func test_tropa_bloqueada_porque_el_mantenimiento_hunde_la_produccion_de_oro() -> void:
	assert_false(_troop(20, 5, 1).is_affordable(100, 4, 10),
		"gpt 4 - mantenimiento 5 < 0: no se puede sostener")


func test_tropa_bloqueada_porque_el_mantenimiento_hunde_la_comida() -> void:
	assert_false(_troop(20, 1, 5).is_affordable(100, 10, 4),
		"food 4 - mantenimiento 5 < 0: no se puede sostener")


func test_tropa_bloqueada_si_ya_se_esta_en_deficit() -> void:
	# Con mantenimiento 0 el gating sigue mordiendo: el déficit previo ya es < 0.
	assert_false(_troop(20, 0, 0).is_affordable(100, -1, 10))
	assert_false(_troop(20, 0, 0).is_affordable(100, 10, -1))


# ---------------------------------------------------------------------------
# Los dos mundos deciden igual
# ---------------------------------------------------------------------------

func test_stats_can_afford_troop_coincide_con_la_regla_compartida() -> void:
	var troop := _troop(20, 3, 2)
	# Casos alrededor de cada uno de los tres cortes.
	for caso in [[100, 10, 10], [20, 3, 2], [19, 10, 10], [100, 2, 10], [100, 10, 1]]:
		var s := TestBuilders.stats() \
			.with_gold(caso[0]).with_gpt(caso[1]).with_food(caso[2]).build()
		assert_eq(s.can_afford_troop(troop), troop.is_affordable(caso[0], caso[1], caso[2]),
			"divergencia con oro=%d gpt=%d comida=%d" % [caso[0], caso[1], caso[2]])
