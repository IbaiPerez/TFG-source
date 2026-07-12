extends RefCounted
class_name SAOptimizer

## Simulated Annealing sobre el vector de pesos de la heurística.
##
## Maximiza el win-rate (HeuristicFitness) explorando el espacio de búsqueda
## definido por HeuristicWeights.OPTIMIZABLE_KEYS (o una lista de claves
## personalizada). El vecino perturba unas pocas dimensiones con ruido
## Gaussiano proporcional al rango de cada parámetro; la aceptación sigue el
## criterio de Metropolis con enfriamiento geométrico.
##
## Uso:
##   var sa := SAOptimizer.new(fitness, 4242)
##   sa.iterations = 200
##   var champ := await sa.run()          # mejor HeuristicWeights encontrado


var fitness: HeuristicFitness
var keys: PackedStringArray                ## claves a optimizar (default: OPTIMIZABLE_KEYS)
var rng := RandomNumberGenerator.new()

# --- Hiperparámetros ---------------------------------------------------------
var iterations: int = 200
var t0: float = 0.15              ## temperatura inicial (escala de win-rate)
var t_min: float = 0.005
var alpha: float = 0.97           ## factor de enfriamiento por iteración
var step_frac: float = 0.15       ## σ de perturbación como fracción del rango
var dims_per_step: int = 3        ## nº de dimensiones perturbadas por vecino

# --- Estado / traza ----------------------------------------------------------
var best_weights: HeuristicWeights
var best_fitness: float = -1.0
var trace: Array = []             ## [{iter, temp, cur_fit, best_fit}]


func _init(p_fitness: HeuristicFitness, p_seed: int = 12345) -> void:
	fitness = p_fitness
	rng.seed = p_seed


## Ejecuta el recocido y devuelve el mejor candidato. `start` = punto inicial
## (default: pesos por defecto).
func run(start: HeuristicWeights = null) -> HeuristicWeights:
	if keys.is_empty():
		keys = HeuristicWeights.OPTIMIZABLE_KEYS
	var cur := start.clone() if start != null else HeuristicWeights.new()
	var cur_fit := await fitness.evaluate(cur)
	best_weights = cur.clone()
	best_fitness = cur_fit
	print("[SA] inicio: fitness base = %.3f (%d dims)" % [cur_fit, keys.size()])

	var temp := t0
	for it in range(iterations):
		var cand := _neighbor(cur)
		var cand_fit := await fitness.evaluate(cand)
		var delta := cand_fit - cur_fit
		var accept := delta >= 0.0 or rng.randf() < exp(delta / maxf(temp, 0.0001))
		if accept:
			cur = cand
			cur_fit = cand_fit
			if cand_fit > best_fitness:
				best_fitness = cand_fit
				best_weights = cand.clone()
		trace.append({"iter": it, "temp": temp, "cur_fit": cur_fit, "best_fit": best_fitness})
		print("[SA] it=%3d T=%.4f cur=%.3f best=%.3f%s" % [
			it, temp, cur_fit, best_fitness, "  *" if accept and cur_fit == best_fitness else ""])
		temp = maxf(temp * alpha, t_min)

	return best_weights


## Genera un vecino perturbando `dims_per_step` dimensiones al azar.
func _neighbor(base: HeuristicWeights) -> HeuristicWeights:
	var cand := base.clone()
	var v := cand.to_vector(keys)
	for i in _pick_dims():
		var b := HeuristicWeights.get_bounds(keys[i])
		var sigma := (b.y - b.x) * step_frac
		v[i] = clampf(v[i] + rng.randfn(0.0, sigma), b.x, b.y)
	cand.apply_vector(v, keys)
	return cand


## Índices de dimensiones a perturbar (barajado Fisher-Yates parcial).
func _pick_dims() -> Array:
	var n := keys.size()
	var pool := range(n)
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, mini(dims_per_step, n))
