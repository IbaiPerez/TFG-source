extends GutTest

## `build_cost_factor` modula el score de BUILD y UPGRADE por lo que cuesta el
## edificio. Medía **coste / oro disponible**, y eso tenía dos defectos medidos sobre
## el catálogo real (48 edificios, coste 50–800):
##
##   1. Apenas discriminaba. Con 300 o con 1500 de oro el orden de los edificios era
##      prácticamente el mismo: el rango [build_cost_min, 1.0] solo reescalaba. Y la
##      asequibilidad DURA ya la resuelve AILegality.build_targets aguas arriba, que
##      descarta `coste > oro` antes de puntuar.
##   2. Invertía su sentido con los edificios malos. Un multiplicador en (0,1) sobre
##      un valor NEGATIVO lo acerca a cero: `academia_militar` (coste 350, −10 de oro)
##      puntuaba −7.5 con poco oro y −11.3 con mucho. El «castigo por caro» hacía que
##      un edificio malo pareciera menos malo cuanto menos podías permitírtelo.
##
## Ahora mide **coste por unidad de valor** contra `build_cost_ref`, y se aplica con
## `apply_build_cost`, que encoge la magnitud de lo bueno y agranda la de lo malo.
## Sigue acotado a [build_cost_min, 1.0], así que la escala de BUILD no cambia y la
## calibración frente a COLONIZE y RECRUIT se conserva.


func _w() -> HeuristicWeights:
	return HeuristicWeights.new()


# ---------------------------------------------------------------------------
# Qué mide el factor
# ---------------------------------------------------------------------------

func test_a_igual_valor_lo_mas_barato_es_mas_eficiente() -> void:
	var w := _w()
	var valor := 100.0
	assert_gt(AIEconomy.build_cost_factor(50, valor, w),
		AIEconomy.build_cost_factor(400, valor, w),
		"con el mismo valor, el edificio barato debe salir mejor parado")


func test_a_igual_coste_lo_que_mas_da_es_mas_eficiente() -> void:
	# Este es el eje que ANTES no existía: el factor no miraba el valor en absoluto.
	var w := _w()
	assert_gt(AIEconomy.build_cost_factor(200, 150.0, w),
		AIEconomy.build_cost_factor(200, 40.0, w),
		"con el mismo coste, el que más produce debe salir mejor parado")


func test_es_monotono_decreciente_en_el_coste() -> void:
	var w := _w()
	var previo := AIEconomy.build_cost_factor(10, 100.0, w)
	for coste in range(20, 800, 20):
		var actual := AIEconomy.build_cost_factor(coste, 100.0, w)
		assert_lte(actual, previo, "el factor subió al encarecer a %d" % coste)
		previo = actual


func test_sigue_acotado_a_su_banda() -> void:
	var w := _w()
	for coste in [0, 1, 200, 5000]:
		for valor in [-500.0, -1.0, 0.0, 1.0, 500.0]:
			var f := AIEconomy.build_cost_factor(coste, valor, w)
			assert_between(f, w.build_cost_min, 1.0,
				"coste=%d valor=%.1f dio %.3f, fuera de banda" % [coste, valor, f])


# ---------------------------------------------------------------------------
# El signo: el defecto que nadie veía
# ---------------------------------------------------------------------------

func test_encarecer_un_edificio_malo_lo_empeora() -> void:
	# EL test que discrimina. Antes, encarecer un edificio de valor negativo subía su
	# score acercándolo a cero.
	var w := _w()
	var malo := -50.0
	assert_lt(AIEconomy.apply_build_cost(malo, 400, w),
		AIEconomy.apply_build_cost(malo, 50, w),
		"un edificio perjudicial debe puntuar PEOR cuanto más caro, no mejor")


func test_encarecer_un_edificio_bueno_lo_empeora_tambien() -> void:
	# La otra mitad: la penalización debe ir en el mismo sentido en los dos signos.
	var w := _w()
	var bueno := 50.0
	assert_lt(AIEconomy.apply_build_cost(bueno, 400, w),
		AIEconomy.apply_build_cost(bueno, 50, w),
		"un edificio útil también debe puntuar peor cuanto más caro")


func test_el_coste_nunca_cambia_el_signo_del_score() -> void:
	# Un edificio perjudicial no puede volverse jugable por ser caro (PASS vale 0.0).
	var w := _w()
	for coste in [0, 50, 400, 5000]:
		assert_lt(AIEconomy.apply_build_cost(-10.0, coste, w), 0.0,
			"coste=%d convirtió un valor negativo en no-negativo" % coste)
		assert_gt(AIEconomy.apply_build_cost(10.0, coste, w), 0.0,
			"coste=%d convirtió un valor positivo en no-positivo" % coste)


# ---------------------------------------------------------------------------
# Ya no depende del oro disponible: extremo a extremo por score_build
# ---------------------------------------------------------------------------

func _score_build_con_oro(oro: int, gold_produced: int, coste: int) -> float:
	var stats := TestBuilders.stats().with_gold(oro).with_gpt(200).with_food(20).build()
	var ctx := TestBuilders.context(stats).build()
	var b := TestBuilders.building().with_gold(gold_produced).with_cost(coste).build()
	return AIMoveScorer.score_build(LiveStateView.new(ctx), b, null)


func test_el_score_de_construir_ya_no_depende_del_oro_en_caja() -> void:
	# La asequibilidad dura es de AILegality, no de este factor. Que el score del
	# MISMO edificio cambiara según el saldo hacía que el orden entre edificios se
	# moviera con el dinero en caja, sin que ninguno hubiera cambiado.
	assert_almost_eq(_score_build_con_oro(300, 10, 200),
		_score_build_con_oro(5000, 10, 200), 0.001,
		"el mismo edificio debe valer lo mismo con 300 que con 5000 de oro")


func test_extremo_a_extremo_el_edificio_perjudicial_empeora_al_encarecerse() -> void:
	assert_lt(_score_build_con_oro(1000, -10, 400),
		_score_build_con_oro(1000, -10, 50),
		"por score_build: encarecer un edificio de producción negativa debe empeorarlo")
