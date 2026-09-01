extends GutTest

## REGLA de mantenimiento de tropas en un frente.
##
## Antes: la tropa asignada SALÍA del pool y por tanto dejaba de pagar su
## mantenimiento base; a cambio el frente cobraba un recargo PLANO y progresivo
## —(i+1)·5 de oro y de comida, igual para toda tropa—. Eso tenía dos problemas:
##
##   · el coste "base" desaparecía al asignar, que es justo lo contrario de lo que
##     significa ser un coste base (y hacía que asignar tropas AHORRARA oro);
##   · el recargo no dependía de la tropa, así que guarnecer una milicia costaba lo
##     mismo que guarnecer infantería pesada.
##
## Ahora: la tropa sigue pagando SU coste base, multiplicado por un factor que
## depende de cuántas haya en ese frente. Son DOS curvas, una por recurso:
##
##   · ORO (1.5^(n-1)): crece despacio y cruza el lineal en la quinta tropa.
##   · COMIDA (2.5^(n-1)): mucho más empinada, cruza ya en la segunda.
##
## La asimetría es deliberada. Los mantenimientos base de oro son un orden de
## magnitud mayores que los de comida, así que con una curva común era siempre el
## oro el que limitaba; con la comida más empinada, es ella la que ata las
## guarniciones grandes, que es el rol que se le quiere dar.
##
## Las aserciones van contra las constantes de `GameBalance`, no contra 1.5 y 2.5:
## si mañana se retoca la curva, estos tests deben seguir describiendo la REGLA.


const GROWTH_ORO := GameBalance.FRONT_UPKEEP_GROWTH_GOLD
const GROWTH_COMIDA := GameBalance.FRONT_UPKEEP_GROWTH_FOOD


# ---------------------------------------------------------------------------
# La curva
# ---------------------------------------------------------------------------

func test_la_primera_tropa_paga_exactamente_su_coste_base() -> void:
	# El multiplicador arranca en 1.0: el coste base NO desaparece ni se recarga.
	assert_almost_eq(CombatMath.front_gold_upkeep_multiplier(1), 1.0, 0.0001,
		"la primera tropa de un frente paga su base, ni más ni menos")


func test_el_multiplicador_crece_despacio_al_principio() -> void:
	# Por debajo del cruce debe ir POR DEBAJO del crecimiento lineal.
	for n in range(2, 5):
		assert_lt(CombatMath.front_gold_upkeep_multiplier(n), float(n),
			"en n=%d el multiplicador debe ser más suave que el lineal" % n)


func test_el_multiplicador_cruza_el_crecimiento_lineal_en_cinco() -> void:
	# El punto de diseño: hasta 4 sale barato apilar, a partir de 5 sale caro.
	assert_lt(CombatMath.front_gold_upkeep_multiplier(4), 4.0, "en n=4 todavía es más suave")
	assert_gt(CombatMath.front_gold_upkeep_multiplier(5), 5.0, "en n=5 ya es más caro")


func test_el_multiplicador_es_convexo() -> void:
	# "Crece más cuanto más asignes": cada salto debe ser mayor que el anterior.
	var salto_previo := 0.0
	for n in range(2, 9):
		var salto := CombatMath.front_gold_upkeep_multiplier(n) \
			- CombatMath.front_gold_upkeep_multiplier(n - 1)
		assert_gt(salto, salto_previo, "el salto hacia n=%d debe superar al anterior" % n)
		salto_previo = salto


func test_el_multiplicador_espeja_la_constante_de_regla() -> void:
	assert_almost_eq(CombatMath.front_gold_upkeep_multiplier(2), GROWTH_ORO, 0.0001)
	assert_almost_eq(CombatMath.front_food_upkeep_multiplier(2), GROWTH_COMIDA, 0.0001)


# ---------------------------------------------------------------------------
# Aplicada al frente
# ---------------------------------------------------------------------------

var _front: BattleFront


func before_each() -> void:
	BattleFront.clear_active_instances()
	var atk := TestBuilders.tile().build()
	var def := TestBuilders.tile().build()
	add_child_autofree(atk)
	add_child_autofree(def)
	_front = BattleFront.new(atk, def, Empire.new(), Empire.new())


func after_each() -> void:
	BattleFront.clear_active_instances()


func _añadir(n: int, oro: int, comida: int) -> void:
	for i in range(n):
		_front.assign_troop(
			TestBuilders.troop().with_maintenance(oro, comida).build(),
			BattleFront.Side.ATTACKER)


func test_el_coste_del_frente_depende_de_la_tropa_concreta() -> void:
	# Antes el recargo era plano: guarnecer milicia costaba lo mismo que infantería
	# pesada. Ahora escala con el coste base de cada una.
	_añadir(3, 25, 3)                       # infantería pesada
	var cara := _front.get_front_maintenance(BattleFront.Side.ATTACKER)

	BattleFront.clear_active_instances()
	var atk := TestBuilders.tile().build()
	var def := TestBuilders.tile().build()
	add_child_autofree(atk)
	add_child_autofree(def)
	_front = BattleFront.new(atk, def, Empire.new(), Empire.new())
	_añadir(3, 12, 1)                       # milicia
	var barata := _front.get_front_maintenance(BattleFront.Side.ATTACKER)

	assert_gt(cara["gold"], barata["gold"],
		"guarnecer tropas caras debe costar más que guarnecer milicia")


func test_una_sola_tropa_cuesta_su_base() -> void:
	_añadir(1, 12, 3)
	var m := _front.get_front_maintenance(BattleFront.Side.ATTACKER)
	assert_eq(m["gold"], 12, "una tropa sola paga su mantenimiento base en oro")
	assert_eq(m["food"], 3, "y su mantenimiento base en comida")


func test_el_coste_total_crece_mas_que_proporcionalmente() -> void:
	_añadir(1, 12, 1)
	var uno: int = _front.get_front_maintenance(BattleFront.Side.ATTACKER)["gold"]
	_añadir(3, 12, 1)   # hasta 4 en total
	var cuatro: int = _front.get_front_maintenance(BattleFront.Side.ATTACKER)["gold"]
	assert_gt(cuatro, uno * 4,
		"cuatro tropas deben costar MÁS que cuatro veces una: el frente se recarga")


func test_frente_vacio_no_cuesta_nada() -> void:
	var m := _front.get_front_maintenance(BattleFront.Side.ATTACKER)
	assert_eq(m["gold"], 0)
	assert_eq(m["food"], 0)


# ---------------------------------------------------------------------------
# El coste base ya no desaparece
# ---------------------------------------------------------------------------

func test_asignar_una_tropa_nunca_abarata_al_imperio() -> void:
	# EL invariante que motiva el cambio. Antes, sacarla del pool le quitaba el
	# mantenimiento base y el recargo de la primera (5) era menor: asignar SALÍA
	# A CUENTA. Ahora el coste marginal de la primera es exactamente cero.
	var t := TestBuilders.troop().with_maintenance(18, 2).build()
	assert_almost_eq(TroopAssignmentPolicy.marginal_gold_cost(1, t), 0.0, 0.001,
		"la primera tropa de un frente no cuesta ni ahorra nada")
	assert_almost_eq(TroopAssignmentPolicy.marginal_food_cost(1, t), 0.0, 0.001)
	for n in range(2, 8):
		assert_gt(TroopAssignmentPolicy.marginal_gold_cost(n, t), 0.0,
			"a partir de la segunda, apilar siempre cuesta oro (n=%d)" % n)


# ---------------------------------------------------------------------------
# Las dos curvas no son la misma
# ---------------------------------------------------------------------------

func test_la_comida_escala_mas_deprisa_que_el_oro() -> void:
	# La decision de balance que separa las dos curvas: los mantenimientos base de
	# ORO son un orden de magnitud mayores que los de comida, asi que con una sola
	# curva era siempre el oro el que limitaba. Con la comida mas empinada, es ella
	# la que ata las guarniciones grandes.
	assert_gt(GROWTH_COMIDA, GROWTH_ORO, "precondicion: la constante de comida es mayor")
	for n in range(2, 7):
		assert_gt(CombatMath.front_food_upkeep_multiplier(n),
			CombatMath.front_gold_upkeep_multiplier(n),
			"en n=%d la comida debe escalar mas que el oro" % n)


func test_la_comida_cruza_el_lineal_mucho_antes_que_el_oro() -> void:
	# El oro cruza en la quinta; la comida ya en la segunda.
	assert_gt(CombatMath.front_food_upkeep_multiplier(2), 2.0,
		"la comida ya es mas cara que el lineal en la segunda tropa")
	assert_lt(CombatMath.front_gold_upkeep_multiplier(2), 2.0,
		"el oro todavia es mas barato que el lineal en la segunda")


func test_tres_tropas_cuestan_el_doble_de_comida_que_con_la_curva_del_oro() -> void:
	# Punto de calibracion: una tropa de base 1 de comida pasa de ~4.8 a ~9.8.
	var comida := CombatMath.front_food_upkeep_multiplier(1) 		+ CombatMath.front_food_upkeep_multiplier(2) 		+ CombatMath.front_food_upkeep_multiplier(3)
	var oro := CombatMath.front_gold_upkeep_multiplier(1) 		+ CombatMath.front_gold_upkeep_multiplier(2) 		+ CombatMath.front_gold_upkeep_multiplier(3)
	assert_gt(comida, oro * 1.8,
		"tres tropas deben costar en comida bastante mas del doble que con la curva del oro")
