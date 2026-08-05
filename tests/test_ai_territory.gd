extends GutTest

## Tests de AITerritory: expansión, encierro y carrera territorial.
##
## Las aserciones van contra el CAMPO DE PESO y las entradas se construyen desde el
## UMBRAL correspondiente, no con números elegidos a mano. La diferencia importa:
## con literales, cambiar `encircle_r1` dejaba el test en verde midiendo otra banda
## —el peor fallo posible en un test, porque sigue pasando y ya no comprueba lo que
## dice su nombre.
##
## `0.0` y `1.0` se dejan literales donde son identidades (sin expansión / sin
## amplificación), no pesos.

const NEUTRO := 1.0


func _w() -> HeuristicWeights:
	return HeuristicWeights.new()


## Cuenta de colonizables que produce el ratio pedido sobre `controladas`.
func _colonizables_para_ratio(ratio: float, controladas: int) -> int:
	return int(round(ratio * controladas))


## Reparto de casillas que produce las cuotas pedidas. El resto va a libres.
func _reparto(my_share: float, rival_share: float) -> Array[int]:
	var total := 1000
	var mias := int(round(my_share * total))
	var rival := int(round(rival_share * total))
	return [mias, rival, total - mias - rival]


# ------------------------------------------------------------------
#  Expansión
# ------------------------------------------------------------------

func test_expansion_factor_desconocido_y_cero() -> void:
	var w := _w()
	# −1 es el centinela de "no hay mapa" (tests, contextos sin mundo).
	assert_almost_eq(AITerritory.expansion_factor(-1, w), w.expansion_unknown, 0.001)
	assert_almost_eq(AITerritory.expansion_factor(0, w), 0.0, 0.001)


func test_expansion_factor_satura_en_la_referencia() -> void:
	var w := _w()
	# ceili, no int: truncar dejaría la entrada JUSTO por debajo de la referencia si
	# el peso no es entero, y el test fallaría por la truncación y no por la regla.
	var referencia := ceili(w.expansion_reference)
	assert_almost_eq(AITerritory.expansion_factor(referencia, w), NEUTRO, 0.001)
	# Y sigue topado por encima: más casillas libres no dan más de 1.0.
	assert_almost_eq(AITerritory.expansion_factor(referencia * 2, w), NEUTRO, 0.001)
	assert_almost_eq(AITerritory.expansion_factor(referencia * 100, w), NEUTRO, 0.001)


func test_expansion_factor_es_creciente_antes_de_saturar() -> void:
	var w := _w()
	var referencia := int(w.expansion_reference)
	var pocas := AITerritory.expansion_factor(maxi(referencia / 5, 1), w)
	var muchas := AITerritory.expansion_factor(maxi(referencia / 2, 2), w)
	assert_gt(pocas, 0.0)
	assert_gt(muchas, pocas, "más casillas libres, más presión expansionista")
	assert_lt(muchas, NEUTRO, "pero por debajo de la referencia no satura")


# ------------------------------------------------------------------
#  Encierro
# ------------------------------------------------------------------

func test_encirclement_pressure_ratio_bands() -> void:
	var w := _w()
	var controladas := 100
	# Cada umbral de ratio devuelve su banda. Los umbrales son inclusivos (>=),
	# así que se prueba JUSTO en el umbral, que es donde se decide.
	var casos := [
		[w.encircle_r2, w.encircle_high],
		[w.encircle_r1, w.encircle_mid],
		[w.encircle_r05, w.encircle_low],
	]
	for caso in casos:
		var ratio: float = caso[0]
		var esperado: float = caso[1]
		assert_almost_eq(AITerritory.encirclement_pressure(
			_colonizables_para_ratio(ratio, controladas), controladas, w),
			esperado, 0.001, "ratio %.2f debe caer en su banda" % ratio)

	# Por debajo del umbral más bajo: rodeado, presión máxima.
	assert_almost_eq(AITerritory.encirclement_pressure(
		_colonizables_para_ratio(w.encircle_r05 / 2.0, controladas), controladas, w),
		w.encircle_min, 0.001)


func test_encirclement_pressure_crece_al_estrecharse_el_cerco() -> void:
	# El ORDEN de las bandas es la regla: menos salida = más urgencia por escapar.
	var w := _w()
	assert_gt(w.encircle_min, w.encircle_low)
	assert_gt(w.encircle_low, w.encircle_mid)
	assert_gt(w.encircle_mid, w.encircle_high)


# ------------------------------------------------------------------
#  Carrera territorial
# ------------------------------------------------------------------

func test_territory_race_colonize_modes() -> void:
	var w := _w()
	# Cerca de la dominación → se amplifica todo lo que acerque al final.
	var cierre := _reparto(w.tr_close_share + 0.05, 0.10)
	assert_almost_eq(AITerritory.territory_race_factor(
		cierre[0], cierre[1], cierre[2], &"colonize", w), w.tr_close_factor, 0.001)

	# Liderando pero sin cerrar → amplificación menor.
	var lidera := _reparto(w.tr_lead_share, 0.10)
	assert_almost_eq(AITerritory.territory_race_factor(
		lidera[0], lidera[1], lidera[2], &"colonize", w), w.tr_lead_factor, 0.001)

	# El RIVAL cerca de su límite → bloquear vale tanto como avanzar.
	var bloqueo := _reparto(0.10, w.tr_block_share)
	assert_almost_eq(AITerritory.territory_race_factor(
		bloqueo[0], bloqueo[1], bloqueo[2], &"colonize", w), w.tr_block_factor, 0.001)

	# Reparto equilibrado con espacio libre de sobra → sin amplificación.
	var neutro := _reparto(0.30, 0.30)
	assert_almost_eq(AITerritory.territory_race_factor(
		neutro[0], neutro[1], neutro[2], &"colonize", w), NEUTRO, 0.001)


func test_territory_race_open_front_shares_colonize_logic() -> void:
	# Abrir frente gana territorio igual que colonizar: misma amplificación.
	var w := _w()
	var cierre := _reparto(w.tr_close_share + 0.05, 0.10)
	assert_eq(
		AITerritory.territory_race_factor(cierre[0], cierre[1], cierre[2], &"open_front", w),
		AITerritory.territory_race_factor(cierre[0], cierre[1], cierre[2], &"colonize", w),
		"open_front y colonize comparten la lógica de carrera")


func test_territory_race_economy_mode() -> void:
	var w := _w()
	# Con ventaja territorial, la economía vale MENOS: es un descuento, no un bonus.
	var cierre := _reparto(w.tr_close_share + 0.05, 0.10)
	assert_almost_eq(AITerritory.territory_race_factor(
		cierre[0], cierre[1], cierre[2], &"economy", w), w.tr_econ_factor, 0.001)
	assert_lt(w.tr_econ_factor, NEUTRO, "en modo economía el factor descuenta")

	# Sin ventaja no descuenta nada.
	var neutro := _reparto(0.30, 0.30)
	assert_almost_eq(AITerritory.territory_race_factor(
		neutro[0], neutro[1], neutro[2], &"economy", w), NEUTRO, 0.001)


func test_territory_race_modo_desconocido_es_neutro() -> void:
	# Guarda: un modo que no existe no debe amplificar nada por accidente.
	var w := _w()
	var cierre := _reparto(w.tr_close_share + 0.05, 0.10)
	assert_almost_eq(AITerritory.territory_race_factor(
		cierre[0], cierre[1], cierre[2], &"modo_inventado", w), NEUTRO, 0.001)
