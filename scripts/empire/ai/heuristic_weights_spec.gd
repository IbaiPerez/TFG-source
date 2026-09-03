extends RefCounted
class_name HeuristicWeightsSpec

## Interfaz de OPTIMIZACIÓN de HeuristicWeights: qué campos forman el espacio de
## búsqueda, en qué rango se mueve cada uno, qué invariantes deben cumplir y cómo
## se traduce un juego de pesos a vector y de vuelta.
##
## Vive aparte de HeuristicWeights porque son dos cosas distintas: allí está la
## TABLA DE VALORES que el juego lee en caliente; aquí, el conocimiento que solo
## necesitan SA/GA, que son herramientas de desarrollo.
##
## La dependencia va en UN SOLO SENTIDO (Spec → Weights) a propósito.
## HeuristicWeights es un Resource que se carga desde .tres; si además apuntase
## aquí, el ciclo rompería ese load() devolviendo null EN EJECUCIÓN, sin error de
## parseo. Por eso no hay métodos delegadores en HeuristicWeights.


## Tabla declarativa de metadatos por campo, fuente ÚNICA para el optimizador:
##   - "opt": true  → entra en el ESPACIO DE BÚSQUEDA por defecto (OPTIMIZABLE_KEYS).
##   - "unit": true → acotado a [0, 1] en get_bounds (probabilidades/ratios que la
##                    heurística ya clampa), en vez de la regla general [d*0.25, d*4].
## Un campo sin entrada aquí NO es optimizable por defecto y usa la regla general.
##
## Deliberadamente NO se marcan opt los umbrales de las curvas de urgencia
## (romperían su monotonía) ni los pesos de score_state (state_w_*/state_*_norm):
## score_state no se usa en modo HEURISTIC, así que optimizarlos aquí no tendría
## señal de fitness. Se listan (unit) por si se optimiza el mirror del MCTS.
## El optimizador puede optimizar cualquier campo pasando su propia lista de keys.
##
## El ORDEN de las entradas opt define el layout del vector (to_vector/apply_vector).
const SPEC := {
	# --- Optimizables (magnitudes/multiplicadores que influyen en modo HEURISTIC) ---
	# Urgencias
	"mil_urg_base_idle": {"opt": true}, "mil_urg_base_adjacent": {"opt": true},
	"mil_urg_base_active": {"opt": true}, "mil_urg_max": {"opt": true},
	# Factores
	"surplus_max": {"opt": true}, "build_cost_min": {"opt": true, "unit": true},
	"deck_thin_small": {"opt": true}, "deck_thin_large": {"opt": true},
	"purge_thresh_small": {"opt": true}, "purge_thresh_large": {"opt": true},
	"encircle_high": {"opt": true}, "encircle_mid": {"opt": true},
	"encircle_low": {"opt": true}, "encircle_min": {"opt": true},
	"tr_close_factor": {"opt": true}, "tr_lead_factor": {"opt": true},
	"tr_block_factor": {"opt": true},
	# tr_econ_factor NO entra: su rama (mode "economy") no tenía ningún llamante, así
	# que el fitness era PLANO en esa dirección y SA/GA solo hacía un paseo aleatorio
	# por ella —el campeón la dejó en 0.588 sin que eso cambiara una sola partida—.
	# Una dimensión inerte no es gratis: consume evaluaciones, que aquí son partidas.
	# Edificios
	"gold_weight_pos": {"opt": true}, "gold_weight_maint": {"opt": true},
	"food_weight": {"opt": true}, "defense_weight": {"opt": true},
	"build_resource_match": {"opt": true}, "build_border": {"opt": true},
	"unlock_gold": {"opt": true}, "unlock_food": {"opt": true},
	"unlock_defense": {"opt": true}, "unlock_cap": {"opt": true},
	# Reclutamiento
	"recruit_atkdef_weight": {"opt": true}, "recruit_cost_eff_base": {"opt": true},
	"counter_bonus": {"opt": true},
	# Frente
	"openfront_gold": {"opt": true}, "openfront_food": {"opt": true},
	"openfront_base_strategic": {"opt": true}, "openfront_base_mu": {"opt": true},
	"openfront_source_building": {"opt": true}, "openfront_source_gold": {"opt": true},
	"openfront_source_food": {"opt": true},
	# Cartas varias
	"tactic_base": {"opt": true}, "tactic_urgency_scale": {"opt": true},
	"draw_weight": {"opt": true},
	"colonize_gold": {"opt": true}, "colonize_food": {"opt": true},
	"colonize_expansion": {"opt": true}, "colonize_denial": {"opt": true},
	"changeloc_resource_bonus": {"opt": true}, "changeloc_slot": {"opt": true},
	"changeloc_consumption": {"opt": true},
	# Choice de eventos
	"choice_unlock": {"opt": true}, "choice_colonize": {"opt": true},
	"choice_modifier": {"opt": true},
	# Efectos de edificio
	"se_flat_gold": {"opt": true}, "se_flat_food": {"opt": true},
	"se_card_draw": {"opt": true}, "se_tpr_base": {"opt": true}, "se_tpr_mu": {"opt": true},
	# Va al FINAL de las entradas opt a propósito: el orden de declaración define el
	# layout del vector, así que añadir aquí conserva los índices de todas las demás
	# y el .tres del campeón sigue siendo válido (serializa por nombre, no por
	# posición). Insertarla en su grupo temático habría desplazado 20 dimensiones.
	"build_cost_ref": {"opt": true}, "assign_power_weight": {"opt": true},
	# Fronteras de fase. Las cuotas van "unit" porque son fracciones del mapa: la
	# regla general [d*0.25, d*4] llevaría phase_late_share a 1.2, una cuota
	# inalcanzable que apagaría la rama entera. Los umbrales de gpt sí usan la regla
	# general. `validate` impide que EARLY y LATE se crucen.
	"phase_late_share": {"opt": true, "unit": true},
	"phase_early_share": {"opt": true, "unit": true},
	"phase_early_gpt": {"opt": true}, "phase_late_gpt": {"opt": true},
	# Umbrales que preguntan «¿va bien mi economía?». Estaban fuera del espacio y
	# repartidos por tres sitios que no se enteran unos de otros, con lo que el
	# desfase de escala que arrastraban —calibrados para una economía que el juego
	# ya no tiene— no había forma de corregirlo. Van en los bloques econ_scale /
	# econ_scale_food, así que el optimizador los desplaza en conjunto.
	"surplus_comfortable_early": {"opt": true}, "surplus_comfortable_mid": {"opt": true},
	"surplus_comfortable_late": {"opt": true},
	"openfront_econ_early_gpt": {"opt": true}, "openfront_econ_mid_gpt": {"opt": true},
	"openfront_econ_late_gpt": {"opt": true},
	"surplus_min_food": {"opt": true},
	"openfront_econ_early_food": {"opt": true}, "openfront_econ_mid_food": {"opt": true},
	"openfront_econ_late_food": {"opt": true},
	# Las curvas de urgencia completas -- umbrales Y valores. Eran el 0 % del espacio
	# pese a decidir qué mira la IA en cada tramo de partida: la única curva
	# optimizable era la militar. Los umbrales van con guarda de reparación (arriba);
	# los valores no la necesitan, el código no exige que decrezcan.
	"gold_urg_early_t0": {"opt": true}, "gold_urg_early_t1": {"opt": true},
	"gold_urg_early_t2": {"opt": true},
	"gold_urg_early_v0": {"opt": true}, "gold_urg_early_v1": {"opt": true},
	"gold_urg_early_v2": {"opt": true}, "gold_urg_early_v3": {"opt": true},
	"gold_urg_mid_t0": {"opt": true}, "gold_urg_mid_t1": {"opt": true},
	"gold_urg_mid_t2": {"opt": true}, "gold_urg_mid_t3": {"opt": true},
	"gold_urg_mid_v0": {"opt": true}, "gold_urg_mid_v1": {"opt": true},
	"gold_urg_mid_v2": {"opt": true}, "gold_urg_mid_v3": {"opt": true},
	"gold_urg_mid_v4": {"opt": true},
	"gold_urg_late_t0": {"opt": true, "hi": 50.0}, "gold_urg_late_t1": {"opt": true},
	"gold_urg_late_t2": {"opt": true}, "gold_urg_late_t3": {"opt": true},
	"gold_urg_late_t4": {"opt": true}, "gold_urg_late_t5": {"opt": true},
	"gold_urg_late_t6": {"opt": true},
	"gold_urg_late_v0": {"opt": true}, "gold_urg_late_v1": {"opt": true},
	"gold_urg_late_v2": {"opt": true}, "gold_urg_late_v3": {"opt": true},
	"gold_urg_late_v4": {"opt": true}, "gold_urg_late_v5": {"opt": true},
	"gold_urg_late_v6": {"opt": true}, "gold_urg_late_v7": {"opt": true},
	"food_urg_early_t0": {"opt": true, "hi": 2.0}, "food_urg_early_t1": {"opt": true},
	"food_urg_early_t2": {"opt": true},
	"food_urg_early_v0": {"opt": true}, "food_urg_early_v1": {"opt": true},
	"food_urg_early_v2": {"opt": true}, "food_urg_early_v3": {"opt": true},
	"food_urg_mid_t0": {"opt": true, "hi": 5.0}, "food_urg_mid_t1": {"opt": true},
	"food_urg_mid_t2": {"opt": true},
	"food_urg_mid_v0": {"opt": true}, "food_urg_mid_v1": {"opt": true},
	"food_urg_mid_v2": {"opt": true}, "food_urg_mid_v3": {"opt": true},
	"food_urg_late_t0": {"opt": true, "hi": 5.0}, "food_urg_late_t1": {"opt": true},
	"food_urg_late_t2": {"opt": true},
	"food_urg_late_v0": {"opt": true}, "food_urg_late_v1": {"opt": true},
	"food_urg_late_v2": {"opt": true}, "food_urg_late_v3": {"opt": true},
	"deck_urg_t0": {"opt": true}, "deck_urg_t1": {"opt": true},
	"deck_urg_v0": {"opt": true}, "deck_urg_v1": {"opt": true}, "deck_urg_v2": {"opt": true},
	# Banda de mazo: el eje (bloque deck_axis, arriba) y el umbral de tienda que
	# faltaba -- deck_thin_*/purge_thresh_* ya entraban, shop_thresh_* no, sin que
	# hubiera un motivo: comparten exactamente la misma forma (lerp sobre el eje).
	"deck_small": {"opt": true}, "deck_large": {"opt": true},
	"shop_thresh_small": {"opt": true}, "shop_thresh_large": {"opt": true},
	# --- No optimizables por defecto pero acotados a [0,1] (pesos de score_state) ---
	"state_w_t_early": {"unit": true}, "state_w_e_early": {"unit": true},
	"state_w_m_early": {"unit": true}, "state_w_k_early": {"unit": true},
	"state_w_t_mid": {"unit": true}, "state_w_e_mid": {"unit": true},
	"state_w_m_mid": {"unit": true}, "state_w_k_mid": {"unit": true},
	"state_w_t_late": {"unit": true}, "state_w_e_late": {"unit": true},
	"state_w_m_late": {"unit": true}, "state_w_k_late": {"unit": true},
	"state_t_share_mix": {"unit": true},
}



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
static func repair(w: HeuristicWeights) -> int:
	var tocados := 0
	# Curvas de urgencia: MISMOS umbrales que comprueba `validate()` (los tramos se
	# leen de arriba abajo, y cruzarlos deja tramos inalcanzables). Antes `validate`
	# los vigilaba pero nada los corregía —no estaba conectada al bucle del
	# optimizador— y no eran optimizables; ahora las dos cosas son ciertas, así que
	# un candidato que las cruce se repara aquí, no se descarta.
	tocados += _sort_ascending(w, ["gold_urg_early_t0", "gold_urg_early_t1", "gold_urg_early_t2"])
	tocados += _sort_ascending(w, ["gold_urg_mid_t0", "gold_urg_mid_t1", "gold_urg_mid_t2",
		"gold_urg_mid_t3"])
	tocados += _sort_ascending(w, ["gold_urg_late_t0", "gold_urg_late_t1", "gold_urg_late_t2",
		"gold_urg_late_t3", "gold_urg_late_t4", "gold_urg_late_t5", "gold_urg_late_t6"])
	tocados += _sort_ascending(w, ["food_urg_early_t0", "food_urg_early_t1", "food_urg_early_t2"])
	tocados += _sort_ascending(w, ["food_urg_mid_t0", "food_urg_mid_t1", "food_urg_mid_t2"])
	tocados += _sort_ascending(w, ["food_urg_late_t0", "food_urg_late_t1", "food_urg_late_t2"])
	tocados += _sort_ascending(w, ["deck_urg_t0", "deck_urg_t1"])
	# Encierro: umbrales decrecientes, valores crecientes. El gradiente «cuanto más
	# rodeado, más incentivo a escapar» es intencional y hasta ahora no lo protegía
	# nada — el campeón lo invirtió.
	tocados += _sort_descending(w, ["encircle_r2", "encircle_r1", "encircle_r05"])
	tocados += _sort_ascending(w, ["encircle_high", "encircle_mid", "encircle_low",
		"encircle_min"])
	# Complementariedad: el if/elif exige hi > mid > lomid > lo en el eje del pool y
	# lo < mid < hi en el de la tropa; si se cruzan, hay ramas que no alcanza nadie.
	tocados += _sort_descending(w, ["complement_pool_hi", "complement_pool_mid",
		"complement_pool_lomid", "complement_pool_lo"])
	tocados += _sort_ascending(w, ["complement_troop_lo", "complement_troop_mid",
		"complement_troop_hi"])
	tocados += _repair_phase_order(w)
	tocados += _repair_deck_axis(w)
	return tocados


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
	if w.deck_large - w.deck_small >= 0.5:
		return 0
	var centro := (w.deck_small + w.deck_large) / 2.0
	w.deck_small = centro - 0.25
	w.deck_large = centro + 0.25
	return 1


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


## Espacio de búsqueda por defecto de SA/GA: las claves con opt:true en SPEC, en su
## orden de declaración (define el layout del vector).
static var OPTIMIZABLE_KEYS: PackedStringArray = _compute_optimizable_keys()

static func _compute_optimizable_keys() -> PackedStringArray:
	var out := PackedStringArray()
	for k in SPEC:
		if SPEC[k].get("opt", false):
			out.append(k)
	return out


## Rango [min, max] de búsqueda de un campo. Los marcados "unit" en SPEC viven en
## [0, 1]; el resto usa la regla general multiplicativa [d*0.25, d*4] (o [0,1] si
## el default es 0).
static func get_bounds(key: String) -> Vector2:
	if SPEC.has(key) and SPEC[key].get("unit", false):
		return Vector2(0.0, 1.0)
	# Un puñado de umbrales del PRIMER tramo de una cadena valen 0 por diseño (el
	# tramo empieza en cero), y la regla general confundiría ese 0 con "esto es una
	# probabilidad" y lo encerraría en [0, 1] — cuando en realidad vive en la misma
	# escala que sus hermanos de cadena (hasta 2000 en gold_urg_late). "hi" fija el
	# techo explícitamente para esos campos; el suelo se queda en 0, que sí es
	# correcto: el tramo no puede empezar en negativo.
	if SPEC.has(key) and SPEC[key].has("hi"):
		return Vector2(0.0, float(SPEC[key]["hi"]))
	var d := float(HeuristicWeights.get_default().get(key))
	if d == 0.0:
		return Vector2(0.0, 1.0)
	var lo := d * 0.25
	var hi := d * 4.0
	return Vector2(minf(lo, hi), maxf(lo, hi))


## Valida los invariantes de los pesos. Devuelve una lista de problemas (vacía =
## OK). Comprueba la monotonía de las curvas de urgencia (umbrales no decrecientes)
## y que los pesos de mezcla queden en [0,1]. El optimizador la llama antes de
## evaluar un candidato para descartar configuraciones incoherentes.
static func validate(w: HeuristicWeights) -> Array[String]:
	var errors: Array[String] = []
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
	if w.state_t_share_mix < 0.0 or w.state_t_share_mix > 1.0:
		errors.append("state_t_share_mix fuera de [0,1]: %.3f" % w.state_t_share_mix)
	_require_phase_order(errors, w)
	return errors


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


static func _require_non_decreasing(errors: Array[String], label: String, values: Array) -> void:
	for i in range(1, values.size()):
		if float(values[i]) < float(values[i - 1]):
			errors.append("%s: umbral no creciente en índice %d (%.2f < %.2f)" % [
				label, i, values[i], values[i - 1]])


## Serializa los campos indicados (o OPTIMIZABLE_KEYS por defecto) a un vector.
static func to_vector(w: HeuristicWeights,
		keys: PackedStringArray = []) -> PackedFloat64Array:
	var k := keys if not keys.is_empty() else OPTIMIZABLE_KEYS
	var out := PackedFloat64Array()
	out.resize(k.size())
	for i in range(k.size()):
		out[i] = float(w.get(k[i]))
	return out


## Aplica un vector a los campos indicados (o OPTIMIZABLE_KEYS por defecto).
static func apply_vector(w: HeuristicWeights, v: PackedFloat64Array,
		keys: PackedStringArray = []) -> void:
	var k := keys if not keys.is_empty() else OPTIMIZABLE_KEYS
	var n := mini(v.size(), k.size())
	for i in range(n):
		w.set(k[i], v[i])
