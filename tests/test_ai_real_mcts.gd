extends GutTest

## Tests para el árbol MCTS v2 (Fase C v2 — F3b): mecánica del nodo
## (move_key, avg_value, robust child), selección PUCT con availability y
## negamax, y la búsqueda end-to-end sobre un estado construido.


func _rng(s: int = 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _config(iters: int = 120, depth: int = 3, k: int = 8,
		heuristic: bool = true) -> AIConfig:
	var c := AIConfig.new()
	c.mode = AIConfig.Mode.MCTS
	c.mcts_iterations = iters
	c.mcts_rollout_depth = depth
	c.mcts_action_pruning_k = k
	c.mcts_exploration_c = 1.0
	c.mcts_heuristic_rollout = heuristic
	return c


func _resource(gold: int, food: int) -> NaturalResource:
	var r := NaturalResource.new()
	r.gold_produced = gold
	r.food_produced = food
	return r


func _snap(id: int, owner: int, gold: int = 0,
		location: int = Tile.location_type.Village) -> AIRealState.TileSnap:
	var s := AIRealState.TileSnap.new()
	s.id = id
	s.owner = owner
	s.location_type = location
	s.max_buildings = 3
	s.natural_resource = _resource(gold, 0)
	s.resource_gold = gold
	s.neighbor_ids = []
	return s


func _move(kind: StringName, tile_id: int = -1) -> AIRealOptions.Move:
	var m := AIRealOptions.Move.new()
	m.kind = kind
	m.tile_id = tile_id
	return m


# ============================================================
#  Nodo: move_key, avg_value, robust child
# ============================================================

func test_move_key_distinguishes_target() -> void:
	var a := _move(&"COLONIZE", 1)
	var b := _move(&"COLONIZE", 1)
	var c := _move(&"COLONIZE", 2)
	assert_eq(AIRealMCTSNode.move_key(a), AIRealMCTSNode.move_key(b),
		"Misma jugada+target → misma clave")
	assert_ne(AIRealMCTSNode.move_key(a), AIRealMCTSNode.move_key(c),
		"Distinto target → distinta clave")
	assert_eq(AIRealMCTSNode.move_key(AIRealOptions.Move.pass_move()), "PASS")


func test_avg_value_and_robust_child() -> void:
	var root := AIRealMCTSNode.create(AIRealState.OWNER_SELF, 0)
	var a := AIRealMCTSNode.create(AIRealState.OWNER_SELF, 0)
	a.visits = 10; a.value_sum = 5.0
	var b := AIRealMCTSNode.create(AIRealState.OWNER_SELF, 0)
	b.visits = 3; b.value_sum = 2.0
	root.add_child(a, "a")
	root.add_child(b, "b")
	assert_almost_eq(a.avg_value(), 0.5, 0.001)
	assert_eq(root.most_visited_child(), a, "El robust child es el más visitado")


# ============================================================
#  PUCT + negamax
# ============================================================

func test_puct_self_prefers_higher_value() -> void:
	var node := AIRealMCTSNode.create(AIRealState.OWNER_SELF, 0)
	var hi := AIRealMCTSNode.create(AIRealState.OWNER_SELF, 0)
	hi.visits = 10; hi.value_sum = 8.0; hi.availability = 10; hi.prior = 0.5  # avg 0.8
	var lo := AIRealMCTSNode.create(AIRealState.OWNER_SELF, 0)
	lo.visits = 10; lo.value_sum = 1.0; lo.availability = 10; lo.prior = 0.5  # avg 0.1
	var sel := AIRealMCTS._puct_select(node, [hi, lo] as Array[AIRealMCTSNode], 1.0)
	assert_eq(sel, hi, "En nodo propio, PUCT prefiere mayor valor (mismo prior/explore)")


func test_puct_rival_minimizes_self_value() -> void:
	# Nodo del rival: minimiza el valor PROPIO → prefiere el hijo con menor avg.
	var node := AIRealMCTSNode.create(AIRealState.OWNER_RIVAL, 0)
	var good_for_self := AIRealMCTSNode.create(AIRealState.OWNER_SELF, 0)
	good_for_self.visits = 10; good_for_self.value_sum = 8.0
	good_for_self.availability = 10; good_for_self.prior = 0.5   # avg +0.8
	var bad_for_self := AIRealMCTSNode.create(AIRealState.OWNER_SELF, 0)
	bad_for_self.visits = 10; bad_for_self.value_sum = -5.0
	bad_for_self.availability = 10; bad_for_self.prior = 0.5     # avg −0.5
	var sel := AIRealMCTS._puct_select(node, [good_for_self, bad_for_self] as Array[AIRealMCTSNode], 1.0)
	assert_eq(sel, bad_for_self, "El rival elige la rama peor para nosotros (negamax)")


func test_puct_exploration_favors_unvisited_among_available() -> void:
	# Con valores iguales, mayor prior / menor visitas → más exploración.
	var node := AIRealMCTSNode.create(AIRealState.OWNER_SELF, 0)
	var visited := AIRealMCTSNode.create(AIRealState.OWNER_SELF, 0)
	visited.visits = 50; visited.value_sum = 25.0; visited.availability = 50; visited.prior = 0.3
	var fresh := AIRealMCTSNode.create(AIRealState.OWNER_SELF, 0)
	fresh.visits = 1; fresh.value_sum = 0.5; fresh.availability = 50; fresh.prior = 0.7
	var sel := AIRealMCTS._puct_select(node, [visited, fresh] as Array[AIRealMCTSNode], 2.0)
	assert_eq(sel, fresh, "Más prior y menos visitas → el término de exploración la favorece")


# ============================================================
#  Búsqueda end-to-end
# ============================================================

## Estado pequeño: 1 casilla propia productiva rodeada de casillas libres, rival
## con 1 casilla lejana. Una ColonizeCard en mano.
func _colonize_state() -> AIRealState:
	var s := AIRealState.new()
	s.total_map_tiles = 8
	s.tiles[0] = _snap(0, AIRealState.OWNER_SELF, 10)
	for i in [1, 2, 3]:
		s.tiles[i] = _snap(i, AIRealState.OWNER_NONE, 0, Tile.location_type.Uncolonized)
	s.tiles[7] = _snap(7, AIRealState.OWNER_RIVAL, 5)
	(s.tiles[0] as AIRealState.TileSnap).neighbor_ids = [1, 2, 3]
	s.own.gold = 100
	s.own.gold_per_turn = 10
	s.own.cards_per_turn = 2
	s.rival.gold_per_turn = 5
	s.rival.cards_per_turn = 2
	return s


func test_search_returns_legal_move() -> void:
	var s := _colonize_state()
	var hand: Array[Card] = [ColonizeCard.new()]
	var result := AIRealMCTS.search(s, hand, [] as Array[Card], 2, _config(), _rng())
	assert_not_null(result.best_move, "La búsqueda devuelve una jugada")
	assert_gt(result.root_visits, 0, "La raíz se visita")
	assert_gt(result.root_children, 0, "La raíz expande hijos")


func test_search_prefers_colonize_over_pass() -> void:
	var s := _colonize_state()
	var hand: Array[Card] = [ColonizeCard.new()]
	var result := AIRealMCTS.search(s, hand, [] as Array[Card], 2, _config(150), _rng())
	assert_eq(result.best_move.kind, &"COLONIZE",
		"Colonizar mejora el territorio → preferido sobre PASS")
	assert_false(result.chose_pass)


func test_search_passes_with_empty_hand() -> void:
	var s := _colonize_state()
	var result := AIRealMCTS.search(s, [] as Array[Card], [] as Array[Card], 2, _config(40), _rng())
	assert_true(result.chose_pass, "Sin cartas en mano, la búsqueda pasa")
	assert_eq(result.best_move.kind, &"PASS")


func test_search_is_deterministic_with_seed() -> void:
	var hand1: Array[Card] = [ColonizeCard.new()]
	var r1 := AIRealMCTS.search(_colonize_state(), hand1, [] as Array[Card], 2, _config(80), _rng(42))
	var hand2: Array[Card] = [ColonizeCard.new()]
	var r2 := AIRealMCTS.search(_colonize_state(), hand2, [] as Array[Card], 2, _config(80), _rng(42))
	assert_eq(r1.best_move.kind, r2.best_move.kind,
		"Misma semilla → misma decisión (tipo)")
	assert_eq(r1.best_move.tile_id, r2.best_move.tile_id,
		"Misma semilla → mismo target")


func test_search_respects_time_budget() -> void:
	# Techo de iteraciones enorme + presupuesto pequeño → para por TIEMPO.
	var s := _colonize_state()
	var hand: Array[Card] = [ColonizeCard.new()]
	var cfg := _config(1000000, 3, 8)
	cfg.mcts_time_budget_ms = 10
	var result := AIRealMCTS.search(s, hand, [] as Array[Card], 2, cfg, _rng())
	assert_not_null(result.best_move, "Devuelve jugada dentro del presupuesto")
	assert_gt(result.iterations, 0, "Ejecuta al menos una iteración")
	assert_lt(result.iterations, 1000000,
		"Para por tiempo, no por el techo de iteraciones")


func test_search_uniform_mode_runs() -> void:
	# Modo sin heurística (prior uniforme + rollout aleatorio): debe completar
	# la búsqueda sin errores y devolver una jugada legal.
	var s := _colonize_state()
	var hand: Array[Card] = [ColonizeCard.new()]
	var result := AIRealMCTS.search(s, hand, [] as Array[Card], 2,
		_config(60, 3, 8, false), _rng())
	assert_not_null(result.best_move, "El modo Monte Carlo puro también devuelve jugada")


# ============================================================
#  Reutilización de subárbol (tree persistence)
# ============================================================

func test_search_exposes_root_and_subtree() -> void:
	# La búsqueda expone su raíz y el subárbol del best_move, para que el
	# controller pueda reutilizarlo en la siguiente decisión del mismo turno.
	var s := _colonize_state()
	var hand: Array[Card] = [ColonizeCard.new()]
	var result := AIRealMCTS.search(s, hand, [] as Array[Card], 2, _config(120), _rng())
	assert_not_null(result.root, "Expone la raíz del árbol")
	assert_not_null(result.best_child, "Expone el subárbol del best_move")
	assert_true(result.root.children.has(result.best_child),
		"El subárbol reutilizable es hijo de la raíz")


func test_reuse_root_preserves_visits() -> void:
	# Warm start: al reutilizar el subárbol como raíz, conserva las visitas ya
	# acumuladas y solo SUMA las nuevas iteraciones (no empieza el árbol de cero).
	var s := _colonize_state()
	var hand: Array[Card] = [ColonizeCard.new(), ColonizeCard.new()]
	var r1 := AIRealMCTS.search(s, hand, [] as Array[Card], 2, _config(120), _rng(7))
	var warm := r1.best_child.visits
	assert_gt(warm, 0, "El subárbol acumuló visitas en la primera búsqueda")
	# Segunda decisión del MISMO turno: reutiliza el subárbol anterior.
	var hand2: Array[Card] = [ColonizeCard.new()]
	var r2 := AIRealMCTS.search(s, hand2, [] as Array[Card], 2, _config(60), _rng(7),
		{}, r1.best_child)
	assert_eq(r2.root, r1.best_child, "La raíz reutilizada es el subárbol anterior")
	assert_eq(r2.root_visits, warm + r2.iterations,
		"Conserva las visitas previas y suma las nuevas (warm start)")


func test_reroot_refresh_prunes_illegal_children() -> void:
	# Al re-enraizar, los hijos cuya jugada ya NO es legal en el nuevo estado se
	# podan, aunque tuvieran muchas visitas: evita devolver una jugada ilegal.
	var s := _colonize_state()
	var root := AIRealMCTSNode.create(AIRealState.OWNER_SELF, 0)
	var ghost := AIRealMCTSNode.create(AIRealState.OWNER_SELF, 0)
	ghost.move = _move(&"COLONIZE", 99)   # tile inexistente → ilegal
	ghost.visits = 999
	root.add_child(ghost, AIRealMCTSNode.move_key(ghost.move))
	var hand: Array[Card] = [ColonizeCard.new()]
	var r := AIRealMCTS.search(s, hand, [] as Array[Card], 2, _config(80), _rng(),
		{}, root)
	assert_false(root.child_by_key.has(AIRealMCTSNode.move_key(ghost.move)),
		"El hijo con jugada ilegal se poda al re-enraizar")
	assert_not_null(r.best_move, "Tras podar, sigue devolviendo una jugada legal")
	assert_ne(r.best_move.tile_id, 99, "Nunca elige la jugada podada")
