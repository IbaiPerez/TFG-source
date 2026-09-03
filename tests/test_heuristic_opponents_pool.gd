extends GutTest

## Composición de los POOLS de rivales del optimizador.
##
## Lo que fija este fichero es una decisión de método, no un detalle: contra quién
## se mide un candidato determina qué acaba optimizando el algoritmo. El reparto
## —muchos rivales con pocas partidas en la búsqueda, pocos rivales con muchas
## partidas en la selección— responde a dos objetivos distintos, y los dos tienen
## su guarda aquí.


const SEED_BUSQUEDA := 31337
const SEED_SELECCION := 80085


## Identidad de un rival: su VECTOR completo de pesos optimizables.
##
## Usar dos campos sueltos como firma no vale, y esto lo descubrió el propio test
## al fallar: `expansionist()` no toca ni `gold_weight_pos` ni
## `recruit_atkdef_weight`, así que con esa firma era indistinguible de la baseline
## y denunciaba solapamientos que no existían.
func _firma(cfg: AIConfig) -> String:
	return str(HeuristicWeightsSpec.to_vector(cfg.heuristic_weights,
		HeuristicWeightsSpec.OPTIMIZABLE_KEYS))


# ---------------------------------------------------------------------------
# Los mismos rivales para todos los candidatos
# ---------------------------------------------------------------------------

func test_el_pool_de_busqueda_es_reproducible() -> void:
	# EL invariante que hace comparables los win-rate entre candidatos: dos
	# llamadas con la misma semilla dan exactamente los mismos rivales. Si el pool
	# variara, un candidato podría perder por haberle tocado un pool más duro.
	var a := HeuristicOpponents.search_pool(SEED_BUSQUEDA, 6)
	var b := HeuristicOpponents.search_pool(SEED_BUSQUEDA, 6)
	assert_eq(a.size(), b.size())
	for i in range(a.size()):
		var wa := (a[i] as AIConfig).heuristic_weights
		var wb := (b[i] as AIConfig).heuristic_weights
		for k in HeuristicWeightsSpec.OPTIMIZABLE_KEYS:
			assert_almost_eq(float(wa.get(k)), float(wb.get(k)), 0.0001,
				"rival %d difiere en %s entre dos construcciones" % [i, k])


func test_semillas_distintas_dan_rivales_distintos() -> void:
	var a := HeuristicOpponents.search_pool(SEED_BUSQUEDA, 6)
	var b := HeuristicOpponents.search_pool(SEED_BUSQUEDA + 1, 6)
	var iguales := true
	for i in range(a.size()):
		var wa := (a[i] as AIConfig).heuristic_weights
		var wb := (b[i] as AIConfig).heuristic_weights
		if not is_equal_approx(float(wa.gold_weight_pos), float(wb.gold_weight_pos)):
			iguales = false
	assert_false(iguales, "otra semilla debe producir otro pool")


# ---------------------------------------------------------------------------
# Búsqueda: muchos rivales
# ---------------------------------------------------------------------------

func test_el_pool_de_busqueda_tiene_muchos_rivales() -> void:
	# Con presupuesto total fijo, la varianza de la estimación es
	# σ²_entre_rivales/k + E[p(1−p)]/G: el término binomial depende solo del TOTAL,
	# así que más rivales reduce el error sin gastar más partidas. Y sobre todo:
	# cuantos más estilos haya que batir, menos margen para especializarse.
	var pool := HeuristicOpponents.search_pool(SEED_BUSQUEDA, 16)
	assert_gte(pool.size(), 15, "la búsqueda necesita variedad, no precisión")


func test_los_rivales_de_busqueda_son_coherentes() -> void:
	for cfg in HeuristicOpponents.search_pool(SEED_BUSQUEDA, 10):
		var w := (cfg as AIConfig).heuristic_weights
		assert_eq(HeuristicWeightsInvariants.validate(w).size(), 0,
			"un rival con cadenas rotas es más débil de lo previsto")


func test_los_rivales_de_busqueda_no_se_repiten() -> void:
	# Un pool con rivales clonados mide una sola cosa muchas veces.
	var vistos := {}
	for cfg in HeuristicOpponents.search_pool(SEED_BUSQUEDA, 12):
		var f := _firma(cfg as AIConfig)
		assert_false(vistos.has(f), "dos rivales idénticos en el pool de búsqueda")
		vistos[f] = true


# ---------------------------------------------------------------------------
# Selección: held-out de verdad
# ---------------------------------------------------------------------------

func test_los_dos_pools_no_comparten_ningun_rival() -> void:
	# EL punto de todo esto. Si el pool que ELIGE al campeón comparte rivales con
	# el que lo BUSCÓ, se está premiando la especialización. Antes compartían tres
	# de cuatro.
	var firmas := {}
	for cfg in HeuristicOpponents.search_pool(SEED_BUSQUEDA, 16):
		firmas[_firma(cfg as AIConfig)] = true
	for cfg in HeuristicOpponents.selection_pool(SEED_SELECCION, 12):
		assert_false(firmas.has(_firma(cfg as AIConfig)),
			"un rival de selección ya estaba en la búsqueda")


func test_la_baseline_esta_en_seleccion_y_no_en_busqueda() -> void:
	# Deliberado: así «el campeón gana a los pesos por defecto» es una afirmación
	# sobre un rival que la búsqueda nunca vio.
	var firma_baseline := str(HeuristicWeightsSpec.to_vector(HeuristicWeights.new(),
		HeuristicWeightsSpec.OPTIMIZABLE_KEYS))

	var en_seleccion := false
	for cfg in HeuristicOpponents.selection_pool(SEED_SELECCION, 6):
		if _firma(cfg as AIConfig) == firma_baseline:
			en_seleccion = true
	assert_true(en_seleccion, "la baseline es la referencia: debe estar en selección")

	for cfg in HeuristicOpponents.search_pool(SEED_BUSQUEDA, 16):
		assert_ne(_firma(cfg as AIConfig), firma_baseline,
			"la baseline no debe entrar en la búsqueda")


# ---------------------------------------------------------------------------
# Nada de política aleatoria en los pools de fitness
# ---------------------------------------------------------------------------

func test_ningun_pool_incluye_politica_aleatoria() -> void:
	# Medido en la corrida real: `Mode.RANDOM` separaba a los finalistas por 0.056
	# de win-rate frente al ~0.30 de los rivales de verdad.
	for pool in [HeuristicOpponents.search_pool(SEED_BUSQUEDA, 8),
			HeuristicOpponents.selection_pool(SEED_SELECCION, 8)]:
		for cfg in pool:
			assert_eq((cfg as AIConfig).mode, AIConfig.Mode.HEURISTIC,
				"los pools de fitness son de heurística pura")
