extends RefCounted
class_name HeuristicWeightsSpec

## Interfaz de OPTIMIZACIÓN de HeuristicWeights: qué campos forman el espacio de
## búsqueda, en qué rango se mueve cada uno y cómo se traduce un juego de pesos a
## vector y de vuelta.
##
## Las RESTRICCIONES que un candidato debe cumplir —y qué claves hay que mover
## juntas para poder alcanzarlas— viven en [HeuristicWeightsInvariants].
##
## La dependencia va en UN SOLO SENTIDO (Spec -> Weights) a propósito.
## HeuristicWeights es un Resource que se carga desde .tres; si además apuntase
## aquí, el ciclo rompería ese load() devolviendo null EN EJECUCIÓN, sin error de
## parseo. Por eso no hay métodos delegadores en HeuristicWeights.


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
