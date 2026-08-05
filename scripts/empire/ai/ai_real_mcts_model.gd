extends RefCounted
class_name AIRealMCTSModel

## El MODELO DE JUEGO que consulta la búsqueda: qué jugadas existen y con qué
## prior, qué le hace una jugada al estado, cómo se juega un rollout hasta la
## hoja y cómo se roban las manos.
##
## Está separado de AIRealMCTS porque son dos cosas que cambian por motivos
## distintos: allí vive el algoritmo (PUCT, retropropagación, presupuesto), que
## es genérico y no sabe de este juego; aquí, todo lo que sí sabe de cartas,
## turnos y economía. Tocar el balance del juego afecta a este fichero; tocar la
## fórmula de exploración, al otro.


const OWNER_SELF := AIRealState.OWNER_SELF
const OWNER_RIVAL := AIRealState.OWNER_RIVAL


## Una jugada candidata con su prior, producida por _entries.
class Entry:
	var move: AIRealOptions.Move
	var raw: float = 0.0
	var prior: float = 0.0


# ---------------------------------------------------------------------------
# Generación de jugadas + prior (top-K)
# ---------------------------------------------------------------------------

## Jugadas legales del jugador en el estado, podadas a top-K por el prior fuerte
## (AIRealEvalStrong.score_move) y con prior P normalizado (proporcional a ese
## score si heurístico; uniforme si no). Siempre incluye PASS (no se poda).
## Si `root_priors` no está vacío, el prior crudo de cada jugada sale de ahí
## (heurística real score_option, vía move_key); las jugadas sin entrada caen al
## prior fuerte del snapshot. Es el prior HÍBRIDO de la raíz.
static func _entries(state: AIRealState, hand: Array[Card], player: int,
		config: AIConfig, root_priors: Dictionary = {}) -> Array[Entry]:
	var raw_moves := AIRealOptions.enumerate(state, hand, player)
	var use_root := not root_priors.is_empty()
	# Pesos de la heurística que guían el MCTS a TODA profundidad (prior/rollout):
	# los del config (campeón desplegado) o el default si no hay ninguno.
	var w := config.heuristic_weights if config.heuristic_weights != null else HeuristicWeights.get_default()
	var scored: Array[Entry] = []
	for m in raw_moves:
		var e := Entry.new()
		e.move = m
		if use_root:
			e.raw = root_priors.get(AIRealMCTSNode.move_key(m),
				AIRealEvalStrong.score_move(m, state, player, w))
		else:
			e.raw = AIRealEvalStrong.score_move(m, state, player, w)
		scored.append(e)
	scored.sort_custom(func(a: Entry, b: Entry) -> bool: return a.raw > b.raw)
	var k := config.mcts_action_pruning_k
	if k > 0 and scored.size() > k:
		scored.resize(k)

	var pass_e := Entry.new()
	pass_e.move = AIRealOptions.Move.pass_move()
	pass_e.raw = 0.0
	scored.append(pass_e)

	if config.mcts_heuristic_rollout:
		var sum := 0.0
		for e in scored:
			sum += maxf(e.raw, 0.0) + 0.01
		for e in scored:
			e.prior = (maxf(e.raw, 0.0) + 0.01) / sum
	else:
		var uniform := 1.0 / float(scored.size())
		for e in scored:
			e.prior = uniform
	return scored


static func _max_prior_entry(entries: Array[Entry]) -> Entry:
	var best := entries[0]
	for i in range(1, entries.size()):
		if entries[i].prior > best.prior:
			best = entries[i]
	return best



# ---------------------------------------------------------------------------
# Transición de jugada y de turno/ronda
# ---------------------------------------------------------------------------

## Aplica `move` sobre `state` (in-place) y devuelve el siguiente
## {player, hand, depth, leaf}. Encadena dentro del turno; al cerrar el turno
## propio pasa al rival (mano determinizada); al cerrar el del rival ejecuta
## advance_turn (economía/ingresos/frentes/evento) y avanza de ronda.
static func _apply_and_transition(state: AIRealState, move: AIRealOptions.Move,
		player: int, hand: Array[Card], depth: int, known_deck: Array[Card],
		rival_hand_size: int, config: AIConfig, rng: RandomNumberGenerator,
		process_events: bool = true) -> Dictionary:
	var turn_ends := false
	if move.kind == &"PASS":
		turn_ends = true
	else:
		AIRealOptions.apply(state, move, player, rng)
		if move.card != null:
			hand.erase(move.card)
		if move.kind == &"CARD_DRAW":
			_draw_into(hand, _deck_of(state, player), move.amount, rng)
		if hand.is_empty():
			turn_ends = true

	if not turn_ends:
		return {"player": player, "hand": hand, "depth": depth, "leaf": false}

	if player == OWNER_SELF:
		var rival_hand := AIDeterminizer.sample(known_deck, rival_hand_size, rng)
		return {"player": OWNER_RIVAL, "hand": rival_hand, "depth": depth, "leaf": false}

	# El rival cerró su turno → fin de ronda: economía/ingresos/frentes/evento.
	AIRealSimulator.advance_turn(state, rng, process_events, config.heuristic_weights)
	var d2 := depth + 1
	var empty: Array[Card] = []
	if d2 >= maxi(config.mcts_rollout_depth, 1) or AIRealEval.is_terminal(state):
		return {"player": OWNER_SELF, "hand": empty, "depth": d2, "leaf": true}
	return {"player": OWNER_SELF, "hand": _draw_hand(state.own, rng), "depth": d2, "leaf": false}



# ---------------------------------------------------------------------------
# Rollout
# ---------------------------------------------------------------------------

## Juega desde (state, player, hand, depth) con la política configurada hasta
## alcanzar la profundidad D o un estado terminal, y devuelve score_state.
static func _rollout(state: AIRealState, player: int, hand: Array[Card], depth: int,
		known_deck: Array[Card], rival_hand_size: int, config: AIConfig,
		rng: RandomNumberGenerator) -> float:
	var use_heuristic := config.mcts_heuristic_rollout
	var d_limit := maxi(config.mcts_rollout_depth, 1)
	var guard := 0
	while depth < d_limit and not AIRealEval.is_terminal(state) and guard < 256:
		guard += 1
		var entries := _entries(state, hand, player, config)
		var pick := _policy_pick(entries, use_heuristic, rng)
		# process_events=false: el rollout omite los eventos (caros) — es una
		# estimación; el árbol sí los modela en sus transiciones de ronda.
		var tr := _apply_and_transition(state, pick.move, player, hand, depth,
			known_deck, rival_hand_size, config, rng, false)
		player = tr["player"]; hand = tr["hand"]; depth = tr["depth"]
	return AIRealEval.score_state(state, config.heuristic_weights)


## Política de rollout: greedy por score_move (heurístico) o aleatoria.
static func _policy_pick(entries: Array[Entry], use_heuristic: bool,
		rng: RandomNumberGenerator) -> Entry:
	if not use_heuristic:
		return entries[rng.randi_range(0, entries.size() - 1)]
	var best := entries[0]
	for i in range(1, entries.size()):
		if entries[i].raw > best.raw:
			best = entries[i]
	return best



# ---------------------------------------------------------------------------
# Manos / mazos
# ---------------------------------------------------------------------------

static func _deck_of(state: AIRealState, player: int) -> Array[Card]:
	return state.own.deck if player == OWNER_SELF else state.rival.deck


## Roba `amount` cartas del mazo a la mano del turno (tempo de CardDraw). Mazo
## circular (puede repetir), igual que el modelo de v1.
static func _draw_into(hand: Array[Card], deck: Array[Card], amount: int,
		rng: RandomNumberGenerator) -> void:
	if deck.is_empty():
		return
	for _j in range(maxi(amount, 0)):
		hand.append(deck[rng.randi_range(0, deck.size() - 1)])


## Samplea cards_per_turn cartas del mazo del imperio (Fisher-Yates parcial),
## como la mano de un nuevo turno. Mazo tratado como circular (sin extraer).
static func _draw_hand(emp: AIRealState.EmpireSnap, rng: RandomNumberGenerator) -> Array[Card]:
	if emp.deck.is_empty() or emp.cards_per_turn <= 0:
		return [] as Array[Card]
	var pool: Array[Card] = emp.deck.duplicate()
	var n := mini(emp.cards_per_turn, pool.size())
	for i in range(pool.size() - 1, pool.size() - n - 1, -1):
		var j := rng.randi_range(0, i)
		var tmp: Card = pool[i]; pool[i] = pool[j]; pool[j] = tmp
	return pool.slice(pool.size() - n, pool.size())
