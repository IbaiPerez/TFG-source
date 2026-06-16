extends RefCounted
class_name AIMCTS

## Orquestador de Monte Carlo Tree Search con UCT para la IA (Fase C, Versión 3).
##
## Búsqueda hacia adelante de información imperfecta (SO-ISMCTS):
##   - El árbol explora secuencias de jugadas DENTRO del turno actual.
##   - El rollout proyecta `mcts_rollout_depth` turnos futuros con la política
##     configurada (heurística o aleatoria).
##   - Cada iteración samplea una determinización de la mano del rival
##     (AIDeterminizer) que el rollout usa para proyectar la respuesta rival.
##     Promediar sobre muchas determinizaciones es la esencia de SO-ISMCTS.
##
## Acotación del factor de ramificación (PLAN_IA_COMPLETO §2.1):
##   - Abstracción por carta: las N·M opciones reales (carta × target) se
##     colapsan en una por carta. La AIPlayOption concreta devuelta es la de
##     mayor score heurístico dentro de ese grupo (la heurística de Fase B
##     decide el "cómo", MCTS decide el "qué" y el "cuándo").
##   - Action pruning: tope de K moves en la raíz por score heurístico.
##
## Integración: 1 jugador humano vs 1 IA (§8.1) → árbol de 2 agentes, sin Maxn.
## Devuelve una AIPlayOption real para que AIController la ejecute.
##
## Rendimiento: síncrono en GDScript (sin thread). Acotado por mcts_iterations
## y la abstracción de acciones. El threading queda como optimización futura
## (PLAN_IA_COMPLETO §2.5 / riesgos).


## Resultado de la búsqueda, con métricas para logging/depuración.
class Result:
	var best_option: AIPlayOption = null   ## null → el controller usa la heurística
	var iterations: int = 0
	var root_visits: int = 0
	var root_children: int = 0
	var best_avg_value: float = 0.0
	var chose_pass: bool = false


## Punto de entrada. `real_options` son las AIPlayOption legales del turno
## (incluyendo el PASS que añade el controller). `ctx` debe tener la caché de
## decisión preparada (AIHeuristic.prepare_decision_cache) para que los scores
## de pruning y el estado raíz sean precisos.
static func search(real_options: Array[AIPlayOption], ctx: AITurnContext,
		config: AIConfig, rng: RandomNumberGenerator) -> Result:
	var result := Result.new()
	if config == null:
		return result

	var root_state := AIGameState.from_context(ctx)

	# --- Construcción de los moves de la raíz (abstracción + pruning) --------
	var root_moves := _build_root_moves(real_options, root_state, ctx,
			config.mcts_action_pruning_k)
	# Sin acciones reales modelables → que decida la heurística del controller.
	var has_card_move := false
	for mv in root_moves:
		if mv.get("kind", "") == "abstract":
			has_card_move = true
			break
	if not has_card_move:
		return result

	var root_hand: Array[Card] = []
	for mv in root_moves:
		if mv.get("kind", "") == "abstract":
			root_hand.append(mv["card"])

	var root := AIMCTSNode.create(root_state, root_hand)
	root.untried_moves = root_moves

	# --- Determinización del deck rival (una vez; se samplea por iteración) --
	var known_deck: Array[Card] = []
	var rival_hand_size := root_state.rival_hand_size
	if ctx.world_view != null:
		var rival_view := ctx.world_view.get_rival_view()
		if rival_view != null:
			known_deck = AIDeterminizer.build_known_deck(rival_view, ctx.deck_observer)

	# --- Bucle MCTS ----------------------------------------------------------
	var iterations := maxi(config.mcts_iterations, 1)
	for _i in range(iterations):
		# Determinización de esta iteración (SO-ISMCTS).
		var rival_hand := AIDeterminizer.sample(known_deck, rival_hand_size, rng)

		# 1) Selección: descender por UCB1 hasta una hoja o un nodo expandible.
		var path: Array[AIMCTSNode] = [root]
		var node := root
		while not node.is_leaf() and node.is_fully_expanded():
			var next := node.best_uct_child(config.mcts_exploration_c)
			if next == null:
				break
			node = next
			path.append(node)

		# 2) Expansión: si quedan moves sin probar, crear un hijo nuevo.
		if not node.is_leaf() and not node.is_fully_expanded():
			node = _expand(node, rng)
			path.append(node)

		# 3) Rollout/simulación desde el nodo alcanzado.
		var value := _rollout(node, config, rng, rival_hand)

		# 4) Retropropagación a lo largo del camino raíz→hoja.
		for n in path:
			n.visits += 1
			n.value_sum += value

	# --- Selección de la jugada final (robust child) -------------------------
	result.iterations = iterations
	result.root_visits = root.visits
	result.root_children = root.children.size()
	var best := root.most_visited_child()
	if best == null:
		return result
	result.best_avg_value = best.avg_value()
	if best.move.get("kind", "") == "pass":
		result.best_option = AIPlayOption.create_pass()
		result.chose_pass = true
	else:
		result.best_option = best.move.get("real", null)
	return result


# ---------------------------------------------------------------------------
# Construcción de moves
# ---------------------------------------------------------------------------

## Agrupa las opciones reales por carta (identidad), elige la mejor instancia
## por score heurístico, mapea cada grupo a su opción abstracta y poda a K.
## Añade siempre un move PASS al final (no se poda).
static func _build_root_moves(real_options: Array[AIPlayOption],
		root_state: AIGameState, ctx: AITurnContext, k: int) -> Array:
	# Agrupar por carta: card -> { real, score }
	var groups := {}
	for opt in real_options:
		if opt == null or opt.is_pass or opt.card == null:
			continue
		var sc := AIHeuristic.score_option(opt, ctx)
		if not groups.has(opt.card) or sc > float(groups[opt.card]["score"]):
			groups[opt.card] = { "real": opt, "score": sc }

	var moves: Array = []
	for card in groups.keys():
		var abstract := AISimulator.abstract_option_for_card(card, root_state)
		if abstract.is_empty():
			abstract = _neutral_abstract(card)
		moves.append({
			"kind": "abstract",
			"abstract": abstract,
			"card": card,
			"real": groups[card]["real"],
			"score": float(groups[card]["score"]),
		})

	# Action pruning: top-K por score heurístico.
	moves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"]))
	if k > 0 and moves.size() > k:
		moves.resize(k)

	moves.append({ "kind": "pass" })
	return moves


## Moves de un nodo interno (sin AIPlayOption real: solo abstracción + PASS).
## Una entrada por carta restante en la mano + PASS.
static func _generate_child_moves(state: AIGameState, hand: Array[Card]) -> Array:
	var moves: Array = []
	for card in hand:
		var abstract := AISimulator.abstract_option_for_card(card, state)
		if abstract.is_empty():
			abstract = _neutral_abstract(card)
		moves.append({ "kind": "abstract", "abstract": abstract, "card": card })
	moves.append({ "kind": "pass" })
	return moves


## Opción abstracta neutra (sin deltas) para cartas no modeladas por el
## simulador (CardDraw, Recover…). Mantiene la carta seleccionable en el árbol
## y consume su slot de mano, pero no altera las magnitudes del estado.
static func _neutral_abstract(card: Card) -> Dictionary:
	return {
		"type": "OTHER", "card": card, "gold_cost": 0,
		"gold_per_turn_delta": 0, "food_delta": 0,
		"tiles_delta": 0, "troop_power_delta": 0.0, "gold_immediate": 0,
	}


# ---------------------------------------------------------------------------
# Expansión y rollout
# ---------------------------------------------------------------------------

static func _expand(node: AIMCTSNode, rng: RandomNumberGenerator) -> AIMCTSNode:
	var mv: Dictionary = node.untried_moves.pop_back()
	var child_state := node.state.clone()
	var child_hand: Array[Card] = node.hand.duplicate()
	var turn_end := false

	if mv.get("kind", "") == "pass":
		turn_end = true
	else:
		AISimulator.apply_abstract(child_state, mv["abstract"])
		var card: Card = mv.get("card", null)
		if card != null:
			child_hand.erase(card)
		# CardDraw: añade cartas a la mano de este turno (tempo) para que la rama
		# "robar" lleve a estados con más jugadas → el árbol valore CardDraw.
		var abstract: Dictionary = mv["abstract"]
		if abstract.get("type", "") == "DRAW" and not child_state.own_deck.is_empty():
			for _j in range(int(abstract.get("draw_count", 1))):
				child_hand.append(
					child_state.own_deck[rng.randi_range(0, child_state.own_deck.size() - 1)])
		if child_hand.is_empty():
			turn_end = true

	var child := AIMCTSNode.create(child_state, child_hand)
	child.move = mv
	child.is_turn_end = turn_end
	if not turn_end:
		child.untried_moves = _generate_child_moves(child_state, child_hand)
	node.children.append(child)
	return child


## Estima el valor del nodo: termina la mano del turno actual (si queda),
## proyecta la respuesta rival determinizada y simula `mcts_rollout_depth`
## turnos futuros. Devuelve evaluate() del estado final en [-1, 1].
static func _rollout(node: AIMCTSNode, config: AIConfig,
		rng: RandomNumberGenerator, rival_hand: Array[Card]) -> float:
	var s := node.state.clone()
	var use_heuristic := config.mcts_heuristic_rollout

	# Terminar la mano del turno en curso (los ingresos ya están en el estado raíz).
	if not node.is_turn_end and not node.hand.is_empty():
		AISimulator.play_hand(s, node.hand, use_heuristic, rng)

	# El rival responde al turno que acabamos de cerrar.
	AISimulator.simulate_rival_turn(s, rival_hand, rng)
	if AISimulator.is_terminal(s):
		return AISimulator.evaluate(s)

	# Lookahead a turnos futuros (alternancia propio/rival).
	for _d in range(maxi(config.mcts_rollout_depth, 0)):
		s = AISimulator.simulate_turn(s, use_heuristic, rng)
		AISimulator.simulate_rival_turn(s, rival_hand, rng)
		if AISimulator.is_terminal(s):
			break

	return AISimulator.evaluate(s)
