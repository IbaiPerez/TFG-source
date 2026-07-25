extends GutTest

## Tests de HeuristicWeights: interfaz vectorial para el optimizador, límites de
## búsqueda y semántica del default cacheado. La equivalencia byte-idéntica del
## comportamiento de la heurística con los pesos por defecto la cubren
## test_ai_heuristic.gd / test_ai_heuristic_extended.gd (valores exactos).


func test_to_vector_size_matches_optimizable_keys() -> void:
	var w := HeuristicWeights.new()
	assert_eq(w.to_vector().size(), HeuristicWeights.OPTIMIZABLE_KEYS.size())


func test_apply_vector_is_inverse_of_to_vector() -> void:
	var w := HeuristicWeights.new()
	var v := w.to_vector()
	var w2 := HeuristicWeights.new()
	w2.apply_vector(v)
	assert_eq(w2.to_vector(), v)


func test_mutated_vector_roundtrips_per_key() -> void:
	var base := HeuristicWeights.new().to_vector()
	var mutated := base.duplicate()
	for i in range(mutated.size()):
		mutated[i] = mutated[i] + 1.0
	var w := HeuristicWeights.new()
	w.apply_vector(mutated)
	var keys := HeuristicWeights.OPTIMIZABLE_KEYS
	for i in range(keys.size()):
		assert_almost_eq(float(w.get(keys[i])), base[i] + 1.0, 0.0001,
			"clave %s no hace round-trip" % keys[i])


func test_get_default_is_cached() -> void:
	assert_true(HeuristicWeights.get_default() == HeuristicWeights.get_default(),
		"get_default() debe devolver siempre la misma instancia cacheada")


func test_bounds_contain_default_values() -> void:
	var w := HeuristicWeights.get_default()
	for k in HeuristicWeights.OPTIMIZABLE_KEYS:
		var b := HeuristicWeights.get_bounds(k)
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
	for key in HeuristicWeights.SPEC:
		assert_ne(w.get(key), null,
			"SPEC declara '%s' pero no existe como propiedad" % key)


func test_optimizable_keys_derived_from_spec() -> void:
	# OPTIMIZABLE_KEYS = exactamente las claves de SPEC con opt:true.
	for key in HeuristicWeights.OPTIMIZABLE_KEYS:
		assert_true(HeuristicWeights.SPEC.has(key) and HeuristicWeights.SPEC[key].get("opt", false),
			"'%s' está en OPTIMIZABLE_KEYS pero no marcada opt:true en SPEC" % key)
	var opt_count := 0
	for key in HeuristicWeights.SPEC:
		if HeuristicWeights.SPEC[key].get("opt", false):
			opt_count += 1
	assert_eq(HeuristicWeights.OPTIMIZABLE_KEYS.size(), opt_count,
		"OPTIMIZABLE_KEYS debe tener tantas claves como entradas opt:true en SPEC")


func test_validate_passes_on_defaults() -> void:
	var errors := HeuristicWeights.new().validate()
	assert_eq(errors.size(), 0,
		"los pesos por defecto deben validar sin errores: %s" % str(errors))


func test_validate_detects_non_monotonic_urgency() -> void:
	var w := HeuristicWeights.new()
	w.gold_urg_early_t1 = w.gold_urg_early_t0 - 1.0  # rompe la monotonía
	assert_gt(w.validate().size(), 0,
		"validate() debe detectar una curva de urgencia no creciente")


func test_partial_keys_vector() -> void:
	var w := HeuristicWeights.new()
	var keys := PackedStringArray(["gold_weight_pos", "food_weight"])
	var v := w.to_vector(keys)
	assert_eq(v.size(), 2)
	v[0] = 42.0
	v[1] = 7.0
	w.apply_vector(v, keys)
	assert_eq(w.gold_weight_pos, 42.0)
	assert_eq(w.food_weight, 7.0)
	# El resto de campos permanece intacto.
	assert_eq(w.defense_weight, HeuristicWeights.get_default().defense_weight)
