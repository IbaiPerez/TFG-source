extends GutTest

## Tests para AIMCTSNode y AIMCTS (Fase C — búsqueda MCTS/UCT).


# ============================================================
#  Helpers
# ============================================================

func _make_state(own_tiles: int = 10, own_gpt: int = 200,
		rival_tiles: int = 8) -> AIGameState:
	var s := AIGameState.new()
	s.own_tiles           = own_tiles
	s.own_gold            = 200
	s.own_gold_per_turn   = own_gpt
	s.own_food            = 10
	s.own_troop_power     = 30.0
	s.own_cards_per_turn  = 3
	s.rival_tiles         = rival_tiles
	s.rival_gold_per_turn = 150
	s.rival_hand_size     = 2
	s.rival_troop_power   = 20.0
	s.turn_number         = 10
	s.total_map_tiles     = 100
	s.colonizable_count   = 5
	s.buildable_slots     = 3
	return s


func _make_rng(seed_val: int = 42) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	return r


func _make_config(iters: int = 200, depth: int = 1,
		heuristic_rollout: bool = true, k: int = 12) -> AIConfig:
	var cfg := AIConfig.new()
	cfg.mode = AIConfig.Mode.MCTS
	cfg.mcts_iterations = iters
	cfg.mcts_rollout_depth = depth
	cfg.mcts_heuristic_rollout = heuristic_rollout
	cfg.mcts_action_pruning_k = k
	cfg.mcts_exploration_c = 1.41421356
	return cfg


## Tiles "dummy" para contar territorio. Inicializa los campos que la caché de
## decisión recorre (neighbors/buildings) para no romper prepare_decision_cache.
func _make_tiles(n: int) -> Array[Tile]:
	var arr: Array[Tile] = []
	for _i in range(n):
		var t := Tile.new()
		t.neighbors = []
		t.buildings = []
		t.max_buildings = 0
		add_child_autofree(t)
		arr.append(t)
	return arr


func _make_stats(p_gpt: int = 200, p_food: int = 10, p_gold: int = 200,
		own_tiles: int = 10) -> Stats:
	var s := Stats.new()
	s.total_gold = p_gold
	s.gold_per_turn = p_gpt
	s.food = p_food
	s.cards_per_turn = 3
	s.turn_number = 10  # MID
	s.deck = CardPile.new()
	s.draw_pile = CardPile.new()
	s.discard_pile = CardPile.new()
	s.played_pile = CardPile.new()
	s.empire = Empire.new()
	s.empire.name = "TestAI"
	s.empire.controlled_tiles = _make_tiles(own_tiles)
	s.troop_pool = []
	s.possible_buildings = []
	return s


func _make_ctx(stats: Stats, colonizable: int = 5,
		total_tiles: int = 100) -> AITurnContext:
	var ctx := AITurnContext.new()
	ctx.stats = stats
	ctx.rng = _make_rng()
	ctx.drawn_cards = []
	ctx.colonizable_tiles_count = colonizable
	ctx.total_map_tiles = total_tiles
	ctx.config = _make_config()
	return ctx


## Adjunta un rival con info pública (territorio dado) al world_view del ctx.
## Necesario para que AIGameState.from_context fije rival_tiles > 0: sin rival,
## evaluate() ve rival_tiles == 0 → 1.0 (victoria) y aplana toda la señal.
func _attach_rival(ctx: AITurnContext, rival_tiles: int = 8) -> void:
	var rival_empire := Empire.new()
	rival_empire.name = "Rival"
	rival_empire.controlled_tiles = _make_tiles(rival_tiles)
	var pub := AIEmpirePublicView.new()
	pub.empire = rival_empire
	pub.gold_per_turn = 150
	pub.hand_size = 2
	pub.deck_size = 0
	pub.known_deck = []
	var wv := AIWorldView.new()
	wv.own_stats = ctx.stats
	wv.rival_views = [pub]
	ctx.world_view = wv


func _make_colonize_card() -> ColonizeCard:
	var c := ColonizeCard.new()
	c.id = "colonize"
	return c


func _make_gold_card(amount: int = 50, id: String = "gold") -> GenerateGoldCard:
	var c := GenerateGoldCard.new()
	c.id = id
	c.amount = amount
	return c


# ============================================================
#  AIMCTSNode — básico
# ============================================================

func test_node_create_sets_fields() -> void:
	var s := _make_state()
	var n := AIMCTSNode.create(s, [])
	assert_eq(n.state, s)
	assert_eq(n.visits, 0)
	assert_eq(n.value_sum, 0.0)


func test_node_avg_value_zero_when_unvisited() -> void:
	var n := AIMCTSNode.create(_make_state(), [])
	assert_eq(n.avg_value(), 0.0)


func test_node_avg_value_computed() -> void:
	var n := AIMCTSNode.create(_make_state(), [])
	n.visits = 4
	n.value_sum = 2.0
	assert_almost_eq(n.avg_value(), 0.5, 0.0001)


func test_node_is_fully_expanded() -> void:
	var n := AIMCTSNode.create(_make_state(), [])
	n.untried_moves = [{ "kind": "pass" }]
	assert_false(n.is_fully_expanded())
	n.untried_moves = []
	assert_true(n.is_fully_expanded())


func test_node_best_uct_prefers_unvisited() -> void:
	var parent := AIMCTSNode.create(_make_state(), [])
	parent.visits = 10
	var visited := AIMCTSNode.create(_make_state(), [])
	visited.visits = 5
	visited.value_sum = 4.0  # avg 0.8
	var fresh := AIMCTSNode.create(_make_state(), [])  # 0 visitas → INF
	parent.children = [visited, fresh]
	assert_eq(parent.best_uct_child(1.41), fresh,
		"Un hijo sin visitas tiene prioridad infinita")


func test_node_best_uct_prefers_higher_value_when_equal_visits() -> void:
	var parent := AIMCTSNode.create(_make_state(), [])
	parent.visits = 20
	var a := AIMCTSNode.create(_make_state(), [])
	a.visits = 10; a.value_sum = 8.0   # avg 0.8
	var b := AIMCTSNode.create(_make_state(), [])
	b.visits = 10; b.value_sum = 2.0   # avg 0.2
	parent.children = [a, b]
	assert_eq(parent.best_uct_child(1.41), a,
		"Con igual exploración, gana el de mayor valor medio")


func test_node_most_visited_child() -> void:
	var parent := AIMCTSNode.create(_make_state(), [])
	var a := AIMCTSNode.create(_make_state(), [])
	a.visits = 10
	var b := AIMCTSNode.create(_make_state(), [])
	b.visits = 25
	parent.children = [a, b]
	assert_eq(parent.most_visited_child(), b)


# ============================================================
#  AIMCTS — búsqueda
# ============================================================

func test_search_returns_null_when_only_pass() -> void:
	var stats := _make_stats()
	var ctx := _make_ctx(stats)
	var pass_opt := AIPlayOption.create_pass()
	var opts: Array[AIPlayOption] = [pass_opt]
	var result := AIMCTS.search(opts, ctx, ctx.config, _make_rng())
	assert_null(result.best_option,
		"Sin acciones de carta, MCTS delega en la heurística (best_option null)")


func test_search_returns_a_real_option() -> void:
	var stats := _make_stats(200, 10, 200, 10)
	var ctx := _make_ctx(stats, 5, 100)
	_attach_rival(ctx, 8)
	var card := _make_colonize_card()
	ctx.drawn_cards = [card]
	AIHeuristic.prepare_decision_cache(ctx)

	var opt := AIPlayOption.simple(card, [])
	var opts: Array[AIPlayOption] = [opt, AIPlayOption.create_pass()]
	var result := AIMCTS.search(opts, ctx, ctx.config, _make_rng())
	assert_not_null(result.best_option, "Debe devolver una jugada")
	assert_gt(result.iterations, 0)
	assert_gt(result.root_visits, 0)


func test_search_prefers_colonize_over_pass() -> void:
	# Colonizar añade tiles (mejor evaluate) → debe ganar a PASS.
	var stats := _make_stats(200, 10, 200, 10)
	var ctx := _make_ctx(stats, 8, 100)
	_attach_rival(ctx, 8)
	var card := _make_colonize_card()
	ctx.drawn_cards = [card]
	AIHeuristic.prepare_decision_cache(ctx)

	var opt := AIPlayOption.simple(card, [])
	var opts: Array[AIPlayOption] = [opt, AIPlayOption.create_pass()]
	var result := AIMCTS.search(opts, ctx, _make_config(300, 2), _make_rng())
	assert_false(result.chose_pass,
		"Con tiles colonizables, MCTS no debe elegir PASS")
	assert_eq(result.best_option.card, card,
		"Debe devolver la opción de colonizar")


func test_search_is_deterministic_with_same_seed() -> void:
	var stats := _make_stats(200, 10, 200, 10)
	var ctx := _make_ctx(stats, 5, 100)
	_attach_rival(ctx, 8)
	var card := _make_colonize_card()
	ctx.drawn_cards = [card]
	AIHeuristic.prepare_decision_cache(ctx)
	var opt := AIPlayOption.simple(card, [])
	var opts: Array[AIPlayOption] = [opt, AIPlayOption.create_pass()]

	var r1 := AIMCTS.search(opts, ctx, ctx.config, _make_rng(99))
	var r2 := AIMCTS.search(opts, ctx, ctx.config, _make_rng(99))
	assert_eq(r1.chose_pass, r2.chose_pass,
		"Con el mismo seed, la decisión debe ser idéntica")
	assert_eq(r1.root_visits, r2.root_visits)


func test_search_respects_action_pruning_k() -> void:
	# 20 cartas distintas, K=3 → la raíz expande a lo sumo 3 acciones + PASS.
	var stats := _make_stats(200, 10, 200, 10)
	var ctx := _make_ctx(stats, 0, 100)
	_attach_rival(ctx, 8)
	var opts: Array[AIPlayOption] = []
	var hand: Array[Card] = []
	for i in range(20):
		var c := _make_gold_card(50, "gold_%d" % i)
		hand.append(c)
		opts.append(AIPlayOption.simple(c, []))
	ctx.drawn_cards = hand
	AIHeuristic.prepare_decision_cache(ctx)
	opts.append(AIPlayOption.create_pass())

	var result := AIMCTS.search(opts, ctx, _make_config(300, 1, true, 3), _make_rng())
	assert_lte(result.root_children, 4,
		"Con K=3 la raíz no debe expandir más de 3 acciones + PASS")


func test_search_random_rollout_still_works() -> void:
	var stats := _make_stats(200, 10, 200, 10)
	var ctx := _make_ctx(stats, 5, 100)
	_attach_rival(ctx, 8)
	var card := _make_colonize_card()
	ctx.drawn_cards = [card]
	AIHeuristic.prepare_decision_cache(ctx)
	var opt := AIPlayOption.simple(card, [])
	var opts: Array[AIPlayOption] = [opt, AIPlayOption.create_pass()]

	var result := AIMCTS.search(opts, ctx, _make_config(100, 2, false), _make_rng())
	assert_not_null(result.best_option,
		"La política de rollout aleatoria debe completar sin errores")


func test_search_zero_rollout_depth_immediate_eval() -> void:
	# rollout_depth=0 → evaluación inmediata, sin lookahead. Debe funcionar.
	var stats := _make_stats(200, 10, 200, 10)
	var ctx := _make_ctx(stats, 5, 100)
	_attach_rival(ctx, 8)
	var card := _make_colonize_card()
	ctx.drawn_cards = [card]
	AIHeuristic.prepare_decision_cache(ctx)
	var opt := AIPlayOption.simple(card, [])
	var opts: Array[AIPlayOption] = [opt, AIPlayOption.create_pass()]

	var result := AIMCTS.search(opts, ctx, _make_config(100, 0), _make_rng())
	assert_not_null(result.best_option)
	assert_true(result.best_avg_value >= -1.0 and result.best_avg_value <= 1.0,
		"El valor medio debe estar en [-1, 1]")
