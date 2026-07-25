extends RefCounted
class_name AIRealEval

## Evaluación de estados y jugadas sobre AIRealState para la búsqueda MCTS.
##
##  - `score_state`: evaluación de HOJA (diferencial propio−rival en [-1, 1] vía
##    tanh, parametrizada por HeuristicWeights). Es la señal que el árbol maximiza
##    (negamax) y la ÚNICA score_state del proyecto.
##  - `score_move`: PRIOR del PUCT y política de rollout, aproximación-suelo de
##    AIHeuristic.score_option por tipo de jugada sobre el estado simulado (el
##    detalle exacto de score_option vive acoplado a la escena; aquí basta una
##    guía relativa que el lookahead corrige).
##  - `detect_phase`: espejo de AIGamePhase.detect sobre el snapshot.


# ---------------------------------------------------------------------------
# Evaluación de hoja del MCTS. Es la ÚNICA score_state del proyecto: antes había
# un espejo muerto (AIHeuristic.score_state) con pesos y esta versión viva con los
# valores hardcodeados. Ahora los pesos viven en HeuristicWeights (defaults =
# valores previos), así que el resultado es idéntico y quedan optimizables.
# ---------------------------------------------------------------------------

## Valor del estado desde la perspectiva propia, en [-1, 1]. `w` null → default.
static func score_state(state: AIRealState, w: HeuristicWeights = null) -> float:
	if w == null:
		w = HeuristicWeights.get_default()
	var my_tiles := state.count_tiles(AIRealState.OWNER_SELF)
	var rival_tiles := state.count_tiles(AIRealState.OWNER_RIVAL)
	var total := maxi(state.total_map_tiles, my_tiles + rival_tiles + 1)
	var my_share := float(my_tiles) / float(total)
	var rival_share := float(rival_tiles) / float(total)

	# Condiciones terminales.
	if my_share >= w.state_victory_share: return 1.0
	if rival_share >= w.state_victory_share: return -1.0
	if rival_tiles == 0: return 1.0
	if my_tiles == 0: return -1.0

	var phase := detect_phase(state)
	var w_t := w.state_w_t_early; var w_e := w.state_w_e_early
	var w_m := w.state_w_m_early; var w_k := w.state_w_k_early
	match phase:
		AIGamePhase.Phase.MID:
			w_t = w.state_w_t_mid; w_e = w.state_w_e_mid; w_m = w.state_w_m_mid; w_k = w.state_w_k_mid
		AIGamePhase.Phase.LATE:
			w_t = w.state_w_t_late; w_e = w.state_w_e_late; w_m = w.state_w_m_late; w_k = w.state_w_k_late

	var t_score := _territory_term(my_tiles, rival_tiles, my_share, rival_share, w)
	var e_score := _economy_term(state, w)
	var food_stability := clampf(float(state.own.food) / w.state_food_norm,
		-1.0, w.state_food_stability_cap)
	var m_score := _military_term(state, w)
	var k_score := _deck_term(state, w)

	var raw := w_t * t_score \
			 + w_e * (e_score + food_stability * w.state_food_stability_weight) \
			 + w_m * m_score \
			 + w_k * k_score
	return tanh(raw * w.state_tanh_scale)


## Territorio: mezcla del progreso hacia dominación (cuota diferencial) con la
## ventaja ABSOLUTA de casillas, para que CADA colonización mueva la aguja (la
## cuota sola, normalizada por el mapa entero, era casi insensible por colocación).
static func _territory_term(my_tiles: int, rival_tiles: int,
		my_share: float, rival_share: float, w: HeuristicWeights) -> float:
	var t_share := (my_share - rival_share) / w.state_t_norm
	var t_count := clampf(float(my_tiles - rival_tiles) / w.state_t_count_norm, -1.0, 1.0)
	return clampf(w.state_t_share_mix * t_share + (1.0 - w.state_t_share_mix) * t_count, -1.0, 1.0)


## Economía: diferencial de oro por turno normalizado.
static func _economy_term(state: AIRealState, w: HeuristicWeights) -> float:
	return clampf(float(state.own.gold_per_turn - state.rival.gold_per_turn) / w.state_e_norm,
		-1.0, 1.0)


## Militar: poder de tropas propias (pool) vs poder del rival visible en frentes.
static func _military_term(state: AIRealState, w: HeuristicWeights) -> float:
	var my_power := 0.0
	for troop in state.own.troop_pool:
		my_power += float(troop.attack + troop.defense)
	var rival_power := _rival_front_power(state)
	return clampf((my_power - rival_power) / w.state_m_norm, -1.0, 1.0)


## Mazo: diferencial de cartas por turno normalizado.
static func _deck_term(state: AIRealState, w: HeuristicWeights) -> float:
	return clampf(float(state.own.cards_per_turn - state.rival.cards_per_turn) / w.state_k_norm,
		-1.0, 1.0)


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
	if float(my_tiles) / total >= GameBalance.VICTORY_TILE_SHARE: return true
	if float(rival_tiles) / total >= GameBalance.VICTORY_TILE_SHARE: return true
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
		var late_gpt := int(float(GameBalance.PHASE_LATE_GPT) * float(state.total_map_tiles) \
			/ float(GameBalance.DEFAULT_MAP_TILE_COUNT))
		if share >= GameBalance.PHASE_LATE_SHARE or gpt >= late_gpt:
			return AIGamePhase.Phase.LATE
		if share < GameBalance.PHASE_EARLY_SHARE and gpt < GameBalance.PHASE_EARLY_GPT:
			return AIGamePhase.Phase.EARLY
		return AIGamePhase.Phase.MID
	if gpt >= GameBalance.PHASE_LATE_GPT or tiles >= GameBalance.PHASE_LATE_TILES_LEGACY:
		return AIGamePhase.Phase.LATE
	if gpt < GameBalance.PHASE_EARLY_GPT and tiles < GameBalance.PHASE_EARLY_TILES_LEGACY:
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
		if side == BattleFront.Side.NONE:
			continue
		urgency = maxf(urgency, 1.5)
		var our_marker := front.marker if side == BattleFront.Side.ATTACKER else -front.marker
		if our_marker < 0.0:
			urgency = maxf(urgency, 2.5)
	return urgency


## Presión expansionista: alta si controlamos poco territorio (hay donde crecer).
static func _expansion_factor(state: AIRealState, p_owner: int) -> float:
	var my_tiles := state.count_tiles(p_owner)
	var total := maxi(state.total_map_tiles, my_tiles + 1)
	var share := float(my_tiles) / float(total)
	return clampf(1.0 - share * 2.0, 0.2, 1.5)
