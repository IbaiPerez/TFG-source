extends RefCounted
class_name AIRealMCTS

## Orquestador MCTS v2 sobre estado real (Fase C v2 — F3b): SO-ISMCTS canónico
## con árbol ALTERNANTE de 2 agentes (▲ IA / ▽ rival), PUCT con availability
## count y backup negamax. Reemplaza al AIMCTS v1 (modelo abstracto).
##
## Estructura del árbol (PLAN §4):
##   ▲ (IA, maximiza) encadena colocaciones → fin turno
##     → ▽ (rival, minimiza valor propio) encadena su mano DETERMINIZADA → fin turno
##       → AZAR (advance_turn: economía/ingresos/frentes/EVENTO) → ▲ ... hasta D rondas
##         → hoja: score_state.
##
## ISMCTS: los nodos son conjuntos de información (sin estado almacenado). Cada
## iteración samplea una determinización (manos del rival y nuestras futuras +
## resultados de advance_turn vía rng) y re-deriva el estado aplicando las
## jugadas del camino. La availability count corrige el sesgo del bandido de
## subconjunto en los nodos del rival (Cowling 2012 §IV-B).
##
## Interruptor `mcts_heuristic_rollout` (AIConfig):
##   true  → prior P = AIRealEvalStrong.score_move normalizado (heurística FUERTE,
##            espejo de score_option, a TODA profundidad), política de rollout igual.
##   false → prior uniforme (1/K), política de rollout aleatoria.
## (La alternancia ▲▽ del árbol es estructural y no depende del interruptor.)
##
## F3c.4 (2026-07-01): el prior/rollout usan AIRealEvalStrong (heurística fuerte
## sobre el snapshot) en vez de la aproximación AIRealEval.score_move — así la guía
## heurística (ingrediente decisivo medido) actúa en todo el árbol, no solo en la
## raíz. `root_priors` (score_option REAL) se mantiene: en la raíz es el suelo
## ground-truth y solo mejora sobre el espejo del snapshot.

const OWNER_SELF := AIRealState.OWNER_SELF
const OWNER_RIVAL := AIRealState.OWNER_RIVAL


## Resultado de la búsqueda, con métricas para logging/depuración.
class Result:
	var best_move: AIRealOptions.Move = null
	var iterations: int = 0
	var root_visits: int = 0
	var root_children: int = 0
	var best_avg_value: float = 0.0
	var chose_pass: bool = false
	## True si la jugada elegida (hijo más visitado) NO coincide con la de mayor
	## prior (la que elegiría la heurística). Mide cuánto la búsqueda "se aparta"
	## del prior heurístico — diagnóstico de la patología "más tiempo, peor".
	var overrode_prior: bool = false
	## Raíz del árbol explorado en esta búsqueda. El controller puede conservarla
	## para reutilizar el subárbol en la siguiente decisión del MISMO turno.
	var root: AIRealMCTSNode = null
	## Subárbol (hijo) correspondiente a `best_move`. Es lo que el controller debe
	## reutilizar como nueva raíz tras EJECUTAR `best_move` (tree persistence).
	var best_child: AIRealMCTSNode = null


## Una jugada candidata con su prior, producida por _entries.
class Entry:
	var move: AIRealOptions.Move
	var raw: float = 0.0
	var prior: float = 0.0


## Punto de entrada (puro sobre el snapshot). `own_hand` es la mano real del
## turno; `known_deck`/`rival_hand_size` alimentan la determinización del rival.
##
## `root_priors` (HÍBRIDO, F3 §4): mapa move_key → prior crudo para los hijos de
## la RAÍZ, calculado por el controller con la heurística REAL (score_option)
## sobre el contexto real. Si está vacío, el prior de la raíz usa score_move como
## el resto del árbol. Alinea la decisión raíz con la heurística fuerte (suelo).
## `reuse_root` (REUTILIZACIÓN DE SUBÁRBOL / tree persistence): si el controller
## pasa el subárbol de la jugada anterior de ESTE turno, se reutiliza como raíz —
## conserva las visitas/valor ya calculados (warm start). Dentro de un mismo turno
## las jugadas propias se ENCADENAN sin turno del rival ni advance_turn entre medias,
## así que el hijo de la jugada A₁ sigue a profundidad 0, igual que una raíz nueva:
## re-enraizar es consistente. Antes de buscar se pone al día (ver _reroot_refresh).
static func search(root_state: AIRealState, own_hand: Array[Card],
		known_deck: Array[Card], rival_hand_size: int,
		config: AIConfig, rng: RandomNumberGenerator,
		root_priors: Dictionary = {}, reuse_root: AIRealMCTSNode = null) -> Result:
	var result := Result.new()
	if config == null or root_state == null:
		return result
	var root: AIRealMCTSNode
	if reuse_root != null:
		root = reuse_root
		_reroot_refresh(root, root_state, own_hand, config, root_priors)
	else:
		root = AIRealMCTSNode.create(OWNER_SELF, 0)
	result.root = root
	var iters_cap := maxi(config.mcts_iterations, 1)
	var budget := config.mcts_time_budget_ms
	var start := Time.get_ticks_msec()
	var done := 0
	while done < iters_cap:
		_iterate(root, root_state, own_hand, known_deck, rival_hand_size, config, rng, root_priors)
		done += 1
		# Presupuesto de tiempo: para en cuanto se agota (mcts_iterations es el
		# techo de seguridad). Con budget == 0 corre las iteraciones exactas.
		if budget > 0 and Time.get_ticks_msec() - start >= budget:
			break

	result.iterations = done
	result.root_visits = root.visits
	result.root_children = root.children.size()
	var best := root.most_visited_child()
	if best == null:
		return result
	result.best_avg_value = best.avg_value()
	# Subárbol a reutilizar tras ejecutar la jugada (lo descarta el controller si
	# resulta ser PASS o si la jugada no tiene opción real correspondiente).
	result.best_child = best
	# ¿La búsqueda se apartó del prior? Comparar el hijo más visitado con el de
	# mayor prior (la elección de la heurística en la raíz).
	var top_prior: AIRealMCTSNode = null
	var top_p := -INF
	for ch in root.children:
		if ch.prior > top_p:
			top_p = ch.prior
			top_prior = ch
	result.overrode_prior = best != top_prior
	if best.move == null or best.move.kind == &"PASS":
		result.chose_pass = true
		result.best_move = AIRealOptions.Move.pass_move()
	else:
		result.best_move = best.move
	return result


# ---------------------------------------------------------------------------
# Reutilización de subárbol (tree persistence)
# ---------------------------------------------------------------------------

## Pone al día el subárbol reutilizado como nueva raíz. Tras EJECUTAR la jugada
## anterior, el estado real cambió: algunas jugadas de los hijos ya no son legales
## (o caen fuera del top-K) y los priors deben recalcularse con el prior híbrido de
## la raíz sobre el NUEVO estado. Aquí:
##   - podamos los hijos cuya jugada no aparece entre las legales del nuevo estado
##     (evita que most_visited_child devuelva una jugada ahora ilegal), y
##   - refrescamos el prior de los que se conservan, para que el PUCT sea coherente
##     con los hijos que se expandan durante esta búsqueda.
## Las visitas/valor/availability acumulados se mantienen: son el warm start.
static func _reroot_refresh(root: AIRealMCTSNode, root_state: AIRealState,
		own_hand: Array[Card], config: AIConfig, root_priors: Dictionary) -> void:
	var entries := _entries(root_state, own_hand, OWNER_SELF, config, root_priors)
	var legal := {}
	for e in entries:
		legal[AIRealMCTSNode.move_key(e.move)] = e.prior
	var kept: Array[AIRealMCTSNode] = []
	var kept_map := {}
	for ch in root.children:
		var key := AIRealMCTSNode.move_key(ch.move)
		if legal.has(key):
			ch.prior = legal[key]
			kept.append(ch)
			kept_map[key] = ch
	root.children = kept
	root.child_by_key = kept_map


# ---------------------------------------------------------------------------
# Iteración MCTS (selección → expansión → rollout → retropropagación)
# ---------------------------------------------------------------------------

static func _iterate(root: AIRealMCTSNode, root_state: AIRealState,
		own_hand: Array[Card], known_deck: Array[Card], rival_hand_size: int,
		config: AIConfig, rng: RandomNumberGenerator, root_priors: Dictionary = {}) -> void:
	var state := root_state.clone()
	var player := OWNER_SELF
	var hand: Array[Card] = own_hand.duplicate()
	var depth := 0
	var node := root
	var path: Array[AIRealMCTSNode] = [root]
	var availed: Array[AIRealMCTSNode] = []   ## hijos disponibles esta iteración → availability++
	var guard := 0

	while not node.is_eval_leaf and guard < 256:
		guard += 1
		# Solo la primera decisión (nodo raíz) usa el prior heurístico real.
		var priors_here := root_priors if node == root else {}
		var entries := _entries(state, hand, player, config, priors_here)

		# Casar jugadas disponibles con hijos ya expandidos.
		var avail_children: Array[AIRealMCTSNode] = []
		var untried: Array[Entry] = []
		for e in entries:
			var key := AIRealMCTSNode.move_key(e.move)
			if node.child_by_key.has(key):
				avail_children.append(node.child_by_key[key])
			else:
				untried.append(e)
		for ch in avail_children:
			availed.append(ch)

		if not untried.is_empty():
			# Expansión: crear el hijo de mayor prior entre los no probados.
			var e := _max_prior_entry(untried)
			var child := AIRealMCTSNode.create(player, depth)
			child.move = e.move
			child.prior = e.prior
			node.add_child(child, AIRealMCTSNode.move_key(e.move))
			availed.append(child)
			var tr := _apply_and_transition(state, e.move, player, hand, depth,
				known_deck, rival_hand_size, config, rng)
			player = tr["player"]; hand = tr["hand"]; depth = tr["depth"]
			child.is_eval_leaf = tr["leaf"]
			path.append(child)
			node = child
			break
		else:
			# Selección PUCT entre los hijos disponibles.
			var sel := _puct_select(node, avail_children, config.mcts_exploration_c)
			if sel == null:
				break
			var tr := _apply_and_transition(state, sel.move, player, hand, depth,
				known_deck, rival_hand_size, config, rng)
			player = tr["player"]; hand = tr["hand"]; depth = tr["depth"]
			path.append(sel)
			node = sel
			if bool(tr["leaf"]):
				node.is_eval_leaf = true
				break

	# Rollout desde el estado alcanzado y retropropagación negamax (valor en
	# perspectiva propia; el signo se invierte al seleccionar en nodos ▽).
	var value := _rollout(state, player, hand, depth, known_deck, rival_hand_size, config, rng)
	for n in path:
		n.visits += 1
		n.value_sum += value
	for ch in availed:
		ch.availability += 1


## Selección PUCT con availability count, en la perspectiva del jugador del nodo.
##   PUCT = Q + c · P · √(ln A / (1 + n))   (Q invertido en nodos del rival)
static func _puct_select(node: AIRealMCTSNode, avail_children: Array[AIRealMCTSNode],
		c: float) -> AIRealMCTSNode:
	var best: AIRealMCTSNode = null
	var best_score := -INF
	var minimize := node.to_move == OWNER_RIVAL
	for ch in avail_children:
		var q := ch.avg_value()
		if minimize:
			q = -q
		var a := maxi(ch.availability, 1)
		var explore := c * ch.prior * sqrt(log(float(a)) / float(1 + ch.visits))
		var score := q + explore
		if score > best_score:
			best_score = score
			best = ch
	return best


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
	AIRealSimulator.advance_turn(state, rng, process_events)
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
	return AIRealEval.score_state(state)


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
