extends RefCounted
class_name AIRealMCTS

## Orquestador MCTS v2 sobre estado real: SO-ISMCTS canónico
## con árbol ALTERNANTE de 2 agentes (▲ IA / ▽ rival), PUCT con availability
## count y backup negamax.
##
## Estructura del árbol:
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
##            la misma fórmula que score_option, a TODA profundidad), política de
##            rollout igual.
##   false → prior uniforme (1/K), política de rollout aleatoria.
## (La alternancia ▲▽ del árbol es estructural y no depende del interruptor.)
##
## El prior y el rollout usan AIRealEvalStrong (heurística fuerte sobre el
## snapshot), no la aproximación AIRealEval.score_move: la guía heurística es el
## ingrediente decisivo medido, así que actúa en todo el árbol y no solo en la
## raíz. `root_priors` (score_option sobre el estado VIVO) se mantiene porque en
## la raíz es ground-truth y mejora sobre lo que puede ver el snapshot.

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





## Punto de entrada (puro sobre el snapshot). `own_hand` es la mano real del
## turno; `known_deck`/`rival_hand_size` alimentan la determinización del rival.
##
## `root_priors` (HÍBRIDO): mapa move_key → prior crudo para los hijos de
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
	var root := _prepare_root(root_state, own_hand, config, root_priors, reuse_root)
	result.root = root
	result.iterations = _run_budget_loop(root, root_state, own_hand, known_deck,
		rival_hand_size, config, rng, root_priors)
	_build_result(result, root)
	return result


## Raíz de la búsqueda: reutiliza el subárbol de la decisión anterior (puesto al día
## contra el nuevo estado) o crea una raíz limpia.
static func _prepare_root(root_state: AIRealState, own_hand: Array[Card],
		config: AIConfig, root_priors: Dictionary,
		reuse_root: AIRealMCTSNode) -> AIRealMCTSNode:
	if reuse_root == null:
		return AIRealMCTSNode.create(OWNER_SELF, 0)
	_reroot_refresh(reuse_root, root_state, own_hand, config, root_priors)
	return reuse_root


## Itera hasta agotar el presupuesto. Devuelve las iteraciones NUEVAS ejecutadas.
static func _run_budget_loop(root: AIRealMCTSNode, root_state: AIRealState,
		own_hand: Array[Card], known_deck: Array[Card], rival_hand_size: int,
		config: AIConfig, rng: RandomNumberGenerator, root_priors: Dictionary) -> int:
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
	return done


## Lee el árbol ya construido y rellena el Result: jugada elegida, subárbol a
## reutilizar y diagnóstico de override del prior.
static func _build_result(result: Result, root: AIRealMCTSNode) -> void:
	result.root_visits = root.visits
	result.root_children = root.children.size()
	var best := root.most_visited_child()
	if best == null:
		return
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
	var entries := AIRealMCTSModel._entries(root_state, own_hand, OWNER_SELF, config, root_priors)
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
		var entries := AIRealMCTSModel._entries(state, hand, player, config, priors_here)

		# Casar jugadas disponibles con hijos ya expandidos.
		var avail_children: Array[AIRealMCTSNode] = []
		var untried: Array[AIRealMCTSModel.Entry] = []
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
			var e := AIRealMCTSModel._max_prior_entry(untried)
			var child := AIRealMCTSNode.create(player, depth)
			child.move = e.move
			child.prior = e.prior
			node.add_child(child, AIRealMCTSNode.move_key(e.move))
			availed.append(child)
			var tr := AIRealMCTSModel._apply_and_transition(state, e.move, player, hand, depth,
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
			var tr := AIRealMCTSModel._apply_and_transition(state, sel.move, player, hand, depth,
				known_deck, rival_hand_size, config, rng)
			player = tr["player"]; hand = tr["hand"]; depth = tr["depth"]
			path.append(sel)
			node = sel
			if bool(tr["leaf"]):
				node.is_eval_leaf = true
				break

	# Rollout desde el estado alcanzado y retropropagación negamax (valor en
	# perspectiva propia; el signo se invierte al seleccionar en nodos ▽).
	var value := AIRealMCTSModel._rollout(state, player, hand, depth, known_deck, rival_hand_size, config, rng)
	_backup(path, availed, value)


## Retropropagación: suma visitas y valor por el camino recorrido, e incrementa la
## availability de los hijos que estaban DISPONIBLES en esta iteración (SO-ISMCTS:
## el denominador del PUCT es cuántas veces se pudo elegir la jugada, no cuántas
## veces se visitó el nodo).
static func _backup(path: Array[AIRealMCTSNode], availed: Array[AIRealMCTSNode],
		value: float) -> void:
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

