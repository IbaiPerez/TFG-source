extends RefCounted
class_name AIRealEval

## Evaluación de estados y jugadas sobre AIRealState para la búsqueda MCTS v2
## (Fase C v2 — F3a).
##
##  - `score_state`: evaluación de HOJA, reimplementación fiel de
##    AIHeuristic.score_state sobre el snapshot (diferencial propio−rival en
##    [-1, 1] vía tanh). Es la señal que el árbol maximiza (negamax).
##  - `score_move`: PRIOR del PUCT y política de rollout, aproximación-suelo de
##    AIHeuristic.score_option por tipo de jugada sobre el estado simulado (el
##    detalle exacto de score_option vive acoplado a la escena; aquí basta una
##    guía relativa que el lookahead corrige).
##  - `detect_phase`: espejo de AIGamePhase.detect sobre el snapshot.


# ---------------------------------------------------------------------------
# Evaluación de hoja (espejo de AIHeuristic.score_state)
# ---------------------------------------------------------------------------

## Valor del estado desde la perspectiva propia, en [-1, 1].
static func score_state(state: AIRealState) -> float:
	var my_tiles := state.count_tiles(AIRealState.OWNER_SELF)
	var rival_tiles := state.count_tiles(AIRealState.OWNER_RIVAL)
	var total := maxi(state.total_map_tiles, my_tiles + rival_tiles + 1)
	var my_share := float(my_tiles) / float(total)
	var rival_share := float(rival_tiles) / float(total)

	# Condiciones terminales.
	if my_share >= 0.70: return 1.0
	if rival_share >= 0.70: return -1.0
	if rival_tiles == 0: return 1.0
	if my_tiles == 0: return -1.0

	var phase := detect_phase(state)
	# Pesos reforzados hacia TERRITORIO (F3 — retoque de eval): la victoria es
	# por dominación (70% de tiles), pero en rollouts cortos reclutar movía el
	# valor más que colonizar. Subir w_t y añadir el término de ventaja absoluta
	# de casillas evita que el MCTS infra-colonice y pierda la carrera territorial.
	var w_t := 0.55; var w_e := 0.28; var w_m := 0.12; var w_k := 0.05
	match phase:
		AIGamePhase.Phase.MID:
			w_t = 0.48; w_e = 0.30; w_m = 0.17; w_k = 0.05
		AIGamePhase.Phase.LATE:
			w_t = 0.42; w_e = 0.20; w_m = 0.33; w_k = 0.05

	# Territorio: mezcla del progreso hacia dominación (cuota) con la ventaja
	# ABSOLUTA de casillas, para que CADA colonización mueva la aguja (la cuota
	# sola, normalizada por el mapa entero, era casi insensible por colocación).
	var t_share := (my_share - rival_share) / 0.70
	var t_count := clampf(float(my_tiles - rival_tiles) / 12.0, -1.0, 1.0)
	var t_score := clampf(0.5 * t_share + 0.5 * t_count, -1.0, 1.0)
	var e_score := clampf(float(state.own.gold_per_turn - state.rival.gold_per_turn) / 1000.0,
		-1.0, 1.0)
	var food_stability := clampf(float(state.own.food) / 20.0, -1.0, 0.5)

	var my_power := 0.0
	for troop in state.own.troop_pool:
		my_power += float(troop.attack + troop.defense)
	var rival_power := _rival_front_power(state)
	var m_score := clampf((my_power - rival_power) / 100.0, -1.0, 1.0)

	var k_score := clampf(float(state.own.cards_per_turn - state.rival.cards_per_turn) / 5.0,
		-1.0, 1.0)

	var raw := w_t * t_score \
			 + w_e * (e_score + food_stability * 0.3) \
			 + w_m * m_score \
			 + w_k * k_score
	return tanh(raw * 2.0)


## Poder de tropas del rival visible en frentes (espejo del término militar
## de score_state: solo cuenta las tropas comprometidas del rival).
static func _rival_front_power(state: AIRealState) -> float:
	var power := 0.0
	for f in state.fronts:
		var front := f as AIRealState.FrontSnap
		if front.is_resolved:
			continue
		var troops: Array[Troop] = []
		if front.attacker_owner == AIRealState.OWNER_RIVAL:
			troops = front.attacker_troops
		elif front.defender_owner == AIRealState.OWNER_RIVAL:
			troops = front.defender_troops
		for troop in troops:
			power += float(troop.attack + troop.defense)
	return power


## True si el estado es terminal para la búsqueda (victoria/derrota por
## dominación o eliminación). Permite cortar rollouts.
static func is_terminal(state: AIRealState) -> bool:
	if state.total_map_tiles <= 0:
		return false
	var my_tiles := state.count_tiles(AIRealState.OWNER_SELF)
	var rival_tiles := state.count_tiles(AIRealState.OWNER_RIVAL)
	var total := float(maxi(state.total_map_tiles, my_tiles + rival_tiles + 1))
	if float(my_tiles) / total >= 0.70: return true
	if float(rival_tiles) / total >= 0.70: return true
	return my_tiles == 0 or rival_tiles == 0


# ---------------------------------------------------------------------------
# Fase (espejo de AIGamePhase.detect)
# ---------------------------------------------------------------------------

static func detect_phase(state: AIRealState,
		p_owner: int = AIRealState.OWNER_SELF) -> AIGamePhase.Phase:
	var emp := state.own if p_owner == AIRealState.OWNER_SELF else state.rival
	var gpt := emp.gold_per_turn
	var tiles := state.count_tiles(p_owner)
	if state.total_map_tiles > 0:
		var share := float(tiles) / float(state.total_map_tiles)
		var late_gpt := int(350.0 * float(state.total_map_tiles) / 127.0)
		if share >= 0.30 or gpt >= late_gpt:
			return AIGamePhase.Phase.LATE
		if share < 0.08 and gpt < 100:
			return AIGamePhase.Phase.EARLY
		return AIGamePhase.Phase.MID
	if gpt >= 350 or tiles >= 30:
		return AIGamePhase.Phase.LATE
	if gpt < 100 and tiles < 12:
		return AIGamePhase.Phase.EARLY
	return AIGamePhase.Phase.MID


# ---------------------------------------------------------------------------
# Prior de jugada (aproximación-suelo de AIHeuristic.score_option)
# ---------------------------------------------------------------------------

## Score relativo de una jugada para ordenar/podar (top-K) y como prior P del
## PUCT y política de rollout. No pretende clavar score_option (acoplado a
## escena): captura las prioridades — tiles >> economía > militar (si amenaza).
static func score_move(move: AIRealOptions.Move, state: AIRealState,
		p_owner: int = AIRealState.OWNER_SELF) -> float:
	if move.kind == &"PASS":
		return 0.0
	var emp := state.own if p_owner == AIRealState.OWNER_SELF else state.rival
	var gu := _gold_urgency(emp.gold_per_turn)
	var fu := _food_urgency(emp.food)
	var mu := _military_urgency(state, p_owner)
	var exp := _expansion_factor(state, p_owner)

	match move.kind:
		&"COLONIZE":
			# Prior alto: la expansión es el motor de la dominación. Por encima
			# de Recruit (~8+mu·5) para que el árbol no la infravalore en
			# profundidad (el prior real de score_option solo guía la raíz).
			return lerpf(12.0, 22.0, clampf(exp, 0.0, 1.0))
		&"BUILD", &"DIRECT_BUILD":
			if move.building != null:
				return move.building.gold_produced * 5.0 * gu \
					+ move.building.food_produced * 4.0 * fu \
					+ move.building.flat_defense_bonus * 8.0 * mu
			return 5.0
		&"UPGRADE":
			var dg := 0
			var df := 0
			if move.new_building != null and move.old_building != null:
				dg = move.new_building.gold_produced - move.old_building.gold_produced
				df = move.new_building.food_produced - move.old_building.food_produced
			return maxf(2.0, dg * 5.0 * gu + df * 4.0 * fu)
		&"CHANGE_LOCATION":
			return lerpf(5.0, 14.0, clampf(exp, 0.0, 1.0))
		&"GENERATE_GOLD":
			return move.amount * 0.3 * gu
		&"CARD_DRAW":
			return lerpf(8.0, 14.0, clampf(float(emp.deck.size()) / 20.0, 0.0, 1.0))
		&"RECRUIT":
			var troop_sat := 1.0 / (1.0 + emp.troop_pool.size() * 0.04)
			return (8.0 + mu * 5.0) * troop_sat
		&"OPEN_FRONT":
			return 5.0 + mu * 4.0
		&"TACTIC":
			return 4.0 + mu * 3.0
		_:
			return 5.0


static func _gold_urgency(gpt: int) -> float:
	if gpt < 0:   return 3.0
	if gpt < 50:  return 2.0
	if gpt < 100: return 1.3
	if gpt < 200: return 1.0
	if gpt < 500: return 0.7
	return 0.35


static func _food_urgency(food: int) -> float:
	if food < 0: return 3.0
	if food < 5: return 1.5
	return 0.5


## Urgencia militar: 0.4 base; sube si participamos en un frente; máxima si lo
## estamos perdiendo (espejo del espíritu de _military_urgency).
static func _military_urgency(state: AIRealState, p_owner: int) -> float:
	var urgency := 0.4
	for f in state.fronts:
		var front := f as AIRealState.FrontSnap
		if front.is_resolved:
			continue
		var side := front.side_of(p_owner)
		if side == &"":
			continue
		urgency = maxf(urgency, 1.5)
		var our_marker := front.marker if side == &"attacker" else -front.marker
		if our_marker < 0.0:
			urgency = maxf(urgency, 2.5)
	return urgency


## Presión expansionista: alta si controlamos poco territorio (hay donde crecer).
static func _expansion_factor(state: AIRealState, p_owner: int) -> float:
	var my_tiles := state.count_tiles(p_owner)
	var total := maxi(state.total_map_tiles, my_tiles + 1)
	var share := float(my_tiles) / float(total)
	return clampf(1.0 - share * 2.0, 0.2, 1.5)
