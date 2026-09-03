extends RefCounted
class_name HeuristicWeightsInvariants

## Qué hace COHERENTE a un juego de pesos, y cómo mantenerlo así durante la búsqueda.
##
## Aparte de [HeuristicWeightsSpec], que es el ENCODING (qué se busca, en qué rango,
## cómo se traduce a vector). Aquí viven las RESTRICCIONES y las claves acopladas:
## `repair` proyecta un candidato sobre la región coherente y `validate` es el juez
## que comprueba que lo está.
##
## Dependencia en un solo sentido (-> Weights), igual que Spec: un ciclo rompería
## el load() del .tres devolviendo null EN EJECUCIÓN, sin error de parseo.


# ---------------------------------------------------------------------------
# Parámetros que hay que mover JUNTOS
# ---------------------------------------------------------------------------

## Grupos de claves acopladas: mover una sola no dice nada, o dice algo incoherente.
##
## El optimizador trata cada dimensión por separado, y eso falla en tres formas
## distintas que este proyecto ya ha sufrido:
##
##  · SUSTITUTOS. Las dos condiciones de LATE van unidas por un `or`, así que subir
##    una deja que la otra siga saltando. Medido: subir solo la cuota mueve el
##    reparto de fases 17 puntos, subir solo el gpt lo mueve 2.6, y subir las dos
##    lo mueve 49. SA perturba 3 dimensiones de más de 60: la probabilidad de que
##    toque justo ese par es del orden del 0.1 % por paso — nunca lo explora.
##
##  · CADENAS ORDENADAS. `encirclement_pressure` es un if/elif con umbrales
##    decrecientes y valores crecientes. El campeón vigente ROMPIÓ ese gradiente
##    —dejó `encircle_min` en 2.57, por debajo de `encircle_low` 6.17— porque nada
##    se lo impedía. No es una hipótesis: está en el .tres.
##
##  · RAMAS INALCANZABLES. En `complement_bonus`, mover un umbral de la cadena
##    puede dejar una rama sin ningún estado que la active. Una dimensión muerta
##    silenciosa, como la que ya costó descubrir en `tr_econ_factor`.
##
## Un bloque se perturba con un factor COMÚN: conserva la forma interna del grupo y
## desplaza el conjunto, que es el movimiento que la búsqueda por coordenadas no
## puede hacer. La forma sigue siendo explorable porque las dimensiones también se
## perturban sueltas.
const BLOCKS := {
	# Las dos condiciones de LATE, y las dos de EARLY.
	"phase_late": ["phase_late_share", "phase_late_gpt"],
	"phase_early": ["phase_early_share", "phase_early_gpt"],
	# Los umbrales de encierro y sus valores son dos escalas distintas: los primeros
	# son ratios colonizables/controladas y los segundos multiplicadores de score.
	"encircle_thresholds": ["encircle_r2", "encircle_r1", "encircle_r05"],
	"encircle_values": ["encircle_high", "encircle_mid", "encircle_low", "encircle_min"],
	# Las dos cadenas de complementariedad, una por eje.
	"complement_pool": ["complement_pool_hi", "complement_pool_mid",
		"complement_pool_lomid", "complement_pool_lo"],
	"complement_troop": ["complement_troop_lo", "complement_troop_mid",
		"complement_troop_hi"],
	# Todo lo que pregunta «¿va bien mi economía?» en unidades de gpt, repartido hoy
	# por tres sitios que no se enteran unos de otros. El desfase que encontramos
	# —umbrales calibrados para una economía que el juego ya no tiene— es de ESCALA,
	# así que un factor común lo corrige de una vez. NO se les impone orden: que
	# `openfront_econ_late_gpt` sea menor que el de MID es intencional (en late game
	# el frente es el camino a la victoria y merece más tolerancia).
	"econ_scale": ["surplus_comfortable_early", "surplus_comfortable_mid",
		"surplus_comfortable_late", "openfront_econ_early_gpt",
		"openfront_econ_mid_gpt", "openfront_econ_late_gpt"],
	# El mismo argumento en la otra unidad. La comida tiene su propia escala y va
	# por su cuenta: los ingresos de oro se disparan durante la partida y los de
	# comida se quedan en las decenas, así que mezclarlas en un bloque las ataría
	# a un factor común que no comparten.
	"econ_scale_food": ["surplus_min_food", "openfront_econ_early_food",
		"openfront_econ_mid_food", "openfront_econ_late_food"],

	# Las CADENAS de umbral de las curvas de urgencia. `gold_urgency`/`food_urgency`
	# son un `if x < t0: ... if x < t1: ...` leído de arriba abajo (ver ai_urgency.gd):
	# si los umbrales se cruzan, un tramo intermedio deja de tener ningún estado que
	# lo alcance — el mismo riesgo de rama inalcanzable que en `complement_bonus`,
	# pero aquí eran justo los campos que el usuario pidió abrir primero.
	"gold_urg_early_thresholds": ["gold_urg_early_t0", "gold_urg_early_t1", "gold_urg_early_t2"],
	"gold_urg_mid_thresholds": ["gold_urg_mid_t0", "gold_urg_mid_t1",
		"gold_urg_mid_t2", "gold_urg_mid_t3"],
	"gold_urg_late_thresholds": ["gold_urg_late_t0", "gold_urg_late_t1", "gold_urg_late_t2",
		"gold_urg_late_t3", "gold_urg_late_t4", "gold_urg_late_t5", "gold_urg_late_t6"],
	"food_urg_early_thresholds": ["food_urg_early_t0", "food_urg_early_t1", "food_urg_early_t2"],
	"food_urg_mid_thresholds": ["food_urg_mid_t0", "food_urg_mid_t1", "food_urg_mid_t2"],
	"food_urg_late_thresholds": ["food_urg_late_t0", "food_urg_late_t1", "food_urg_late_t2"],
	"deck_urg_thresholds": ["deck_urg_t0", "deck_urg_t1"],

	# El eje del mazo. `deck_small`/`deck_large` no son "sustitutos" ni una cadena de
	# umbrales de lectura secuencial: son los DOS EXTREMOS de la misma regla de tres
	# (`_deck_ratio`), y si se cruzan o se igualan el denominador se anula —división
	# por cero, NaN silencioso que se propagaría a las tres interpolaciones que
	# comparten el eje (compra en tienda, purga, adelgazamiento de mazo).
	"deck_axis": ["deck_small", "deck_large"],
}


## Bloque al que pertenece `key`, o "" si no está en ninguno. Índice inverso
## construido una vez.
static var _block_of: Dictionary = _compute_block_of()

static func _compute_block_of() -> Dictionary:
	var out := {}
	for nombre in BLOCKS:
		for k in BLOCKS[nombre]:
			out[k] = nombre
	return out


static func block_of(key: String) -> String:
	return _block_of.get(key, "")


## Claves del bloque de `key`, o solo `key` si no está en ninguno.
static func block_peers(key: String) -> PackedStringArray:
	var nombre := block_of(key)
	if nombre == "":
		return PackedStringArray([key])
	return PackedStringArray(BLOCKS[nombre])


# ---------------------------------------------------------------------------
# Reparación de invariantes
# ---------------------------------------------------------------------------

## Proyecta `w` sobre la región COHERENTE, ordenando las cadenas que tienen que ir
## ordenadas. Muta `w` y devuelve cuántos campos tocó.
##
## Reparar en vez de rechazar es deliberado: rechazar tira una partida entera de
## cómputo por un candidato que estaba a un `swap` de ser válido, y con muestreo por
## rechazo en 25 umbrales la tasa de descarte sería ruinosa. Proyectar conserva la
## dirección de la mutación y solo corrige el orden.
##
## Después de `repair`, `validate` debe devolver vacío. Hay un test que lo exige
## sobre candidatos generados al azar.
## Hueco mínimo del eje del mazo. Pegados, `_deck_ratio` divide por ~0 y la banda
## colapsa en escalón: `lerp` deja de interpolar. Exactamente iguales y con un mazo
## de ese mismo tamaño es 0/0 → NaN (comprobado: `clampf(NAN)` devuelve NAN), que
## se propaga a las tres interpolaciones que comparten el eje.
const DECK_AXIS_MIN_GAP: float = 0.5


static func repair(w: HeuristicWeights) -> int:
	var n := 0
	n += _repair_urgency_chains(w)
	n += _repair_encircle(w)
	n += _repair_complement(w)
	n += _repair_phase_order(w)
	n += _repair_deck_axis(w)
	return n


## Umbrales de las curvas de urgencia, no decrecientes: los tramos se leen de
## arriba abajo y cruzarlos deja tramos inalcanzables.
static func _repair_urgency_chains(w: HeuristicWeights) -> int:
	var n := 0
	n += _sort_ascending(w, ["gold_urg_early_t0", "gold_urg_early_t1", "gold_urg_early_t2"])
	n += _sort_ascending(w, ["gold_urg_mid_t0", "gold_urg_mid_t1", "gold_urg_mid_t2",
		"gold_urg_mid_t3"])
	n += _sort_ascending(w, ["gold_urg_late_t0", "gold_urg_late_t1", "gold_urg_late_t2",
		"gold_urg_late_t3", "gold_urg_late_t4", "gold_urg_late_t5", "gold_urg_late_t6"])
	n += _sort_ascending(w, ["food_urg_early_t0", "food_urg_early_t1", "food_urg_early_t2"])
	n += _sort_ascending(w, ["food_urg_mid_t0", "food_urg_mid_t1", "food_urg_mid_t2"])
	n += _sort_ascending(w, ["food_urg_late_t0", "food_urg_late_t1", "food_urg_late_t2"])
	n += _sort_ascending(w, ["deck_urg_t0", "deck_urg_t1"])
	return n


## Encierro: ratios decrecientes, valores crecientes. El gradiente «cuanto más
## rodeado, más incentivo a escapar» es intencional, y el campeón lo invirtió.
static func _repair_encircle(w: HeuristicWeights) -> int:
	return _sort_descending(w, ["encircle_r2", "encircle_r1", "encircle_r05"]) \
		+ _sort_ascending(w, ["encircle_high", "encircle_mid", "encircle_low",
			"encircle_min"])


## Complementariedad. La razón es más fina de lo que parece: cruzar UNA cadena no
## deja ninguna rama inalcanzable —comprobado—, porque cada rama se alcanza también
## por el otro eje; solo mueren si se cruzan las dos a la vez. Lo que sí se rompe
## siempre es la SEMÁNTICA: el tramo estricto dejaría de dar el bonus mayor.
##
## Son dos PARES por eje, no una cadena de cuatro: `hi`/`mid` son umbrales por
## arriba (`ratio > x`) y `lomid`/`lo` por abajo (`ratio < x`), así que `mid` por
## debajo de `lomid` es legítimo y ordenar los cuatro juntos recortaría el espacio
## de búsqueda sin motivo.
static func _repair_complement(w: HeuristicWeights) -> int:
	return _sort_descending(w, ["complement_pool_hi", "complement_pool_mid"]) \
		+ _sort_descending(w, ["complement_pool_lomid", "complement_pool_lo"]) \
		+ _sort_ascending(w, ["complement_troop_lo", "complement_troop_mid",
			"complement_troop_hi"])


## Ordena los valores de `keys` de menor a mayor conservando el CONJUNTO. Devuelve
## cuántas posiciones cambiaron.
static func _sort_ascending(w: HeuristicWeights, keys: Array) -> int:
	var vals: Array = []
	for k in keys:
		vals.append(float(w.get(k)))
	var ordenados := vals.duplicate()
	ordenados.sort()
	return _write_back(w, keys, vals, ordenados)


static func _sort_descending(w: HeuristicWeights, keys: Array) -> int:
	var vals: Array = []
	for k in keys:
		vals.append(float(w.get(k)))
	var ordenados := vals.duplicate()
	ordenados.sort()
	ordenados.reverse()
	return _write_back(w, keys, vals, ordenados)


static func _write_back(w: HeuristicWeights, keys: Array, antes: Array,
		despues: Array) -> int:
	var n := 0
	for i in range(keys.size()):
		if not is_equal_approx(float(antes[i]), float(despues[i])):
			w.set(keys[i], despues[i])
			n += 1
	return n


## El eje del mazo pide orden ESTRICTO y un hueco mínimo: igualados, `_deck_ratio`
## divide por cero (NaN silencioso que se propaga a las tres interpolaciones que
## comparten el eje). El hueco es pequeño a propósito — solo evita el cero exacto,
## no acota la escala del eje, que es justo lo que el optimizador debe poder mover.
static func _repair_deck_axis(w: HeuristicWeights) -> int:
	# Primero ORDENAR conservando el conjunto, igual que las cadenas: un eje
	# invertido (20, 5) tiene que quedar en (5, 20), no colapsar a su centro.
	var n := _sort_ascending(w, ["deck_small", "deck_large"])
	# Y solo si tras ordenar el hueco sigue siendo demasiado pequeño, separarlos.
	# Aquí sí hay que inventar: los dos valores son casi el mismo y el conjunto
	# original no contiene ninguna banda que preservar.
	if w.deck_large - w.deck_small < DECK_AXIS_MIN_GAP:
		var centro := (w.deck_small + w.deck_large) / 2.0
		w.deck_small = centro - DECK_AXIS_MIN_GAP / 2.0
		w.deck_large = centro + DECK_AXIS_MIN_GAP / 2.0
		n += 1
	return n


## Las fronteras de fase piden orden ESTRICTO, no solo no decreciente: iguales, la
## banda de en medio se queda sin ningún estado. Se separa el par un epsilon.
static func _repair_phase_order(w: HeuristicWeights) -> int:
	var n := 0
	if w.phase_early_share >= w.phase_late_share:
		var lo := minf(w.phase_early_share, w.phase_late_share)
		var hi := maxf(w.phase_early_share, w.phase_late_share)
		w.phase_early_share = minf(lo, hi - 0.01)
		w.phase_late_share = hi
		n += 1
	if w.phase_early_gpt >= w.phase_late_gpt:
		var lo2 := minf(w.phase_early_gpt, w.phase_late_gpt)
		var hi2 := maxf(w.phase_early_gpt, w.phase_late_gpt)
		w.phase_early_gpt = minf(lo2, hi2 - 1.0)
		w.phase_late_gpt = hi2
		n += 1
	return n


## Valida los invariantes de los pesos. Devuelve una lista de problemas (vacía =
## OK). Comprueba la monotonía de las curvas de urgencia (umbrales no decrecientes)
## y que los pesos de mezcla queden en [0,1]. El optimizador la llama antes de
## evaluar un candidato para descartar configuraciones incoherentes.
static func validate(w: HeuristicWeights) -> Array[String]:
	var errors: Array[String] = []
	_validate_urgency_chains(errors, w)
	_validate_chains(errors, w)
	if w.state_t_share_mix < 0.0 or w.state_t_share_mix > 1.0:
		errors.append("state_t_share_mix fuera de [0,1]: %.3f" % w.state_t_share_mix)
	_require_phase_order(errors, w)
	if w.deck_large - w.deck_small < DECK_AXIS_MIN_GAP:
		errors.append("eje del mazo sin banda: deck_large - deck_small = %.3f < %.3f" % [
			w.deck_large - w.deck_small, DECK_AXIS_MIN_GAP])
	return errors


static func _validate_urgency_chains(errors: Array[String], w: HeuristicWeights) -> void:
	_require_non_decreasing(errors, "gold_urg_early",
		[w.gold_urg_early_t0, w.gold_urg_early_t1, w.gold_urg_early_t2])
	_require_non_decreasing(errors, "gold_urg_mid",
		[w.gold_urg_mid_t0, w.gold_urg_mid_t1, w.gold_urg_mid_t2, w.gold_urg_mid_t3])
	_require_non_decreasing(errors, "gold_urg_late",
		[w.gold_urg_late_t0, w.gold_urg_late_t1, w.gold_urg_late_t2, w.gold_urg_late_t3,
		w.gold_urg_late_t4, w.gold_urg_late_t5, w.gold_urg_late_t6])
	_require_non_decreasing(errors, "food_urg_early",
		[w.food_urg_early_t0, w.food_urg_early_t1, w.food_urg_early_t2])
	_require_non_decreasing(errors, "food_urg_mid",
		[w.food_urg_mid_t0, w.food_urg_mid_t1, w.food_urg_mid_t2])
	_require_non_decreasing(errors, "food_urg_late",
		[w.food_urg_late_t0, w.food_urg_late_t1, w.food_urg_late_t2])
	_require_non_decreasing(errors, "deck_urg", [w.deck_urg_t0, w.deck_urg_t1])


## Lo mismo que reparan `_repair_encircle` / `_repair_complement`. Sin esto,
## `validate` daba por bueno un candidato con el gradiente de encierro invertido,
## la cadena de tropa cruzada y el eje del mazo del revés — los tres a la vez, 0
## errores— y el test de coherencia extremo a extremo no significaba nada.
static func _validate_chains(errors: Array[String], w: HeuristicWeights) -> void:
	_require_non_increasing(errors, "encircle_r",
		[w.encircle_r2, w.encircle_r1, w.encircle_r05])
	_require_non_decreasing(errors, "encircle_valores",
		[w.encircle_high, w.encircle_mid, w.encircle_low, w.encircle_min])
	_require_non_increasing(errors, "complement_pool_alto",
		[w.complement_pool_hi, w.complement_pool_mid])
	_require_non_increasing(errors, "complement_pool_bajo",
		[w.complement_pool_lomid, w.complement_pool_lo])
	_require_non_decreasing(errors, "complement_troop",
		[w.complement_troop_lo, w.complement_troop_mid, w.complement_troop_hi])


## Las fronteras de fase deben ir en orden ESTRICTO. Cruzadas, la detección sigue
## devolviendo una fase —no falla— pero deja de significar lo que dice: si el umbral
## EARLY supera al LATE, se entra en LATE antes de poder ser EARLY y MID se evapora.
## El optimizador mueve las cuatro de forma independiente, así que puede cruzarlas.
static func _require_phase_order(errors: Array[String], w: HeuristicWeights) -> void:
	if w.phase_early_share >= w.phase_late_share:
		errors.append("phase_early_share >= phase_late_share: %.3f >= %.3f" % [
			w.phase_early_share, w.phase_late_share])
	if w.phase_early_gpt >= w.phase_late_gpt:
		errors.append("phase_early_gpt >= phase_late_gpt: %.1f >= %.1f" % [
			w.phase_early_gpt, w.phase_late_gpt])


## Gemelo de `_require_non_decreasing` para las cadenas que se leen de mayor a
## menor (ratios de encierro, umbrales «por arriba» de complementariedad).
static func _require_non_increasing(errors: Array[String], label: String,
		values: Array) -> void:
	for i in range(1, values.size()):
		if float(values[i]) > float(values[i - 1]):
			errors.append("%s: no decreciente en índice %d (%.2f > %.2f)" % [
				label, i, values[i], values[i - 1]])


static func _require_non_decreasing(errors: Array[String], label: String, values: Array) -> void:
	for i in range(1, values.size()):
		if float(values[i]) < float(values[i - 1]):
			errors.append("%s: umbral no creciente en índice %d (%.2f < %.2f)" % [
				label, i, values[i], values[i - 1]])
