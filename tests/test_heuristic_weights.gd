extends GutTest

## Tests de HeuristicWeights: interfaz vectorial para el optimizador, límites de
## búsqueda y semántica del default cacheado. La equivalencia byte-idéntica del
## comportamiento de la heurística con los pesos por defecto la cubren
## test_ai_heuristic.gd / test_ai_heuristic_extended.gd (valores exactos).


func test_to_vector_size_matches_optimizable_keys() -> void:
	var w := HeuristicWeights.new()
	assert_eq(HeuristicWeightsSpec.to_vector(w).size(), HeuristicWeightsSpec.OPTIMIZABLE_KEYS.size())


func test_apply_vector_is_inverse_of_to_vector() -> void:
	var w := HeuristicWeights.new()
	var v := HeuristicWeightsSpec.to_vector(w)
	var w2 := HeuristicWeights.new()
	HeuristicWeightsSpec.apply_vector(w2, v)
	assert_eq(HeuristicWeightsSpec.to_vector(w2), v)


func test_mutated_vector_roundtrips_per_key() -> void:
	var base := HeuristicWeightsSpec.to_vector(HeuristicWeights.new())
	var mutated := base.duplicate()
	for i in range(mutated.size()):
		mutated[i] = mutated[i] + 1.0
	var w := HeuristicWeights.new()
	HeuristicWeightsSpec.apply_vector(w, mutated)
	var keys := HeuristicWeightsSpec.OPTIMIZABLE_KEYS
	for i in range(keys.size()):
		assert_almost_eq(float(w.get(keys[i])), base[i] + 1.0, 0.0001,
			"clave %s no hace round-trip" % keys[i])


func test_get_default_is_cached() -> void:
	assert_true(HeuristicWeights.get_default() == HeuristicWeights.get_default(),
		"get_default() debe devolver siempre la misma instancia cacheada")


## Canario del contrato de solo-lectura del default (C7 §1.10). La instancia es
## COMPARTIDA por todo el proceso, así que si algún código de producción escribiera
## en ella corrompería todas las partidas y todas las tandas de simulación. Este
## test lo detecta comparando el default con una instancia recién creada.
func test_get_default_is_not_mutated_by_production_code() -> void:
	var shared := HeuristicWeights.get_default()
	var fresh := HeuristicWeights.new()
	for key in HeuristicWeightsSpec.SPEC.keys():
		assert_almost_eq(float(shared.get(key)), float(fresh.get(key)), 0.0000001,
			"El default compartido fue MUTADO en '%s': es de solo lectura" % key)


func test_bounds_contain_default_values() -> void:
	var w := HeuristicWeights.get_default()
	for k in HeuristicWeightsSpec.OPTIMIZABLE_KEYS:
		var b := HeuristicWeightsSpec.get_bounds(k)
		var d := float(w.get(k))
		assert_between(d, b.x - 0.0001, b.y + 0.0001,
			"default de %s (%.4f) debe caer dentro de [%.4f, %.4f]" % [k, d, b.x, b.y])


func test_clone_is_deep_copy() -> void:
	var w := HeuristicWeights.new()
	var original := w.gold_weight_pos
	var c := w.clone()
	c.gold_weight_pos = original + 123.0
	assert_eq(w.gold_weight_pos, original, "el original no debe mutar")
	assert_eq(c.gold_weight_pos, original + 123.0, "la copia sí debe reflejar el cambio")


func test_spec_keys_are_real_properties() -> void:
	# Cada clave de SPEC debe existir como propiedad (atrapa typos).
	var w := HeuristicWeights.new()
	for key in HeuristicWeightsSpec.SPEC:
		assert_ne(w.get(key), null,
			"SPEC declara '%s' pero no existe como propiedad" % key)


func test_optimizable_keys_derived_from_spec() -> void:
	# OPTIMIZABLE_KEYS = exactamente las claves de SPEC con opt:true.
	for key in HeuristicWeightsSpec.OPTIMIZABLE_KEYS:
		assert_true(HeuristicWeightsSpec.SPEC.has(key) and HeuristicWeightsSpec.SPEC[key].get("opt", false),
			"'%s' está en OPTIMIZABLE_KEYS pero no marcada opt:true en SPEC" % key)
	var opt_count := 0
	for key in HeuristicWeightsSpec.SPEC:
		if HeuristicWeightsSpec.SPEC[key].get("opt", false):
			opt_count += 1
	assert_eq(HeuristicWeightsSpec.OPTIMIZABLE_KEYS.size(), opt_count,
		"OPTIMIZABLE_KEYS debe tener tantas claves como entradas opt:true en SPEC")


func test_validate_passes_on_defaults() -> void:
	var errors := HeuristicWeightsInvariants.validate(HeuristicWeights.new())
	assert_eq(errors.size(), 0,
		"los pesos por defecto deben validar sin errores: %s" % str(errors))


func test_validate_detects_non_monotonic_urgency() -> void:
	var w := HeuristicWeights.new()
	w.gold_urg_early_t1 = w.gold_urg_early_t0 - 1.0  # rompe la monotonía
	assert_gt(HeuristicWeightsInvariants.validate(w).size(), 0,
		"validate() debe detectar una curva de urgencia no creciente")


func test_partial_keys_vector() -> void:
	var w := HeuristicWeights.new()
	var keys := PackedStringArray(["gold_weight_pos", "food_weight"])
	var v := HeuristicWeightsSpec.to_vector(w, keys)
	assert_eq(v.size(), 2)
	v[0] = 42.0
	v[1] = 7.0
	HeuristicWeightsSpec.apply_vector(w, v, keys)
	assert_eq(w.gold_weight_pos, 42.0)
	assert_eq(w.food_weight, 7.0)
	# El resto de campos permanece intacto.
	assert_eq(w.defense_weight, HeuristicWeights.get_default().defense_weight)


# ---------------------------------------------------------------------------
# Reglas del juego que la IA solo CREE (no debe reimplementarlas con un literal)
# ---------------------------------------------------------------------------

func test_el_umbral_terminal_del_mcts_sigue_a_la_regla_de_victoria() -> void:
	# state_victory_share NO es un peso: es la condicion de dominacion vista por
	# el arbol. Si divergiera de GameBalance, el MCTS daria por ganadas partidas
	# que el juego no termina (o al reves) y ninguna otra prueba lo notaria,
	# porque los tests de score_state afirman signos, no umbrales.
	assert_eq(HeuristicWeights.new().state_victory_share,
		GameBalance.VICTORY_TILE_SHARE,
		"el umbral terminal del MCTS debe derivar de la regla de victoria")


func test_el_horizonte_de_cards_per_turn_sigue_a_la_regla_de_victoria() -> void:
	assert_eq(HeuristicWeights.new().se_cpt_share_target,
		GameBalance.VICTORY_TILE_SHARE,
		"el horizonte 'cuanto me falta para ganar' debe derivar de la misma regla")


func test_las_reglas_no_entran_en_el_espacio_de_busqueda() -> void:
	# Son creencias sobre las REGLAS, no preferencias: el optimizador no debe
	# poder moverlas, o produciria un campeon que juega con otro reglamento.
	for key in ["state_victory_share", "se_cpt_share_target"]:
		assert_false(HeuristicWeightsSpec.OPTIMIZABLE_KEYS.has(key),
			"%s no debe ser optimizable" % key)


func test_el_tres_campeon_sigue_cargando() -> void:
	# Guarda del ciclo de clases: HeuristicWeights es un Resource que se carga
	# desde .tres y ahora referencia GameBalance. Si esa referencia crease un
	# ciclo, load() devolveria null EN EJECUCION, sin error de parseo y con el
	# reimport headless en EXIT=0 — o sea, en silencio.
	var champion := load("res://resources/ai/heuristic_weights_optimized.tres")
	assert_not_null(champion, "el .tres campeon debe seguir cargando")
	assert_true(champion is HeuristicWeights, "y debe seguir siendo HeuristicWeights")
