extends RefCounted
class_name AITerritory

## Factores territoriales de la heurística (expansión, encierro, carrera territorial),
## escritos UNA sola vez. Antes vivían DUPLICADOS en AIHeuristic
## (estado vivo) y AIRealEvalStrong (snapshot). Son funciones PURAS sobre primitivas +
## pesos: cada mundo cuenta sus tiles (propias / rival / colonizables) con su propia
## representación y pasa los escalares aquí, de modo que la fórmula y los umbrales
## viven en un único lugar y el optimizador (SA/GA) ajusta ambos mundos a la vez.
##
## Los recorridos del grafo de casillas SIN pesos (valor de frontera, conteo de
## colonizables) NO viven aquí, y no por olvido: no hay riesgo de divergencia con el
## optimizador porque no ponderan nada. Cada mundo hace el suyo en AILiveFacts y
## AISnapshotFacts, que es la mitad "cómo se lee este mundo".


## Presión expansionista [0.0, 1.0] por nº de tiles colonizables adyacentes.
## `colonizable` < 0 = desconocido (tests sin mapa) → expansion_unknown; 0 → 0.0;
## si no, satura al llegar a expansion_reference tiles libres.
static func expansion_factor(colonizable: int, w: HeuristicWeights) -> float:
	if colonizable < 0:
		return w.expansion_unknown
	if colonizable == 0:
		return 0.0
	return minf(float(colonizable) / w.expansion_reference, 1.0)


## Multiplicador del bonus de frontera según el grado de encierro. Ratio =
## colonizables / controladas (`controlled` ya viene ≥ 1). Ratio bajo → la IA se
## está quedando rodeada → escalar el incentivo de escapar.
static func encirclement_pressure(colonizable: int, controlled: int,
		w: HeuristicWeights) -> float:
	var ratio := float(colonizable) / float(controlled)
	if ratio >= w.encircle_r2: return w.encircle_high
	if ratio >= w.encircle_r1: return w.encircle_mid
	if ratio >= w.encircle_r05: return w.encircle_low
	return w.encircle_min


## Amplifica jugadas que acercan a la dominación (o bloquean al rival cerca de su
## límite de victoria). `mode` ∈ {colonize, open_front, economy}. Las cuotas se
## calculan sobre el total de tiles en disputa (propias + rival + colonizables).
static func territory_race_factor(my_tiles: int, rival_tiles: int, colonizable: int,
		mode: StringName, w: HeuristicWeights) -> float:
	var total := maxi(my_tiles + rival_tiles + colonizable, 1)
	var my_share := float(my_tiles) / float(total)
	var rival_share := float(rival_tiles) / float(total)

	if mode == &"colonize" or mode == &"open_front":
		if my_share >= w.tr_close_share:
			return w.tr_close_factor   # modo cierre: escalar todo lo que acerca al 70%
		if my_share >= w.tr_lead_share:
			return w.tr_lead_factor
		if rival_share >= w.tr_block_share:
			return w.tr_block_factor   # modo bloqueo: el rival se acerca a su victoria
	elif mode == &"economy":
		if my_share >= w.tr_close_share:
			return w.tr_econ_factor     # con ventaja territorial, la economía importa menos
	return 1.0
