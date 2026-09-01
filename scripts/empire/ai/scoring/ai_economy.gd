extends RefCounted
class_name AIEconomy

## Factores económicos de la heurística (excedente de recursos, coste de construcción),
## escritos UNA sola vez. Antes vivían DUPLICADOS en AIHeuristic
## (estado vivo) y AIRealEvalStrong (snapshot). Son funciones PURAS sobre primitivas +
## pesos: cada mundo lee su comida/gpt/oro con su propia representación y pasa los
## escalares aquí, de modo que la fórmula y los umbrales viven en un único lugar y el
## optimizador (SA/GA) ajusta ambos mundos a la vez.


## Factor de excedente económico [1.0, surplus_max]. Cuando el oro por turno y la
## comida están muy por encima de sus umbrales, el coste de oportunidad de reclutar
## o abrir frentes es mínimo y esas acciones se potencian.
##
## Los DOS ejes siguen la misma regla: neutro en el umbral, pleno al duplicarlo. El
## de comida era antes un acantilado binario —por debajo de `surplus_min_food` daba
## 1.0 y justo en él saltaba a `surplus_max`—, así que un único punto de comida
## triplicaba de golpe el score entero de reclutar y de abrir frente, que son sus dos
## consumidores. Tener el margen JUSTO no concede amplificación; hay que doblarlo.
##
## Se multiplican en vez de tomar el mínimo: hacen falta las dos holguras a la vez,
## y sin margen de comida no se sostienen tropas por mucho oro que sobre.
static func resource_surplus_factor(food: int, gpt: int, phase: AIGamePhase.Phase,
		w: HeuristicWeights) -> float:
	var comfortable := w.surplus_comfortable_late
	match phase:
		AIGamePhase.Phase.EARLY: comfortable = w.surplus_comfortable_early
		AIGamePhase.Phase.MID:   comfortable = w.surplus_comfortable_mid
		_:                       comfortable = w.surplus_comfortable_late
	if gpt <= comfortable:
		return 1.0
	var gold_ratio := clampf(float(gpt - comfortable) / comfortable, 0.0, 1.0)
	# maxf protege la división si un .tres pone el umbral a 0 (= sin exigencia de
	# comida): el ratio satura a 1.0 en vez de dar inf/nan.
	var min_food := maxf(w.surplus_min_food, 0.001)
	var food_ratio := clampf((float(food) - w.surplus_min_food) / min_food, 0.0, 1.0)
	return lerpf(1.0, w.surplus_max, gold_ratio * food_ratio)


## Factor de coste-eficiencia [build_cost_min, 1.0]: cuánto cuesta el edificio por
## unidad de valor que aporta, comparado con `build_cost_ref`.
##
## Antes comparaba el coste contra el ORO EN CAJA, con dos problemas medidos: (1) el
## mismo edificio valía distinto según el saldo, así que el orden entre edificios se
## movía con el dinero sin que ninguno hubiera cambiado; y (2) discriminaba muy poco
## —con 300 o con 1500 de oro el ranking del catálogo era casi idéntico—, porque la
## banda solo reescala. La asequibilidad DURA no se pierde: AILegality.build_targets
## descarta `coste > oro` antes de que esto se ejecute.
##
## Acoplamiento consciente: `value` ya viene ponderado por las urgencias, así que un
## edificio se considera menos eficiente cuando lo que produce importa poco. Es
## deseable: pagar 400 por oro que no necesitas es peor negocio.
static func build_cost_factor(cost: int, value: float, w: HeuristicWeights) -> float:
	if cost <= 0:
		return 1.0
	var magnitude := absf(value)
	if magnitude <= 0.0:
		return w.build_cost_min
	var ref := maxf(w.build_cost_ref, 0.001)
	return lerpf(1.0, w.build_cost_min,
		clampf((float(cost) / magnitude) / ref, 0.0, 1.0))


## Aplica el factor de coste conservando el SENTIDO de la penalización en los dos
## signos: encoge la magnitud de lo bueno y agranda la de lo malo.
##
## Multiplicar en ambos casos era el defecto: un factor en (0,1) sobre un valor
## negativo lo acerca a cero, de modo que encarecer un edificio perjudicial subía su
## score. El signo nunca cambia —no puede volver jugable a lo que no lo es—, pero el
## orden entre edificios malos sí quedaba invertido.
static func apply_build_cost(value: float, cost: int, w: HeuristicWeights) -> float:
	var factor := maxf(build_cost_factor(cost, value, w), 0.001)
	return value * factor if value >= 0.0 else value / factor
