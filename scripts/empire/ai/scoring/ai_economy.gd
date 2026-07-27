extends RefCounted
class_name AIEconomy

## Factores económicos de la heurística (excedente de recursos, coste de construcción),
## escritos UNA sola vez (refactor C4 §1.3.d). Antes vivían DUPLICADOS en AIHeuristic
## (estado vivo) y AIRealEvalStrong (snapshot). Son funciones PURAS sobre primitivas +
## pesos: cada mundo lee su comida/gpt/oro con su propia representación y pasa los
## escalares aquí, de modo que la fórmula y los umbrales viven en un único lugar y el
## optimizador (SA/GA) ajusta ambos mundos a la vez.


## Factor de excedente económico [1.0, surplus_max]. Cuando el oro por turno está muy
## por encima del umbral cómodo de la fase (y hay margen de comida), el coste de
## oportunidad de reclutar o abrir frentes es mínimo y esas acciones se potencian.
## Requiere food ≥ surplus_min_food: sin margen de comida no se sostienen tropas
## aunque el oro sobre.
static func resource_surplus_factor(food: int, gpt: int, phase: AIGamePhase.Phase,
		w: HeuristicWeights) -> float:
	if food < w.surplus_min_food:
		return 1.0
	var comfortable := w.surplus_comfortable_late
	match phase:
		AIGamePhase.Phase.EARLY: comfortable = w.surplus_comfortable_early
		AIGamePhase.Phase.MID:   comfortable = w.surplus_comfortable_mid
		_:                       comfortable = w.surplus_comfortable_late
	if gpt <= comfortable:
		return 1.0
	# 1.0 en el umbral → surplus_max cuando gpt duplica ese umbral.
	return lerpf(1.0, w.surplus_max, clampf(float(gpt - comfortable) / comfortable, 0.0, 1.0))


## Factor de coste: penaliza edificios que consumen una fracción alta del oro
## disponible. Rango build_cost_min (gasto total) → 1.0 (gasto residual).
static func build_cost_factor(cost: int, total_gold: int, w: HeuristicWeights) -> float:
	if total_gold <= 0:
		return w.build_cost_min
	return lerpf(1.0, w.build_cost_min, clampf(float(cost) / float(total_gold), 0.0, 1.0))
