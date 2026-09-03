extends RefCounted
class_name SAOptimizer

## Simulated Annealing sobre el vector de pesos de la heurística.
##
## Maximiza el win-rate (HeuristicFitness) explorando el espacio de búsqueda
## definido por HeuristicWeightsSpec.OPTIMIZABLE_KEYS (o una lista de claves
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
var space: SearchSpace                     ## espacio de búsqueda (comparte el rng)

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
		keys = HeuristicWeightsSpec.OPTIMIZABLE_KEYS
	space = SearchSpace.new(keys, rng)
	var cur := start.clone() if start != null else HeuristicWeights.new()
	# El punto de partida también se repara: el campeón vigente tiene el gradiente
	# de encierro invertido, y arrancar de ahí sin corregir arrastraría la
	# incoherencia a toda la corrida.
	var reparados := HeuristicWeightsSpec.repair(cur)
	if reparados > 0:
		print("[SA] punto de partida reparado: %d campos reordenados" % reparados)
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


## Genera un vecino perturbando `dims_per_step` dimensiones al azar (vía SearchSpace).
func _neighbor(base: HeuristicWeights) -> HeuristicWeights:
	var v := space.perturb_dims(space.vector_of(base), step_frac, dims_per_step)
	return space.apply(base, v)
