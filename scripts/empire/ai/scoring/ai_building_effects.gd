extends RefCounted
class_name AIBuildingEffects

## Puntuación de efectos de edificio, escrita UNA sola vez.
## Antes vivía DUPLICADA en AIHeuristic (estado vivo) y AIRealEvalStrong (snapshot).
## Se unifican las FÓRMULAS con pesos (las que el optimizador ajusta y donde vive el
## riesgo de divergencia). Los dos casos de AddStatModifierEffect que dependen del
## estado —CARDS_PER_TURN (cuota territorial) y TROOPS_PER_RECRUIT (bonus acumulado)—
## reciben su escalar ya calculado: cada mundo lo obtiene con su propia representación
## y SOLO dentro de su rama del match, preservando la evaluación perezosa (esos
## recorridos son caros y corren en el camino caliente del MCTS en el snapshot).
##
## La rama AddCardToDeckEffect NO se unifica aquí: cada mundo puntúa la carta con un
## valorador distinto (AIHeuristic.score_card_for_deck completo vs
## AIRealEvents._score_card_for_deck suelo) — eso es otro subpaso.


## Casos "simples" de AddStatModifierEffect: puros sobre primitivas + pesos. Los dos
## casos dependientes de estado (CARDS_PER_TURN, TROOPS_PER_RECRUIT) los resuelve el
## llamante con cards_per_turn_score / troops_per_recruit_score; aquí devuelven 0.0
## para no romper el contrato de este helper.
static func stat_effect_simple(stat_type: int, v: float, gpt: int, food: int,
		pool_size: int, gu: float, fu: float, mu: float, w: HeuristicWeights) -> float:
	match stat_type:
		StatModifier.StatType.FLAT_GOLD:
			return v * w.se_flat_gold * gu
		StatModifier.StatType.PERCENT_GOLD:
			return gpt * v / 100.0 * w.se_percent_gold * gu
		StatModifier.StatType.FLAT_FOOD:
			return v * w.se_flat_food * fu
		StatModifier.StatType.PERCENT_FOOD:
			return food * v / 100.0 * w.se_percent_food * fu
		StatModifier.StatType.TILE_RESOURCE_GOLD:
			return v * w.se_tile_gold * gu
		StatModifier.StatType.TILE_RESOURCE_FOOD:
			return v * w.se_tile_food * fu
		StatModifier.StatType.CARD_DRAW_BONUS:
			return v * w.se_card_draw
		StatModifier.StatType.TROOP_MAINTENANCE_PERCENT:
			return pool_size * absf(v) * w.se_maint * mu
	return 0.0


## CARDS_PER_TURN: carta extra por turno como valor de FLUJO. El horizonte cae al
## acercarse a la victoria territorial (my_share → se_cpt_share_target). `my_share`
## (cuota de casillas propia) lo calcula cada mundo con su representación.
static func cards_per_turn_score(v: float, my_share: float, w: HeuristicWeights) -> float:
	var horizon := lerpf(w.se_cpt_horizon_lo, w.se_cpt_horizon_hi,
		clampf(1.0 - my_share / w.se_cpt_share_target, 0.0, 1.0))
	return v * (w.se_cpt_base + horizon * w.se_cpt_horizon_scale)


## TROOPS_PER_RECRUIT: escala con la urgencia militar y con rendimiento decreciente
## suave según el bonus de throughput ya acumulado (`current_bonus`, sumado por cada
## mundo sobre sus edificios propios).
static func troops_per_recruit_score(v: float, mu: float, current_bonus: int,
		w: HeuristicWeights) -> float:
	var dr_factor := 1.0 / (1.0 + float(current_bonus) * w.se_tpr_dr_k)
	return v * (w.se_tpr_base + w.se_tpr_mu * mu) * dr_factor


## AddBuildCostModifierEffect: descuento en construcciones futuras, más valioso en mid.
static func build_cost_modifier_score(percent: float, phase: AIGamePhase.Phase,
		w: HeuristicWeights) -> float:
	match phase:
		AIGamePhase.Phase.EARLY: return percent * w.bce_buildcost_early
		AIGamePhase.Phase.MID:   return percent * w.bce_buildcost_mid
		_:                       return percent * w.bce_buildcost_late


## GoldOnCard: recompensa de oro al jugar la carta (frecuencia estimada conservadora).
static func gold_on_card_score(gold_reward: float, gu: float, w: HeuristicWeights) -> float:
	return gold_reward * w.bce_gold_on_card * gu
