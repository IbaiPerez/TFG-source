extends Resource
class_name HeuristicWeights

## Pesos y umbrales de la heurística de decisión de la IA (AIHeuristic).
##
## Extrae a un Resource todos los números mágicos que controlan el scoring de
## AIHeuristic, para poder ajustarlos sin tocar código y para que un optimizador
## (Simulated Annealing / algoritmo genético) los pueda leer, mutar y guardar
## como .tres.
##
## Los valores por defecto reproducen EXACTAMENTE los literales que estaban
## hardcodeados en ai_heuristic.gd: con `HeuristicWeights.new()` (o el default
## cacheado) el comportamiento de la heurística es byte-idéntico al anterior.
##
## Inyección: AITurnContext.get_weights() devuelve los pesos activos (los de
## AIConfig.heuristic_weights si están asignados, o el default cacheado). Ver
## AIHeuristic para los puntos de uso.
##
## Interfaz para optimizadores:
##   - OPTIMIZABLE_KEYS: subconjunto curado de campos que forman el espacio de
##     búsqueda por defecto (multiplicadores y magnitudes; NO umbrales de curva).
##   - to_vector(keys) / apply_vector(v, keys): (des)serializan a PackedFloat64Array.
##   - get_bounds(key): rango [min, max] de búsqueda de un campo.
##   - clone(): copia profunda para candidatos.


# ---------------------------------------------------------------------------
# Urgencia de oro (AIUrgency.gold_urgency): umbrales de gpt (t*) y valores (v*) por fase.
# ---------------------------------------------------------------------------
@export_group("Urgencia oro")
@export var gold_urg_early_t0: float = 10.0
@export var gold_urg_early_t1: float = 30.0
@export var gold_urg_early_t2: float = 60.0
@export var gold_urg_early_v0: float = 3.0
@export var gold_urg_early_v1: float = 1.8
@export var gold_urg_early_v2: float = 1.0
@export var gold_urg_early_v3: float = 0.7

@export var gold_urg_mid_t0: float = 50.0
@export var gold_urg_mid_t1: float = 150.0
@export var gold_urg_mid_t2: float = 250.0
@export var gold_urg_mid_t3: float = 400.0
@export var gold_urg_mid_v0: float = 3.0
@export var gold_urg_mid_v1: float = 2.0
@export var gold_urg_mid_v2: float = 1.3
@export var gold_urg_mid_v3: float = 1.0
@export var gold_urg_mid_v4: float = 0.7

@export var gold_urg_late_t0: float = 0.0
@export var gold_urg_late_t1: float = 50.0
@export var gold_urg_late_t2: float = 100.0
@export var gold_urg_late_t3: float = 200.0
@export var gold_urg_late_t4: float = 500.0
@export var gold_urg_late_t5: float = 1000.0
@export var gold_urg_late_t6: float = 2000.0
@export var gold_urg_late_v0: float = 3.0
@export var gold_urg_late_v1: float = 2.0
@export var gold_urg_late_v2: float = 1.3
@export var gold_urg_late_v3: float = 1.0
@export var gold_urg_late_v4: float = 0.7
@export var gold_urg_late_v5: float = 0.5
@export var gold_urg_late_v6: float = 0.35
@export var gold_urg_late_v7: float = 0.35


# ---------------------------------------------------------------------------
# Urgencia de comida (AIUrgency.food_urgency).
# ---------------------------------------------------------------------------
@export_group("Urgencia comida")
@export var food_urg_early_t0: float = 0.0
@export var food_urg_early_t1: float = 2.0
@export var food_urg_early_t2: float = 5.0
@export var food_urg_early_v0: float = 3.0
@export var food_urg_early_v1: float = 1.8
@export var food_urg_early_v2: float = 1.0
@export var food_urg_early_v3: float = 0.8

@export var food_urg_mid_t0: float = 0.0
@export var food_urg_mid_t1: float = 5.0
@export var food_urg_mid_t2: float = 10.0
@export var food_urg_mid_v0: float = 3.0
@export var food_urg_mid_v1: float = 2.0
@export var food_urg_mid_v2: float = 1.2
@export var food_urg_mid_v3: float = 1.0

@export var food_urg_late_t0: float = 0.0
@export var food_urg_late_t1: float = 5.0
@export var food_urg_late_t2: float = 10.0
@export var food_urg_late_v0: float = 3.0
@export var food_urg_late_v1: float = 2.0
@export var food_urg_late_v2: float = 1.2
@export var food_urg_late_v3: float = 1.0


# ---------------------------------------------------------------------------
# Urgencia militar (prepare_decision_cache / _military_urgency).
# ---------------------------------------------------------------------------
@export_group("Urgencia militar")
@export var mil_urg_base_idle: float = 0.4       ## sin amenaza cercana
@export var mil_urg_base_adjacent: float = 0.9   ## enemigo adyacente
@export var mil_urg_base_active: float = 1.5     ## frente activo propio
@export var mil_urg_max: float = 3.0             ## techo con presión de frente máxima


# ---------------------------------------------------------------------------
# Urgencia de mazo (AIUrgency.deck_urgency).
# ---------------------------------------------------------------------------
@export_group("Urgencia mazo")
@export var deck_urg_t0: float = 3.0
@export var deck_urg_t1: float = 6.0
@export var deck_urg_v0: float = 2.0
@export var deck_urg_v1: float = 1.4
@export var deck_urg_v2: float = 1.0


# ---------------------------------------------------------------------------
# Factores globales.
# ---------------------------------------------------------------------------
@export_group("Factores")
@export var type_sat_min: float = 0.25            ## _type_saturation: suelo del factor
@export var surplus_min_food: float = 5.0         ## _resource_surplus_factor: comida mínima
@export var surplus_comfortable_early: float = 80.0
@export var surplus_comfortable_mid: float = 200.0
@export var surplus_comfortable_late: float = 350.0
@export var surplus_max: float = 3.0
@export var expansion_reference: float = 15.0     ## _expansion_factor: tiles adj. para presión máx.
@export var expansion_unknown: float = 0.5        ## valor neutro sin mapa
@export var build_cost_min: float = 0.6           ## _build_cost_factor: suelo al gastar todo el oro

# Deck sizing (compartido por _deck_thinning_value, dynamic_purge_threshold,
# should_buy_shop_item, score_card_for_deck CardDraw y _current_deck_size ratios).
@export var deck_small: float = 5.0
@export var deck_large: float = 20.0
@export var deck_thin_small: float = 2.0
@export var deck_thin_large: float = 9.0
@export var purge_thresh_small: float = 3.0
@export var purge_thresh_large: float = 10.0
@export var shop_thresh_small: float = 5.0
@export var shop_thresh_large: float = 12.0

# _encirclement_pressure: multiplicador según ratio colonizables/controladas.
@export var encircle_default: float = 1.5   ## sin info / ratio>=2.0
@export var encircle_r2: float = 2.0        ## umbral ratio alto
@export var encircle_r1: float = 1.0        ## umbral ratio medio
@export var encircle_r05: float = 0.5       ## umbral ratio bajo
@export var encircle_high: float = 1.5      ## ratio>=2.0
@export var encircle_mid: float = 2.5       ## ratio>=1.0
@export var encircle_low: float = 4.0       ## ratio>=0.5
@export var encircle_min: float = 5.0       ## ratio<0.5 (rodeado)

# _territory_race_factor.
@export var tr_close_share: float = 0.60
@export var tr_close_factor: float = 2.0
@export var tr_lead_share: float = 0.50
@export var tr_lead_factor: float = 1.5
@export var tr_block_share: float = 0.55
@export var tr_block_factor: float = 1.5
@export var tr_econ_factor: float = 0.7


# ---------------------------------------------------------------------------
# Pesos de scoring de edificios (build / upgrade / direct build).
# ---------------------------------------------------------------------------
@export_group("Edificios")
@export var gold_weight_pos: float = 5.0     ## peso de gold_produced >= 0
@export var gold_weight_maint: float = 2.5   ## peso de gold_produced < 0 (mantenimiento)
@export var food_weight: float = 4.0
@export var defense_weight: float = 8.0
@export var build_resource_match: float = 2.0  ## bonus si el edificio explota el recurso de la tile
@export var build_border: float = 1.0          ## bonus por posición fronteriza
@export var unlock_gold: float = 3.0           ## _score_unlocked_buildings
@export var unlock_food: float = 2.5
@export var unlock_defense: float = 5.0
@export var unlock_cap: float = 15.0


# ---------------------------------------------------------------------------
# Reclutamiento (_score_recruit, _complement_bonus).
# ---------------------------------------------------------------------------
@export_group("Reclutamiento")
@export var recruit_veto_score: float = -10.0        ## score de veto duro
@export var recruit_food_veto_margin: float = -5.0   ## food - maintenance < margen → veto
## Recargo cuadrático de comida por tropa que la heurística PROYECTA al reclutar.
## Espeja `GameBalance.FRONT_SURCHARGE_PER_TROOP` (la regla real), pero se mantiene
## como peso aparte a propósito: es la ESTIMACIÓN que usa la IA para decidir, y
## puede ajustarse (por .tres o por el optimizador) sin tocar la regla del juego.
## Si el balance real cambia, revisar si este default debe seguirlo.
@export var recruit_front_charge_per_troop: float = 5.0
@export var recruit_front_food_margin: float = 5.0   ## comida mínima tras el recargo
@export var recruit_atkdef_weight: float = 3.0
@export var recruit_saturation_k: float = 0.04       ## rendimiento decreciente por pool
@export var recruit_cost_eff_base: float = 30.0      ## coste base de referencia (sqrt(base/cost))
@export var recruit_type_diversity_k: float = 0.2    ## penalización por monocultura de tipo

# _complement_bonus (balance atk/def del pool): umbrales de ratio y bonus.
@export var complement_pool_hi: float = 2.0
@export var complement_troop_lo: float = 0.8
@export var complement_pool_mid: float = 1.5
@export var complement_troop_mid: float = 1.0
@export var complement_pool_lo: float = 0.5
@export var complement_troop_hi: float = 1.2
@export var complement_pool_lomid: float = 0.8
@export var complement_bonus_hi: float = 2.0
@export var complement_bonus_mid: float = 1.5
@export var counter_bonus: float = 1.5               ## ventaja de matchup vs tipo del rival


# ---------------------------------------------------------------------------
# Apertura de frente (_score_open_front).
# ---------------------------------------------------------------------------
@export_group("Frente")
@export var openfront_pool_divisor: float = 6.0
@export var openfront_pool_cap: float = 1.5
@export var openfront_gold: float = 4.0
@export var openfront_food: float = 2.0
@export var openfront_base_strategic: float = 3.0    ## valor territorial base
@export var openfront_base_mu: float = 3.0           ## componente militar del base
@export var openfront_econ_unsafe: float = 0.15      ## gpt<0 o food<0
@export var openfront_econ_caution: float = 0.5      ## economía ajustada por fase
@export var openfront_econ_early_gpt: float = 30.0
@export var openfront_econ_early_food: float = 2.0
@export var openfront_econ_mid_gpt: float = 150.0
@export var openfront_econ_mid_food: float = 5.0
@export var openfront_econ_late_gpt: float = 50.0
@export var openfront_econ_late_food: float = 5.0
@export var openfront_win_default: float = 0.7       ## P(ganar) sin info de rival
@export var openfront_win_min: float = 0.2
@export var openfront_win_max: float = 0.9
@export var openfront_win_neutral: float = 0.5
@export var openfront_source_building: float = 3.0   ## riesgo de la tile origen
@export var openfront_source_gold: float = 2.0
@export var openfront_source_food: float = 1.5


# ---------------------------------------------------------------------------
# Táctica, robo, colonización, cambio de ubicación, oro directo.
# ---------------------------------------------------------------------------
@export_group("Cartas varias")
@export var tactic_base: float = 12.0
@export var tactic_urgency_scale: float = 18.0
@export var draw_weight: float = 4.0
@export var colonize_gold: float = 4.0
@export var colonize_food: float = 5.0
@export var colonize_expansion: float = 3.0          ## bonus territorial (× _expansion_factor)
@export var colonize_denial: float = 3.0             ## negar expansión al rival
@export var changeloc_veto: float = -20.0            ## comida resultante negativa
@export var changeloc_demo_gold: float = 4.0         ## penalización por demolición
@export var changeloc_demo_food: float = 3.0
@export var changeloc_demo_defense: float = 6.0
@export var changeloc_resource_bonus: float = 8.0    ## edificio de recurso mejorado sobrevive
@export var changeloc_slot: float = 10.0             ## valor por slot de edificio nuevo
@export var changeloc_consumption: float = 3.0       ## coste por comida de mantenimiento
@export var simple_gold_weight: float = 0.4          ## GenerateGoldCard jugada (one-shot)


# ---------------------------------------------------------------------------
# score_card_for_deck (valor de una carta en el mazo, por tipo).
# ---------------------------------------------------------------------------
@export_group("Valor en mazo")
@export var scd_colonize_empty: float = 0.5
@export var scd_colonize_lo: float = 8.0
@export var scd_colonize_hi: float = 15.0
@export var scd_db_gold: float = 5.0
@export var scd_db_food: float = 4.0
@export var scd_db_defense: float = 8.0
@export var scd_db_default: float = 5.0
@export var scd_upg_none: float = 2.0
@export var scd_upg_lo: float = 5.0
@export var scd_upg_hi: float = 18.0
@export var scd_upg_ref: float = 5.0
@export var scd_build_none: float = 1.0
@export var scd_build_lo: float = 5.0
@export var scd_build_hi: float = 20.0
@export var scd_build_ref: float = 10.0
@export var scd_recruit_base: float = 8.0
@export var scd_recruit_mu: float = 5.0
@export var scd_openfront_base: float = 5.0
@export var scd_openfront_mu: float = 4.0
@export var scd_tactic_base: float = 4.0
@export var scd_tactic_mu: float = 3.0
@export var scd_clt_invalid: float = 2.0
@export var scd_clt_ref: float = 5.0
@export var scd_clt_poor_lo: float = 2.0
@export var scd_clt_poor_hi: float = 7.0
@export var scd_clt_lo: float = 5.0
@export var scd_clt_hi: float = 14.0
@export var scd_draw_lo: float = 8.0
@export var scd_draw_hi: float = 14.0
@export var scd_draw_ref: float = 20.0
@export var scd_recover_frac: float = 0.6
@export var scd_recover_lo: float = 4.0
@export var scd_recover_hi: float = 12.0
@export var scd_gold_weight: float = 0.3
@export var scd_unknown: float = 5.0


# ---------------------------------------------------------------------------
# score_choice (eventos) y should_buy_shop_item.
# ---------------------------------------------------------------------------
@export_group("Eventos")
@export var choice_gold: float = 0.4
@export var choice_food: float = 0.5
@export var choice_random_pool: float = 8.0
@export var choice_megalopolis: float = 28.0
@export var choice_unknown: float = 3.0
@export var choice_cost_penalty: float = 2.0
## Ramas que SOLO puntuaba el snapshot; al unificar score_choice pasaron a ser
## pesos y valen también en el mundo vivo, que antes las trataba como "efecto
## desconocido".
@export var choice_unlock: float = 10.0      ## AddToCardPool / UnlockBuilding: amplían el espacio de acciones
@export var choice_colonize: float = 15.0    ## ColonizeAdjacent: casilla gratis
@export var choice_modifier: float = 5.0     ## ApplyModifier / Scaled*Modifier


# ---------------------------------------------------------------------------
# Efectos de edificio (_score_building_effects, _score_stat_effect).
# ---------------------------------------------------------------------------
@export_group("Efectos de edificio")
@export var bce_buildcost_early: float = 0.5
@export var bce_buildcost_mid: float = 1.5
@export var bce_buildcost_late: float = 1.0
@export var bce_gold_on_card: float = 0.5
@export var se_flat_gold: float = 5.0
@export var se_percent_gold: float = 5.0
@export var se_flat_food: float = 4.0
@export var se_percent_food: float = 4.0
@export var se_tile_gold: float = 5.0
@export var se_tile_food: float = 4.0
@export var se_cpt_horizon_lo: float = 5.0    ## CARDS_PER_TURN: horizonte cerca de ganar
@export var se_cpt_horizon_hi: float = 40.0   ## horizonte lejos de ganar
@export var se_cpt_share_target: float = 0.70 ## umbral de victoria para el horizonte
@export var se_cpt_base: float = 8.0
@export var se_cpt_horizon_scale: float = 0.6
@export var se_card_draw: float = 8.0
@export var se_tpr_base: float = 5.0          ## TROOPS_PER_RECRUIT
@export var se_tpr_mu: float = 20.0
@export var se_tpr_dr_k: float = 0.12         ## rendimiento decreciente por bonus acumulado
@export var se_maint: float = 0.3             ## TROOP_MAINTENANCE_PERCENT


# ---------------------------------------------------------------------------
# score_state (evaluación de estado para MCTS). Pesos por fase + normalizadores.
# ---------------------------------------------------------------------------
@export_group("Estado (MCTS)")
@export var state_victory_share: float = 0.70   ## dominación (condición terminal)
# Pesos por fase de la evaluación de estado del MCTS (AIRealEval.score_state).
# Valores reforzados hacia TERRITORIO respecto a versiones previas: la victoria es
# por dominación, y en rollouts cortos reclutar movía el valor más que colonizar.
@export var state_w_t_early: float = 0.55
@export var state_w_e_early: float = 0.28
@export var state_w_m_early: float = 0.12
@export var state_w_k_early: float = 0.05
@export var state_w_t_mid: float = 0.48
@export var state_w_e_mid: float = 0.30
@export var state_w_m_mid: float = 0.17
@export var state_w_k_mid: float = 0.05
@export var state_w_t_late: float = 0.42
@export var state_w_e_late: float = 0.20
@export var state_w_m_late: float = 0.33
@export var state_w_k_late: float = 0.05
@export var state_t_norm: float = 0.70          ## normaliza el diferencial territorial (cuota)
## Territorio: mezcla de la cuota diferencial y la ventaja ABSOLUTA de casillas,
## para que cada colonización mueva la aguja (la cuota sola era casi insensible).
@export var state_t_count_norm: float = 12.0    ## normaliza la ventaja absoluta de casillas
@export var state_t_share_mix: float = 0.5      ## peso de la cuota vs la ventaja absoluta [0,1]
@export var state_e_norm: float = 1000.0        ## normaliza el diferencial de gpt
@export var state_food_norm: float = 20.0
@export var state_food_stability_cap: float = 0.5
@export var state_food_stability_weight: float = 0.3
@export var state_m_norm: float = 100.0
@export var state_k_norm: float = 5.0
@export var state_tanh_scale: float = 2.0


# ===========================================================================
# Default cacheado
# ===========================================================================

static var _default: HeuristicWeights = null

## Instancia por defecto COMPARTIDA (todos los campos en su valor original).
## Se usa como fallback cuando no hay pesos asignados en el contexto.
##
## CONTRATO — **es de SOLO LECTURA**. Se devuelve la misma
## instancia a todo el proceso, a propósito: `get_default()` se llama en caminos
## calientes (AIRealEval, AIRealEvalStrong, AIRealMCTS) y duplicar ahí sería caro.
## A cambio, mutar un campo del resultado corrompería TODAS las partidas del
## proceso, incluidas las tandas de simulación. Quien necesite variar pesos debe
## partir de `HeuristicWeights.new()` o de `duplicate()`, nunca escribir aquí.
## `test_heuristic_weights` vigila el contrato: comprueba que el default sigue
## valiendo lo mismo que una instancia recién creada.
static func get_default() -> HeuristicWeights:
	if _default == null:
		_default = HeuristicWeights.new()
	return _default


# ===========================================================================
# Interfaz para optimizadores
# ===========================================================================

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
	var d := float(get_default().get(key))
	if d == 0.0:
		return Vector2(0.0, 1.0)
	var lo := d * 0.25
	var hi := d * 4.0
	return Vector2(minf(lo, hi), maxf(lo, hi))


## Valida los invariantes de los pesos. Devuelve una lista de problemas (vacía =
## OK). Comprueba la monotonía de las curvas de urgencia (umbrales no decrecientes)
## y que los pesos de mezcla queden en [0,1]. El optimizador la llama antes de
## evaluar un candidato para descartar configuraciones incoherentes.
func validate() -> Array[String]:
	var errors: Array[String] = []
	_require_non_decreasing(errors, "gold_urg_early",
		[gold_urg_early_t0, gold_urg_early_t1, gold_urg_early_t2])
	_require_non_decreasing(errors, "gold_urg_mid",
		[gold_urg_mid_t0, gold_urg_mid_t1, gold_urg_mid_t2, gold_urg_mid_t3])
	_require_non_decreasing(errors, "gold_urg_late",
		[gold_urg_late_t0, gold_urg_late_t1, gold_urg_late_t2, gold_urg_late_t3,
		gold_urg_late_t4, gold_urg_late_t5, gold_urg_late_t6])
	_require_non_decreasing(errors, "food_urg_early",
		[food_urg_early_t0, food_urg_early_t1, food_urg_early_t2])
	_require_non_decreasing(errors, "food_urg_mid",
		[food_urg_mid_t0, food_urg_mid_t1, food_urg_mid_t2])
	_require_non_decreasing(errors, "food_urg_late",
		[food_urg_late_t0, food_urg_late_t1, food_urg_late_t2])
	_require_non_decreasing(errors, "deck_urg", [deck_urg_t0, deck_urg_t1])
	if state_t_share_mix < 0.0 or state_t_share_mix > 1.0:
		errors.append("state_t_share_mix fuera de [0,1]: %.3f" % state_t_share_mix)
	return errors


func _require_non_decreasing(errors: Array[String], label: String, values: Array) -> void:
	for i in range(1, values.size()):
		if float(values[i]) < float(values[i - 1]):
			errors.append("%s: umbral no creciente en índice %d (%.2f < %.2f)" % [
				label, i, values[i], values[i - 1]])


## Serializa los campos indicados (o OPTIMIZABLE_KEYS por defecto) a un vector.
func to_vector(keys: PackedStringArray = []) -> PackedFloat64Array:
	var k := keys if not keys.is_empty() else OPTIMIZABLE_KEYS
	var out := PackedFloat64Array()
	out.resize(k.size())
	for i in range(k.size()):
		out[i] = float(get(k[i]))
	return out


## Aplica un vector a los campos indicados (o OPTIMIZABLE_KEYS por defecto).
func apply_vector(v: PackedFloat64Array, keys: PackedStringArray = []) -> void:
	var k := keys if not keys.is_empty() else OPTIMIZABLE_KEYS
	var n := mini(v.size(), k.size())
	for i in range(n):
		set(k[i], v[i])


## Copia profunda para candidatos del optimizador.
func clone() -> HeuristicWeights:
	return duplicate(true) as HeuristicWeights
