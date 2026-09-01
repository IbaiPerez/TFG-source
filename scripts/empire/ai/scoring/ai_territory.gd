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
## límite de victoria). `mode` ∈ {colonize, open_front}; cualquier otro es neutro.
##
## Las cuotas se normalizan contra el MAPA, que es la misma referencia que usa la
## condición de victoria (GameBalance.VICTORY_TILE_SHARE) y que AIGamePhase.
##
## Antes el denominador eran las casillas «en disputa» (propias + rival +
## COLONIZABLES adyacentes). Como los colonizables son siempre ≤ las libres del mapa,
## la cuota salía siempre inflada: no había falsos negativos, pero sí falsos
## positivos, y el más frecuente era el opuesto a lo que el factor dice medir —
## quedarse ENCAJONADO encogía el denominador y disparaba el «modo cierre». Dos
## imperios con 20 casillas propias y 10 rivales daban neutro o ×2.0 solo según
## tuvieran 25 o 3 libres alrededor. Y el encierro ya tiene su propio factor
## (encirclement_pressure), así que se contaba dos veces.
##
## `total_map_tiles <= 0` (tests sin mapa) → neutro: sin saber el tamaño no se puede
## juzgar la carrera, y no amplificar es lo seguro.
static func territory_race_factor(my_tiles: int, rival_tiles: int, total_map_tiles: int,
		mode: StringName, w: HeuristicWeights) -> float:
	if total_map_tiles <= 0:
		return 1.0
	if mode != &"colonize" and mode != &"open_front":
		return 1.0
	var my_share := float(my_tiles) / float(total_map_tiles)
	var rival_share := float(rival_tiles) / float(total_map_tiles)

	if my_share >= w.tr_close_share:
		return w.tr_close_factor   # modo cierre: cerca de la cuota de dominación
	if my_share >= w.tr_lead_share:
		return w.tr_lead_factor
	if rival_share >= w.tr_block_share:
		return w.tr_block_factor   # modo bloqueo: el rival se acerca a su victoria
	return 1.0
