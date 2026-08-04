extends RefCounted
class_name AIUrgency

## Señales de urgencia por recurso (oro/comida/mazo), dependientes de la fase.
## Escritas UNA sola vez. Antes vivían DUPLICADAS en
## AIHeuristic (heurística sobre estado vivo) y AIRealEvalStrong (espejo sobre el
## snapshot). Son funciones PURAS sobre primitivas + pesos: cada mundo obtiene sus
## escalares (gpt, food, tamaño de mazo) de su propia representación y llama aquí,
## de modo que la fórmula y los umbrales viven en un único lugar y el optimizador
## (SA/GA) ajusta ambos mundos a la vez.
##
## Nota de paridad (comida): la versión de AIRealEvalStrong colapsaba MID y LATE en
## una sola rama con los pesos de MID. Aquí se restaura la fórmula completa
## (MID ≠ LATE). Es byte-idéntico mientras food_urg_late_* == food_urg_mid_*
## (cierto por defecto y en el campeón actual, que no serializa esos campos) y
## corrige la divergencia latente que el optimizador dispararía al tocar los
## umbrales de LATE.


## Urgencia de oro: cuánto necesitamos mejorar el gold_per_turn ahora. Los umbrales
## son distintos por fase: 50 gpt es crisis en mid game pero holgado en early (los
## edificios básicos cuestan 50-100, los upgrades 200-400, los lategame hasta 800).
static func gold_urgency(gpt: int, phase: AIGamePhase.Phase, w: HeuristicWeights) -> float:
	match phase:
		AIGamePhase.Phase.EARLY:
			if gpt < w.gold_urg_early_t0:  return w.gold_urg_early_v0
			if gpt < w.gold_urg_early_t1:  return w.gold_urg_early_v1
			if gpt < w.gold_urg_early_t2:  return w.gold_urg_early_v2
			return w.gold_urg_early_v3
		AIGamePhase.Phase.MID:
			# Target mid: 300-400 gpt para construir/mejorar cada turno.
			if gpt < w.gold_urg_mid_t0:  return w.gold_urg_mid_v0
			if gpt < w.gold_urg_mid_t1:  return w.gold_urg_mid_v1
			if gpt < w.gold_urg_mid_t2:  return w.gold_urg_mid_v2
			if gpt < w.gold_urg_mid_t3:  return w.gold_urg_mid_v3
			return w.gold_urg_mid_v4
		_: # LATE
			# Rendimiento decreciente: mucho GPT → invertir en militares, no en más oro.
			if gpt < w.gold_urg_late_t0:  return w.gold_urg_late_v0
			if gpt < w.gold_urg_late_t1:  return w.gold_urg_late_v1
			if gpt < w.gold_urg_late_t2:  return w.gold_urg_late_v2
			if gpt < w.gold_urg_late_t3:  return w.gold_urg_late_v3
			if gpt < w.gold_urg_late_t4:  return w.gold_urg_late_v4
			if gpt < w.gold_urg_late_t5:  return w.gold_urg_late_v5
			if gpt < w.gold_urg_late_t6:  return w.gold_urg_late_v6
			return w.gold_urg_late_v7


## Urgencia de comida: cuánto necesitamos mejorar el balance de food. En mid/late el
## margen debe ser mayor porque cada Town cuesta -5 food.
static func food_urgency(food: int, phase: AIGamePhase.Phase, w: HeuristicWeights) -> float:
	match phase:
		AIGamePhase.Phase.EARLY:
			if food < w.food_urg_early_t0: return w.food_urg_early_v0
			if food < w.food_urg_early_t1: return w.food_urg_early_v1
			if food < w.food_urg_early_t2: return w.food_urg_early_v2
			return w.food_urg_early_v3
		AIGamePhase.Phase.MID:
			if food < w.food_urg_mid_t0:  return w.food_urg_mid_v0
			if food < w.food_urg_mid_t1:  return w.food_urg_mid_v1
			if food < w.food_urg_mid_t2:  return w.food_urg_mid_v2
			return w.food_urg_mid_v3
		_: # LATE
			if food < w.food_urg_late_t0:  return w.food_urg_late_v0
			if food < w.food_urg_late_t1:  return w.food_urg_late_v1
			if food < w.food_urg_late_t2:  return w.food_urg_late_v2
			return w.food_urg_late_v3


## Urgencia de mazo: cuánto necesitamos más cartas disponibles. Cada mundo pasa su
## propia medida de tamaño: el vivo usa el draw_pile; el snapshot usa el mazo
## combinado (draw+discard). La lógica de umbrales es idéntica.
static func deck_urgency(deck_size: int, w: HeuristicWeights) -> float:
	if deck_size < w.deck_urg_t0: return w.deck_urg_v0
	if deck_size < w.deck_urg_t1: return w.deck_urg_v1
	return w.deck_urg_v2


# ---------------------------------------------------------------------------
# Urgencia militar. Fórmula compartida por los cuatro caminos
# que la calculaban por separado: el vivo con caché (prepare_decision_cache), el
# vivo sin caché (_military_urgency/_max_front_pressure fallback) y el snapshot
# (AIRealEvalStrong). Cada mundo mantiene su propio RECORRIDO de frentes/tiles
# (tipos distintos: BattleFront vs FrontSnap) y llama aquí para la fórmula y los
# pesos, de modo que el optimizador ajusta ambos a la vez.
# La versión DÉBIL de una rama (AIRealEval.score_move, prior floor con 0.4/1.5/2.5
# hardcodeados) es OTRA abstracción y no pasa por aquí.
# ---------------------------------------------------------------------------

## Presión [0.0, 1.0] de UN frente desde la perspectiva de la IA: qué tan cerca de
## perderlo. `ai_marker` ya trae el signo propio (marker si atacamos, -marker si
## defendemos). No se protege la división: `threshold` es siempre ≥ MIN_THRESHOLD.
static func front_pressure(ai_marker: float, threshold: float) -> float:
	return clampf(-ai_marker / threshold, 0.0, 1.0)


## Urgencia militar: baseline según la amenaza real (frente activo > enemigo
## adyacente > tranquilo) interpolado hacia mil_urg_max por la presión máxima de
## los frentes propios. Cada mundo calcula los dos booleanos y max_pressure con su
## propio recorrido y pasa los escalares aquí.
static func military_urgency_from(has_active_front: bool, has_adjacent_enemy: bool,
		max_pressure: float, w: HeuristicWeights) -> float:
	var base := w.mil_urg_base_idle
	if has_active_front:      base = w.mil_urg_base_active
	elif has_adjacent_enemy:  base = w.mil_urg_base_adjacent
	return lerpf(base, w.mil_urg_max, max_pressure)
