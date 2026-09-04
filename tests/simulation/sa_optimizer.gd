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
var top_k: int = 5                ## cuántos finalistas devuelve (ver TopCandidates)

# --- Diagnóstico de aceptación ----------------------------------------------
# Sin esto, elegir `dims_per_step`, `t0` o `step_frac` es adivinar. Los cuatro
# contadores separan las cuatro cosas distintas que le pueden pasar a un vecino, y
# cada una apunta a un dial diferente:
#
#   mejora          la búsqueda avanza — lo que se quiere
#   neutro          MESETA: la perturbación no volteó NINGUNA decisión, así que el
#                   win-rate sale idéntico. Se acepta (delta >= 0) y la cadena se
#                   pasea sin aprender. Mucho neutro => perturbar más dimensiones,
#                   o subir las partidas por evaluación para afinar el fitness.
#   peor_aceptado   Metropolis dejando pasar un empeoramiento. Mucho => t0 alto
#                   para la granularidad real del fitness.
#   rechazado       la cadena se está congelando. Mucho, y pronto => enfriamiento
#                   demasiado rápido.
var n_mejora: int = 0
var n_neutro: int = 0
var n_peor_aceptado: int = 0
var n_rechazado: int = 0
var best_weights: HeuristicWeights
var best_fitness: float = -1.0
var top: TopCandidates            ## los `top_k` mejores distintos
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
	top = TopCandidates.new(top_k)
	var cur := start.clone() if start != null else HeuristicWeights.new()
	# El punto de partida también se repara: el campeón vigente tiene el gradiente
	# de encierro invertido, y arrancar de ahí sin corregir arrastraría la
	# incoherencia a toda la corrida.
	var reparados := HeuristicWeightsInvariants.repair(cur)
	if reparados > 0:
		print("[SA] punto de partida reparado: %d campos reordenados" % reparados)
	var cur_fit := await fitness.evaluate(cur)
	best_weights = cur.clone()
	best_fitness = cur_fit
	top.offer(cur, cur_fit, _clave(cur))
	print("[SA] inicio: fitness base = %.3f (%d dims)" % [cur_fit, keys.size()])

	var temp := t0
	for it in range(iterations):
		var cand := _neighbor(cur)
		var cand_fit := await fitness.evaluate(cand)
		var delta := cand_fit - cur_fit
		var accept := delta >= 0.0 or rng.randf() < exp(delta / maxf(temp, 0.0001))
		var clase := _clasificar(delta, accept)
		# El top-K se ofrece SIEMPRE, aceptado o no: un candidato rechazado por
		# Metropolis puede seguir siendo de los mejores vistos, y descartarlo por el
		# camino que tomó el recocido no tendría sentido.
		top.offer(cand, cand_fit, _clave(cand))
		if accept:
			cur = cand
			cur_fit = cand_fit
			if cand_fit > best_fitness:
				best_fitness = cand_fit
				best_weights = cand.clone()
		trace.append({"iter": it, "temp": temp, "cur_fit": cur_fit,
			"best_fit": best_fitness, "delta": delta, "clase": clase})
		print("[SA] it=%3d T=%.4f cur=%.3f best=%.3f%s" % [
			it, temp, cur_fit, best_fitness, "  *" if accept and cur_fit == best_fitness else ""])
		temp = maxf(temp * alpha, t_min)

	_print_diagnostico()
	return best_weights


## Clasifica el vecino y actualiza los contadores. `is_zero_approx` sobre el delta
## detecta la MESETA: el fitness es un win-rate sobre N partidas, así que si la
## perturbación no voltea ninguna decisión el valor sale exactamente igual.
func _clasificar(delta: float, accept: bool) -> String:
	if is_zero_approx(delta):
		n_neutro += 1
		return "neutro"
	if delta > 0.0:
		n_mejora += 1
		return "mejora"
	if accept:
		n_peor_aceptado += 1
		return "peor_aceptado"
	n_rechazado += 1
	return "rechazado"


func _print_diagnostico() -> void:
	var n := maxi(n_mejora + n_neutro + n_peor_aceptado + n_rechazado, 1)
	print("[SA] --- aceptación (%d vecinos, dims/paso=%d, t0=%.3f, step=%.3f) ---" % [
		n, dims_per_step, t0, step_frac])
	print("[SA]   mejora        %4d  %5.1f %%" % [n_mejora, 100.0 * n_mejora / n])
	print("[SA]   neutro/meseta %4d  %5.1f %%" % [n_neutro, 100.0 * n_neutro / n])
	print("[SA]   peor aceptado %4d  %5.1f %%" % [n_peor_aceptado, 100.0 * n_peor_aceptado / n])
	print("[SA]   rechazado     %4d  %5.1f %%" % [n_rechazado, 100.0 * n_rechazado / n])


## Resumen de la corrida, para comparar configuraciones de calibración.
func diagnostico() -> Dictionary:
	var n := maxi(n_mejora + n_neutro + n_peor_aceptado + n_rechazado, 1)
	return {
		"dims_per_step": dims_per_step, "t0": t0, "step_frac": step_frac,
		"iteraciones": n, "best_fitness": best_fitness,
		"mejora": n_mejora, "neutro": n_neutro,
		"peor_aceptado": n_peor_aceptado, "rechazado": n_rechazado,
		"pct_mejora": 100.0 * n_mejora / n,
		"pct_neutro": 100.0 * n_neutro / n,
		"pct_peor_aceptado": 100.0 * n_peor_aceptado / n,
		"pct_rechazado": 100.0 * n_rechazado / n,
	}


## Clave de deduplicación del top-K: el vector de pesos optimizables.
func _clave(w: HeuristicWeights) -> String:
	return str(HeuristicWeightsSpec.to_vector(w, keys))


## Genera un vecino perturbando `dims_per_step` dimensiones al azar (vía SearchSpace).
func _neighbor(base: HeuristicWeights) -> HeuristicWeights:
	var v := space.perturb_dims(space.vector_of(base), step_frac, dims_per_step)
	return space.apply(base, v)
