extends GutTest

## Forma de `AIEconomy.resource_surplus_factor`, el factor que multiplica el score
## ENTERO de reclutar y de abrir frente (sus dos únicos consumidores). Un salto
## aquí no matiza una jugada: puede cambiar qué familia gana el argmax.
##
## El defecto que estos tests fijan: el eje del ORO rampaba suavemente desde el
## umbral cómodo hasta el doble, pero el de la COMIDA era un acantilado binario —
## un único punto de comida llevaba el factor de 1.0 a 3.0 de golpe. Colonizar una
## casilla de trigo podía triplicar por sí sola el valor de todo lo militar.
##
## La corrección aplica al eje de comida la MISMA regla que ya usaba el oro y que
## su propio comentario enunciaba: 1.0 en el umbral, pleno al duplicarlo.
##
## Los tests afirman PROPIEDADES de la curva (monotonía, continuidad, los dos
## extremos) derivadas de los campos de peso, no cifras escritas a mano: con
## literales, mover `surplus_min_food` o `surplus_max` los dejaría en verde
## midiendo otra banda.


func _w() -> HeuristicWeights:
	return HeuristicWeights.new()


## Umbral cómodo de oro de la fase, leído del peso que corresponda.
func _comfortable(w: HeuristicWeights, phase: AIGamePhase.Phase) -> float:
	match phase:
		AIGamePhase.Phase.EARLY: return w.surplus_comfortable_early
		AIGamePhase.Phase.MID:   return w.surplus_comfortable_mid
		_:                       return w.surplus_comfortable_late


## Oro suficiente para saturar el eje económico (el doble del umbral cómodo), de
## modo que lo que se mida sea SOLO el eje de la comida.
func _gpt_saturado(w: HeuristicWeights, phase: AIGamePhase.Phase) -> int:
	return int(_comfortable(w, phase) * 2.0)


func _f(food: int, gpt: int, phase := AIGamePhase.Phase.MID) -> float:
	return AIEconomy.resource_surplus_factor(food, gpt, phase, _w())


# ---------------------------------------------------------------------------
# Continuidad: el defecto principal
# ---------------------------------------------------------------------------

func test_el_eje_de_comida_no_tiene_ningun_salto_brusco() -> void:
	# EL test que discrimina. Antes, entre `surplus_min_food − 1` y
	# `surplus_min_food` el factor pasaba de 1.0 a surplus_max de golpe.
	var w := _w()
	var gpt := _gpt_saturado(w, AIGamePhase.Phase.MID)
	var umbral := int(w.surplus_min_food)
	var rango := w.surplus_max - 1.0
	# Ningún paso de UN punto de comida puede mover el factor más de una fracción
	# pequeña del recorrido total.
	var salto_maximo := rango * 0.35
	var previo := _f(0, gpt)
	for comida in range(1, umbral * 3):
		var actual := _f(comida, gpt)
		assert_lte(actual - previo, salto_maximo,
			"salto brusco en comida=%d: %.2f → %.2f" % [comida, previo, actual])
		previo = actual


func test_en_el_umbral_de_comida_el_factor_es_neutro() -> void:
	# Continuidad por la izquierda: justo en el umbral todavía no hay amplificación.
	var w := _w()
	var gpt := _gpt_saturado(w, AIGamePhase.Phase.MID)
	assert_almost_eq(_f(int(w.surplus_min_food), gpt), 1.0, 0.001,
		"tener el margen justo no debe conceder amplificación militar")


# ---------------------------------------------------------------------------
# Los dos extremos se conservan
# ---------------------------------------------------------------------------

func test_sin_margen_de_comida_no_hay_amplificacion_aunque_sobre_el_oro() -> void:
	var w := _w()
	assert_almost_eq(_f(0, _gpt_saturado(w, AIGamePhase.Phase.MID) * 10), 1.0, 0.001,
		"sin comida no se sostienen tropas por mucho oro que haya")


func test_con_comida_holgada_y_oro_de_sobra_se_alcanza_el_techo() -> void:
	var w := _w()
	var gpt := _gpt_saturado(w, AIGamePhase.Phase.MID)
	assert_almost_eq(_f(int(w.surplus_min_food) * 2, gpt), w.surplus_max, 0.001,
		"al doblar el umbral de comida se alcanza surplus_max, igual que con el oro")


func test_el_factor_nunca_sale_de_su_banda() -> void:
	var w := _w()
	for comida in [-50, 0, 3, 5, 10, 500]:
		for gpt in [-100, 0, 100, 400, 5000]:
			var v := _f(comida, gpt)
			assert_between(v, 1.0, w.surplus_max,
				"comida=%d gpt=%d dio %.2f, fuera de [1, surplus_max]" % [comida, gpt, v])


# ---------------------------------------------------------------------------
# Monotonía en los dos ejes
# ---------------------------------------------------------------------------

func test_mas_comida_nunca_amplifica_menos() -> void:
	var w := _w()
	var gpt := _gpt_saturado(w, AIGamePhase.Phase.MID)
	var previo := _f(0, gpt)
	for comida in range(1, int(w.surplus_min_food) * 3):
		var actual := _f(comida, gpt)
		assert_gte(actual, previo, "el factor cayó al subir la comida a %d" % comida)
		previo = actual


func test_mas_oro_nunca_amplifica_menos() -> void:
	var w := _w()
	var comida := int(w.surplus_min_food) * 3
	var tope := int(_comfortable(w, AIGamePhase.Phase.MID) * 2.5)
	var previo := _f(comida, 0)
	for gpt in range(0, tope, 25):
		var actual := _f(comida, gpt)
		assert_gte(actual, previo, "el factor cayó al subir el gpt a %d" % gpt)
		previo = actual


# ---------------------------------------------------------------------------
# Simetría entre los dos ejes: es la propiedad que define la corrección
# ---------------------------------------------------------------------------

func test_los_dos_ejes_siguen_la_misma_regla_del_umbral_al_doble() -> void:
	# Con un eje saturado, el otro recorre 1.0 → surplus_max entre su umbral y el
	# doble. La propiedad que define la corrección: a la MISMA fracción de recorrido,
	# los dos ejes deben dar el mismo factor.
	#
	# Se usa 0.4 y no el punto medio a propósito: la comida es un int y el medio de
	# la rampa (umbral × 1.5 = 7.5) truncaría a 7, que es la fracción 0.4. Elegir el
	# 0.5 haría fallar al test por el truncamiento, no por el código.
	var w := _w()
	var phase := AIGamePhase.Phase.MID
	var fraccion := 0.4

	var por_oro := _f(int(w.surplus_min_food) * 3,
		int(_comfortable(w, phase) * (1.0 + fraccion)), phase)
	var por_comida := _f(int(w.surplus_min_food * (1.0 + fraccion)),
		_gpt_saturado(w, phase), phase)

	assert_almost_eq(por_oro, por_comida, 0.01,
		"a la misma fracción de recorrido, ambos ejes deben dar el mismo factor")
	assert_almost_eq(por_comida, lerpf(1.0, w.surplus_max, fraccion), 0.01,
		"y esa fracción de recorrido debe mapear a la misma fracción de la banda")


func test_la_fase_solo_mueve_el_umbral_del_oro() -> void:
	# Guarda: el eje de la comida no depende de la fase; el del oro sí.
	var w := _w()
	var comida := int(w.surplus_min_food) * 3
	for phase in [AIGamePhase.Phase.EARLY, AIGamePhase.Phase.MID, AIGamePhase.Phase.LATE]:
		assert_almost_eq(_f(comida, _gpt_saturado(w, phase), phase), w.surplus_max, 0.001,
			"con el oro al doble de SU umbral de fase, el techo debe alcanzarse igual")
