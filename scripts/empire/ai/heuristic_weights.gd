extends Resource
class_name HeuristicWeights

## Tabla de valores de la heurística de decisión de la IA (AIHeuristic): los números
## que dicen cuánto vale cada cosa, fuera del código para poder ajustarlos sin
## tocarlo y para que el optimizador (SA/GA) los lea, mute y guarde como .tres.
##
## Inyección: AITurnContext.get_weights() devuelve los pesos activos (los de
## AIConfig.heuristic_weights si están asignados, o el default cacheado). Ver
## AIHeuristic para los puntos de uso.
##
## Qué campos son optimizables, en qué rango se mueven y cómo se traducen a vector
## vive en [HeuristicWeightsSpec], que es quien depende de aquí — nunca al revés:
## este Resource se carga desde .tres y un ciclo de clases rompería ese load() en
## silencio.


# Fronteras entre fases (AIGamePhase.detect_from). NO son reglas: nada en el juego
# depende de la fase, es solo la lectura con la que la IA elige curva de urgencia y
# pesos. CALIBRADAS contra la simulación: con 0.30/350 el 80 % de los snapshots caía
# en LATE y las bandas de EARLY y MID eran decorativas; con estos valores, medido en
# partida real, 7.4 / 42.5 / 50.1 %. Los dos umbrales de LATE se mueven juntos porque
# la condición es un OR (ver HeuristicWeightsInvariants.BLOCKS).
@export_group("Fases de partida")
@export var phase_late_share: float = 0.55   ## LATE con >= esta cuota del mapa
@export var phase_early_share: float = 0.20  ## EARLY solo por debajo de esta cuota...
@export var phase_early_gpt: float = 400.0   ## ...y con el gpt por debajo de esto
@export var phase_late_gpt: float = 1400.0   ## LATE por gpt, escalado al mapa real


# Urgencia de oro (AIUrgency.gold_urgency): umbrales de gpt (t*) y valores (v*) por fase.
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


# Urgencia de comida (AIUrgency.food_urgency).
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


# Urgencia militar (prepare_decision_cache / _military_urgency).
@export_group("Urgencia militar")
@export var mil_urg_base_idle: float = 0.4       ## sin amenaza cercana
@export var mil_urg_base_adjacent: float = 0.9   ## enemigo adyacente
@export var mil_urg_base_active: float = 1.5     ## frente activo propio
@export var mil_urg_max: float = 3.0             ## techo con presión de frente máxima


# Urgencia de mazo (AIUrgency.deck_urgency).
@export_group("Urgencia mazo")
@export var deck_urg_t0: float = 3.0
@export var deck_urg_t1: float = 6.0
@export var deck_urg_v0: float = 2.0
@export var deck_urg_v1: float = 1.4
@export var deck_urg_v2: float = 1.0


# Factores globales.
@export_group("Factores")
@export var type_sat_min: float = 0.25            ## _type_saturation: suelo del factor
@export var surplus_min_food: float = 5.0         ## _resource_surplus_factor: comida mínima
@export var surplus_comfortable_early: float = 80.0
@export var surplus_comfortable_mid: float = 200.0
@export var surplus_comfortable_late: float = 350.0
@export var surplus_max: float = 3.0
@export var expansion_reference: float = 15.0     ## _expansion_factor: tiles adj. para presión máx.
@export var expansion_unknown: float = 0.5        ## valor neutro sin mapa
@export var build_cost_min: float = 0.6           ## build_cost_factor: suelo del factor de coste
## Coste por unidad de VALOR a partir del cual un edificio se considera caro del todo
## (el factor toca su suelo). Con build_cost_min acota la banda de reordenación.
@export var build_cost_ref: float = 4.0

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
## VESTIGIAL: no lo lee nadie ni está en el SPEC. Se conserva para que
## `heuristic_weights_optimized.tres`, que lo serializa, siga cargando sin avisos.
@export var tr_econ_factor: float = 0.7


# Pesos de scoring de edificios (build / upgrade / direct build).
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


# Reclutamiento (_score_recruit, _complement_bonus).
@export_group("Reclutamiento")
@export var recruit_veto_score: float = -10.0        ## score de veto duro
@export var recruit_food_veto_margin: float = -5.0   ## food - maintenance < margen → veto
## Cuánto se CREE la IA el recargo de frente al decidir si recluta: escala el extra
## que proyecta pagar si la tropa acabara guarnecida. 1.0 = se lo cree tal cual.
## Se mantiene como peso aparte de la regla (CombatMath.front_food_upkeep_multiplier) a
## propósito: es una ESTIMACIÓN sobre un futuro incierto —la tropa puede no llegar a
## asignarse— y debe poder ajustarse sin tocar el balance del juego.
@export var recruit_front_charge_belief: float = 1.0
@export var recruit_front_food_margin: float = 5.0   ## comida mínima tras el recargo
@export var recruit_atkdef_weight: float = 3.0
## Convierte el poder de una tropa en unidades de score al decidir CUÁNTAS meter en
## un frente (TroopAssignmentPolicy). Aparte de recruit_atkdef_weight a propósito: a
## quién recluto y dónde lo pongo son decisiones distintas. El default se fijó para
## que el rango pretendido sea alcanzable —con 6.0 el techo efectivo (4) quedaba por
## DEBAJO del tope rígido de 5 que este diseño vino a quitar—; el fino, al optimizador.
@export var assign_power_weight: float = 10.0
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


# Apertura de frente (_score_open_front).
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


# Táctica, robo, colonización, cambio de ubicación, oro directo.
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


# score_card_for_deck (valor de una carta en el mazo, por tipo).
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


# score_choice (eventos) y should_buy_shop_item.
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


# Efectos de edificio (_score_building_effects, _score_stat_effect).
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
## Cuota territorial que se toma como "victoria" al estimar cuántos turnos quedan.
## Deriva de la REGLA (GameBalance.VICTORY_TILE_SHARE) en vez de repetir el 0.70:
## si mañana la dominación pide otra fracción, el horizonte la sigue solo.
@export var se_cpt_share_target: float = GameBalance.VICTORY_TILE_SHARE
@export var se_cpt_base: float = 8.0
@export var se_cpt_horizon_scale: float = 0.6
@export var se_card_draw: float = 8.0
@export var se_tpr_base: float = 5.0          ## TROOPS_PER_RECRUIT
@export var se_tpr_mu: float = 20.0
@export var se_tpr_dr_k: float = 0.12         ## rendimiento decreciente por bonus acumulado
@export var se_maint: float = 0.3             ## TROOP_MAINTENANCE_PERCENT


# score_state (evaluación de estado para MCTS). Pesos por fase + normalizadores.
@export_group("Estado (MCTS)")
## Condición TERMINAL de score_state: con esta cuota de casillas el estado vale ±1.
## No es un peso ajustable sino la REGLA de victoria vista por el MCTS, así que
## deriva de GameBalance.VICTORY_TILE_SHARE. Si divergiera, el árbol daría por
## ganadas partidas que el juego no termina (o al revés). Sigue siendo @export
## para poder darle a la IA una creencia distinta a propósito desde un .tres, pero
## NO está en SPEC: el optimizador no puede moverla.
@export var state_victory_share: float = GameBalance.VICTORY_TILE_SHARE
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


## Copia profunda para candidatos del optimizador.
func clone() -> HeuristicWeights:
	return duplicate(true) as HeuristicWeights
