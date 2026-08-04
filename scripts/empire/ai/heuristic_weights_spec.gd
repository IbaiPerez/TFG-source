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
	"tr_block_factor": {"opt": true}, "tr_econ_factor": {"opt": true, "unit": true},
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
	return errors


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
