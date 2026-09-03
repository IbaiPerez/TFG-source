extends GutTest

## Composición del POOL de rivales del optimizador.
##
## Lo que fija este fichero es una decisión de método, no un detalle: contra quién
## se mide un candidato determina qué acaba optimizando el algoritmo.

func test_el_pool_completo_no_incluye_politica_aleatoria() -> void:
	# Medido en la corrida real de dos etapas: el rival `Mode.RANDOM` separaba a
	# los tres finalistas por 0.056 de win-rate (0.887 / 0.906 / 0.944) mientras
	# los rivales de verdad los separaban ~0.30. Era un quinto del presupuesto de
	# partidas gastado en una pregunta ya respondida —todos le ganan— e inflaba el
	# win-rate global de todos por igual.
	for cfg in HeuristicOpponents.full_pool():
		assert_ne((cfg as AIConfig).mode, AIConfig.Mode.RANDOM,
			"la política aleatoria no discrimina entre candidatos: fuera del pool")


func test_el_pool_ligero_tampoco() -> void:
	for cfg in HeuristicOpponents.core_pool():
		assert_ne((cfg as AIConfig).mode, AIConfig.Mode.RANDOM)


func test_los_dos_pools_son_de_heuristica_pura() -> void:
	# Sin MCTS: cada evaluación es una partida, y el coste del árbol haría
	# inviable la búsqueda.
	for pool in [HeuristicOpponents.core_pool(), HeuristicOpponents.full_pool()]:
		for cfg in pool:
			assert_eq((cfg as AIConfig).mode, AIConfig.Mode.HEURISTIC)


func test_el_pool_completo_contiene_a_la_baseline() -> void:
	# La baseline tiene que estar: es la referencia contra la que se juzga si la
	# optimización ha mejorado algo. Sin ella no hay punto de comparación.
	var w := HeuristicWeights.new()
	var encontrada := false
	for cfg in HeuristicOpponents.full_pool():
		var op := (cfg as AIConfig).heuristic_weights
		if op != null and is_equal_approx(op.gold_weight_pos, w.gold_weight_pos) \
				and is_equal_approx(op.recruit_atkdef_weight, w.recruit_atkdef_weight):
			encontrada = true
	assert_true(encontrada, "el pool debe incluir los pesos por defecto")


func test_los_arquetipos_son_distintos_entre_si() -> void:
	# Un pool con rivales casi idénticos mide una sola cosa tres veces.
	var vistos := {}
	for cfg in HeuristicOpponents.full_pool():
		var op := (cfg as AIConfig).heuristic_weights
		if op != null:
			var firma := "%.3f|%.3f|%.3f" % [op.gold_weight_pos,
				op.recruit_atkdef_weight, op.colonize_expansion]
			assert_false(vistos.has(firma), "dos rivales del pool son iguales: %s" % firma)
			vistos[firma] = true
	assert_gte(vistos.size(), 4, "baseline + 3 arquetipos contrastados")


func test_los_rivales_del_pool_son_coherentes() -> void:
	# Los arquetipos escalan grupos de pesos del default; si alguno cruzara una
	# cadena ordenada, el rival tendría tramos muertos y mediría otra cosa.
	for cfg in HeuristicOpponents.full_pool():
		var op := (cfg as AIConfig).heuristic_weights
		if op != null:
			assert_eq(HeuristicWeightsInvariants.validate(op).size(), 0,
				"un rival del pool no debe tener invariantes rotos")


func test_los_rivales_aleatorios_del_heldout_son_coherentes() -> void:
	# Desde que las curvas de urgencia entraron en el espacio, escalar cada umbral
	# por su propio factor los cruza constantemente: medido, 36 de 50 semillas
	# daban un rival con alguna cadena rota. Un rival con tramos muertos es más
	# débil de lo previsto e inflaría la generalización aparente del campeón.
	for semilla in range(12):
		var rng := RandomNumberGenerator.new()
		rng.seed = semilla
		var w := HeuristicOpponents.random_heuristic(rng, 0.5)
		assert_eq(HeuristicWeightsInvariants.validate(w).size(), 0,
			"el rival aleatorio de semilla %d tiene invariantes rotos" % semilla)
