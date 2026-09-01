extends GutTest

## Tests de AIEconomy: los factores económicos unificados de la heurística.
##
## Las aserciones afirman contra el CAMPO DE PESO, no contra su valor actual, y las
## ENTRADAS también se derivan del peso. Así cada test dice la regla ("al doble del
## umbral cómodo se alcanza el máximo") en vez de una coincidencia aritmética, y
## sobrevive a que el optimizador reajuste los defaults. Afirmar contra el literal
## tenía el problema de siempre: al cambiar un peso el test falla sin que nada esté
## roto, y —peor— si cambia el umbral de ENTRADA el test sigue verde midiendo otra
## cosa.
##
## `1.0` sí se deja literal donde aparece: no es un peso, es la identidad "sin
## excedente / sin penalización".

const NEUTRO := 1.0


func _w() -> HeuristicWeights:
	return HeuristicWeights.new()


## Comida que SATURA el eje de la comida, para que los tests del eje del ORO midan
## solo el oro. Los dos ejes rampan igual —neutro en el umbral, pleno al doblarlo—,
## así que hace falta el DOBLE del umbral, no el umbral justo.
##
## Antes bastaba con `int(w.surplus_min_food)` porque el eje de la comida era un
## acantilado binario: en el umbral ya daba el máximo. Al convertirlo en rampa, ese
## valor pasó a ser el punto NEUTRO y estos tests empezaron a medir un factor de 1.0
## creyendo que medían el eje del oro.
func _comida_holgada(w: HeuristicWeights) -> int:
	return int(w.surplus_min_food) * 2


# ------------------------------------------------------------------
#  Excedente de recursos
# ------------------------------------------------------------------

func test_surplus_requires_food_margin() -> void:
	var w := _w()
	# Por debajo del margen de comida no hay excedente aunque sobre el oro:
	# sin comida no se sostienen tropas.
	var sin_margen := int(w.surplus_min_food) - 1
	var oro_de_sobra := int(w.surplus_comfortable_mid * 10)
	assert_almost_eq(
		AIEconomy.resource_surplus_factor(sin_margen, oro_de_sobra, AIGamePhase.Phase.MID, w),
		NEUTRO, 0.001)


func test_surplus_neutral_below_comfortable() -> void:
	var w := _w()
	# Justo EN el umbral cómodo todavía es neutro (la banda abre por encima).
	assert_almost_eq(AIEconomy.resource_surplus_factor(
		int(w.surplus_min_food), int(w.surplus_comfortable_mid), AIGamePhase.Phase.MID, w),
		NEUTRO, 0.001)


func test_surplus_scales_above_comfortable() -> void:
	var w := _w()
	var comodo := w.surplus_comfortable_mid
	var comida := _comida_holgada(w)

	# Los dos EXTREMOS son exactos sea cual sea el umbral: en el umbral, neutro;
	# al doble, el máximo.
	assert_almost_eq(AIEconomy.resource_surplus_factor(
		comida, int(comodo * 2.0), AIGamePhase.Phase.MID, w), w.surplus_max, 0.001)

	# En medio se afirma la PROPIEDAD (creciente y acotada), no el valor exacto de
	# la interpolación. Fijar aquí `lerpf(neutro, max, 0.5)` parecía más preciso pero
	# es falso: `int(comodo * 1.5)` trunca, y con un umbral impar el punto medio no
	# cae en 0.5. El test fallaría por la truncación, no por un cambio de regla.
	var medio := AIEconomy.resource_surplus_factor(
		comida, int(comodo * 1.5), AIGamePhase.Phase.MID, w)
	assert_gt(medio, NEUTRO, "por encima del umbral ya hay excedente")
	assert_lt(medio, w.surplus_max, "pero no se alcanza el máximo hasta el doble")

	# Y es monótona: más oro nunca puede dar menos excedente.
	assert_gt(medio, AIEconomy.resource_surplus_factor(
		comida, int(comodo * 1.25), AIGamePhase.Phase.MID, w))


func test_surplus_esta_topado_muy_por_encima_del_doble() -> void:
	# HUECO REAL que no cubría ningún test: todas las entradas se quedaban entre el
	# umbral y su doble, que es justo donde el clamp superior NO se nota. Sin este
	# caso, quitar el clamp de la fórmula dejaba la suite en verde y el excedente
	# crecía sin techo — un imperio rico habría valorado lo militar hasta el absurdo.
	var w := _w()
	var comida := _comida_holgada(w)
	for factor in [3.0, 10.0, 100.0]:
		assert_almost_eq(AIEconomy.resource_surplus_factor(
			comida, int(w.surplus_comfortable_mid * factor), AIGamePhase.Phase.MID, w),
			w.surplus_max, 0.001,
			"a %.0f× el umbral el excedente sigue topado en el máximo" % factor)


func test_surplus_uses_phase_thresholds() -> void:
	var w := _w()
	var comida := _comida_holgada(w)
	# Cada fase tiene su propio umbral cómodo: lo que es excedente en EARLY no lo es
	# en LATE. El test lo comprueba en los dos extremos de la escala.
	assert_almost_eq(AIEconomy.resource_surplus_factor(
		comida, int(w.surplus_comfortable_early), AIGamePhase.Phase.EARLY, w),
		NEUTRO, 0.001)
	assert_almost_eq(AIEconomy.resource_surplus_factor(
		comida, int(w.surplus_comfortable_late * 2.0), AIGamePhase.Phase.LATE, w),
		w.surplus_max, 0.001)
	# Y el mismo gpt cae en bandas distintas según la fase.
	var gpt := int(w.surplus_comfortable_late)
	assert_gt(AIEconomy.resource_surplus_factor(comida, gpt, AIGamePhase.Phase.EARLY, w),
		AIEconomy.resource_surplus_factor(comida, gpt, AIGamePhase.Phase.LATE, w),
		"el umbral EARLY es más bajo, así que el mismo gpt es más excedente en EARLY")


# ------------------------------------------------------------------
#  Coste de construcción
# ------------------------------------------------------------------

# El segundo argumento es el VALOR del edificio, no el oro en caja: el factor mide
# coste por unidad de valor. Estos tests decían antes "full_spend" / "half_spend",
# nombres de una fracción de gasto que ya no existe — y que, tras el cambio, habrían
# seguido pasando midiendo otra cosa si no se reescriben.

func test_build_cost_factor_sin_valor_toca_el_suelo() -> void:
	# Un edificio que no aporta nada es el peor negocio posible, cueste lo que cueste.
	assert_almost_eq(AIEconomy.build_cost_factor(50, 0.0, _w()), _w().build_cost_min, 0.001)


func test_build_cost_factor_toca_el_suelo_en_la_referencia() -> void:
	# El suelo se alcanza cuando el coste por unidad de valor llega a build_cost_ref.
	var w := _w()
	var valor := 100.0
	assert_almost_eq(AIEconomy.build_cost_factor(int(valor * w.build_cost_ref), valor, w),
		w.build_cost_min, 0.001)


func test_build_cost_factor_a_media_referencia_esta_a_media_banda() -> void:
	var w := _w()
	var valor := 100.0
	assert_almost_eq(
		AIEconomy.build_cost_factor(int(valor * w.build_cost_ref * 0.5), valor, w),
		lerpf(NEUTRO, w.build_cost_min, 0.5), 0.001)


func test_build_cost_factor_coste_residual_frente_al_valor_es_neutro() -> void:
	# Un coste ínfimo comparado con lo que da apenas penaliza.
	assert_gt(AIEconomy.build_cost_factor(1, 10000.0, _w()), 0.99)
