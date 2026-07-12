extends RefCounted
class_name GAOptimizer

## Algoritmo genético sobre el vector de pesos de la heurística.
##
## Maximiza el win-rate (HeuristicFitness). Individuos = vectores sobre
## HeuristicWeights.OPTIMIZABLE_KEYS (o claves personalizadas). Selección por
## torneo, cruce BLX-α, mutación Gaussiana por gen y elitismo. La población se
## siembra con el default exacto (ancla baseline) más variantes perturbadas.
##
## Uso:
##   var ga := GAOptimizer.new(fitness, 999)
##   ga.pop_size = 16; ga.generations = 15
##   var champ := await ga.run()


var fitness: HeuristicFitness
var keys: PackedStringArray
var rng := RandomNumberGenerator.new()

# --- Hiperparámetros ---------------------------------------------------------
var pop_size: int = 16
var generations: int = 15
var tournament_k: int = 3
var mutation_prob: float = 0.2    ## probabilidad de mutar cada gen
var mutation_frac: float = 0.15   ## σ de mutación como fracción del rango
var blx_alpha: float = 0.3        ## expansión del intervalo en el cruce BLX-α
var elitism: int = 2              ## nº de mejores que pasan intactos
var init_spread: float = 0.25     ## dispersión inicial (fracción del rango)

# --- Estado / traza ----------------------------------------------------------
var best_weights: HeuristicWeights
var best_fitness: float = -1.0
var trace: Array = []             ## [{gen, best, mean}]


func _init(p_fitness: HeuristicFitness, p_seed: int = 999) -> void:
	fitness = p_fitness
	rng.seed = p_seed


## Ejecuta el GA y devuelve el mejor candidato. `seed_weights` = ancla de la
## población inicial (default: pesos por defecto).
func run(seed_weights: HeuristicWeights = null) -> HeuristicWeights:
	if keys.is_empty():
		keys = HeuristicWeights.OPTIMIZABLE_KEYS
	var base := seed_weights.clone() if seed_weights != null else HeuristicWeights.new()
	var base_vec := base.to_vector(keys)

	# Población inicial: individuo 0 = base exacto (ancla); resto perturbados.
	var pop: Array = [base_vec.duplicate()]
	for i in range(1, pop_size):
		pop.append(_random_near(base_vec))

	var fits: Array = []
	fits.resize(pop_size)
	for i in range(pop_size):
		fits[i] = await _eval_vec(pop[i])
		_track(pop[i], fits[i])
	print("[GA] gen  0 (init): best=%.3f mean=%.3f" % [best_fitness, _mean(fits)])

	for gen in range(generations):
		var order := _argsort_desc(fits)
		var new_pop: Array = []
		for e in range(mini(elitism, pop_size)):
			new_pop.append((pop[order[e]] as PackedFloat64Array).duplicate())
		while new_pop.size() < pop_size:
			var p1 := _tournament(pop, fits)
			var p2 := _tournament(pop, fits)
			new_pop.append(_mutate(_crossover(p1, p2)))
		pop = new_pop

		for i in range(pop_size):
			fits[i] = await _eval_vec(pop[i])
			_track(pop[i], fits[i])
		trace.append({"gen": gen, "best": best_fitness, "mean": _mean(fits)})
		print("[GA] gen %2d: best=%.3f mean=%.3f" % [gen + 1, best_fitness, _mean(fits)])

	return best_weights


# --- Operadores --------------------------------------------------------------

func _eval_vec(v: PackedFloat64Array) -> float:
	var wgt := HeuristicWeights.new()
	wgt.apply_vector(v, keys)
	return await fitness.evaluate(wgt)


func _track(v: PackedFloat64Array, f: float) -> void:
	if f > best_fitness:
		best_fitness = f
		best_weights = HeuristicWeights.new()
		best_weights.apply_vector(v, keys)


func _random_near(base_vec: PackedFloat64Array) -> PackedFloat64Array:
	var out := base_vec.duplicate()
	for i in range(out.size()):
		var b := HeuristicWeights.get_bounds(keys[i])
		out[i] = clampf(out[i] + rng.randfn(0.0, (b.y - b.x) * init_spread), b.x, b.y)
	return out


func _tournament(pop: Array, fits: Array) -> PackedFloat64Array:
	var best_i := rng.randi_range(0, pop.size() - 1)
	for _k in range(tournament_k - 1):
		var c := rng.randi_range(0, pop.size() - 1)
		if fits[c] > fits[best_i]:
			best_i = c
	return (pop[best_i] as PackedFloat64Array).duplicate()


func _crossover(a: PackedFloat64Array, b: PackedFloat64Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(a.size())
	for i in range(a.size()):
		var lo := minf(a[i], b[i])
		var hi := maxf(a[i], b[i])
		var d := hi - lo
		var val := rng.randf_range(lo - blx_alpha * d, hi + blx_alpha * d)
		var bnd := HeuristicWeights.get_bounds(keys[i])
		out[i] = clampf(val, bnd.x, bnd.y)
	return out


func _mutate(v: PackedFloat64Array) -> PackedFloat64Array:
	for i in range(v.size()):
		if rng.randf() < mutation_prob:
			var bnd := HeuristicWeights.get_bounds(keys[i])
			v[i] = clampf(v[i] + rng.randfn(0.0, (bnd.y - bnd.x) * mutation_frac), bnd.x, bnd.y)
	return v


# --- Utilidades --------------------------------------------------------------

func _mean(fits: Array) -> float:
	if fits.is_empty():
		return 0.0
	var s := 0.0
	for f in fits:
		s += float(f)
	return s / float(fits.size())


## Índices ordenados por fitness descendente.
func _argsort_desc(fits: Array) -> Array:
	var idx := range(fits.size())
	idx.sort_custom(func(a: int, b: int) -> bool: return fits[a] > fits[b])
	return idx
