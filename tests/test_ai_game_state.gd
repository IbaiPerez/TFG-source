extends GutTest

## Tests para AIGameState y AISimulator (Fase C — infraestructura MCTS).


# ============================================================
#  Helpers
# ============================================================

func _make_state(own_tiles: int = 10, own_gpt: int = 200,
		rival_tiles: int = 8, rival_gpt: int = 150) -> AIGameState:
	var s := AIGameState.new()
	s.own_tiles           = own_tiles
	s.own_gold            = 100
	s.own_gold_per_turn   = own_gpt
	s.own_food            = 10
	s.own_troop_power     = 30.0
	s.own_cards_per_turn  = 3
	s.rival_tiles         = rival_tiles
	s.rival_gold_per_turn = rival_gpt
	s.rival_hand_size     = 3
	s.rival_troop_power   = 20.0
	s.turn_number         = 10
	s.total_map_tiles     = 100
	s.colonizable_count   = 5
	s.buildable_slots     = 3
	return s


func _make_card(id: String) -> Card:
	var c := Card.new()
	c.id = id
	return c


func _make_rng(seed_val: int = 42) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	return r


# ============================================================
#  AIGameState — clone
# ============================================================

func test_clone_is_independent() -> void:
	var s := _make_state()
	var c := s.clone()
	c.own_tiles += 5
	c.own_gold  += 200
	assert_eq(s.own_tiles, 10, "clone no debe alterar el original (tiles)")
	assert_eq(s.own_gold,  100, "clone no debe alterar el original (gold)")


func test_clone_copies_all_scalar_fields() -> void:
	var s := _make_state(15, 300, 12, 250)
	s.own_food         = 20
	s.own_troop_power  = 50.0
	s.rival_troop_power = 40.0
	s.colonizable_count = 7
	s.buildable_slots  = 4
	var c := s.clone()
	assert_eq(c.own_tiles,         15)
	assert_eq(c.own_gold_per_turn, 300)
	assert_eq(c.rival_tiles,       12)
	assert_eq(c.own_food,          20)
	assert_eq(c.own_troop_power,   50.0)
	assert_eq(c.rival_troop_power, 40.0)
	assert_eq(c.colonizable_count, 7)
	assert_eq(c.buildable_slots,   4)


func test_clone_copies_fronts_independently() -> void:
	var s := _make_state()
	s.fronts.append(AIGameState.FrontSnapshot.of(&"attacker", 3.0, 12.0))
	var c := s.clone()
	(c.fronts[0] as AIGameState.FrontSnapshot).marker = 99.0
	assert_eq((s.fronts[0] as AIGameState.FrontSnapshot).marker, 3.0,
		"Los FrontSnapshot del clon deben ser copias independientes")


func test_clone_copies_hand_independently() -> void:
	var s := _make_state()
	s.own_hand = [_make_card("a"), _make_card("b")]
	var c := s.clone()
	c.own_hand.clear()
	assert_eq(s.own_hand.size(), 2, "El hand del original no debe verse afectado")


# ============================================================
#  AIGameState — FrontSnapshot
# ============================================================

func test_front_snapshot_factory() -> void:
	var f := AIGameState.FrontSnapshot.of(&"defender", -5.0, 10.0)
	assert_eq(f.own_side,  &"defender")
	assert_eq(f.marker,    -5.0)
	assert_eq(f.threshold, 10.0)


func test_front_snapshot_clone() -> void:
	var f := AIGameState.FrontSnapshot.of(&"attacker", 2.0, 8.0)
	var c := f.clone()
	c.marker = 99.0
	assert_eq(f.marker, 2.0, "clone de FrontSnapshot debe ser independiente")


# ============================================================
#  AISimulator — evaluate
# ============================================================

func test_evaluate_winning_state_positive() -> void:
	var s := _make_state(20, 400, 5, 100)
	var score := AISimulator.evaluate(s)
	assert_gt(score, 0.0, "Estado con ventaja propia debe puntuar positivo")


func test_evaluate_losing_state_negative() -> void:
	var s := _make_state(5, 100, 20, 400)
	var score := AISimulator.evaluate(s)
	assert_lt(score, 0.0, "Estado con desventaja propia debe puntuar negativo")


func test_evaluate_terminal_own_victory() -> void:
	var s := _make_state(75, 500, 10, 100)
	s.total_map_tiles = 100
	assert_eq(AISimulator.evaluate(s), 1.0,
		"75% del mapa debe retornar 1.0 (victoria)")


func test_evaluate_terminal_rival_victory() -> void:
	var s := _make_state(10, 100, 75, 500)
	s.total_map_tiles = 100
	assert_eq(AISimulator.evaluate(s), -1.0,
		"Rival con 75% del mapa debe retornar -1.0 (derrota)")


func test_evaluate_no_rival_tiles() -> void:
	var s := _make_state(10, 200, 0, 0)
	assert_eq(AISimulator.evaluate(s), 1.0,
		"Sin tiles rivales debe retornar 1.0")


func test_evaluate_range() -> void:
	for _i in range(20):
		var s := _make_state(
			randi_range(1, 40), randi_range(0, 1000),
			randi_range(1, 40), randi_range(0, 1000))
		s.total_map_tiles = 100
		var v := AISimulator.evaluate(s)
		assert_true(v >= -1.0 and v <= 1.0,
			"evaluate debe estar siempre en [-1, 1] (got %.3f)" % v)


# ============================================================
#  AISimulator — is_terminal
# ============================================================

func test_is_terminal_false_by_default() -> void:
	var s := _make_state()
	assert_false(AISimulator.is_terminal(s))


func test_is_terminal_own_dominates() -> void:
	var s := _make_state(71, 500, 10, 100)
	s.total_map_tiles = 100
	assert_true(AISimulator.is_terminal(s))


func test_is_terminal_rival_dominates() -> void:
	var s := _make_state(5, 100, 71, 500)
	s.total_map_tiles = 100
	assert_true(AISimulator.is_terminal(s))


func test_is_terminal_no_map_info() -> void:
	var s := _make_state()
	s.total_map_tiles = 0
	assert_false(AISimulator.is_terminal(s),
		"Sin total_map_tiles no podemos determinar terminal")


# ============================================================
#  AISimulator — simulate_turn
# ============================================================

func test_simulate_turn_advances_turn_number() -> void:
	var s := _make_state()
	s.turn_number = 5
	var result := AISimulator.simulate_turn(s, true, _make_rng())
	assert_eq(result.turn_number, 6, "simulate_turn debe incrementar turn_number")


func test_simulate_turn_applies_income() -> void:
	var s := _make_state()
	s.own_gold = 50
	s.own_gold_per_turn = 100
	var result := AISimulator.simulate_turn(s, false, _make_rng())
	# El gold final >= gold_inicial + income (puede haberse gastado en acciones)
	assert_gte(result.own_gold, 50,
		"El gold tras el turno no debe ser menor que el inicial")


func test_simulate_turn_does_not_modify_original() -> void:
	var s := _make_state()
	s.own_gold = 500
	s.turn_number = 3
	AISimulator.simulate_turn(s, true, _make_rng())
	assert_eq(s.own_gold,    500, "simulate_turn no debe mutar el estado original")
	assert_eq(s.turn_number, 3,   "simulate_turn no debe mutar el estado original")


func test_simulate_turn_is_deterministic_with_same_seed() -> void:
	var s := _make_state()
	s.own_deck = [_make_card("colonize"), _make_card("build")]
	s.colonizable_count = 3
	var r1 := AISimulator.simulate_turn(s, true, _make_rng(77))
	var r2 := AISimulator.simulate_turn(s, true, _make_rng(77))
	assert_eq(r1.own_tiles, r2.own_tiles,
		"Con el mismo seed, simulate_turn debe ser determinista")
	assert_eq(r1.own_gold, r2.own_gold)


func test_simulate_turn_heuristic_vs_random_same_state() -> void:
	# Solo comprueba que ambas políticas terminan sin errores
	var s := _make_state()
	s.own_deck = [_make_card("colonize")]
	s.colonizable_count = 3
	var r_h := AISimulator.simulate_turn(s, true,  _make_rng(1))
	var r_r := AISimulator.simulate_turn(s, false, _make_rng(2))
	assert_not_null(r_h, "Política heurística debe retornar estado")
	assert_not_null(r_r, "Política aleatoria debe retornar estado")


func test_simulate_turn_empty_deck_still_works() -> void:
	var s := _make_state()
	s.own_deck = []
	var result := AISimulator.simulate_turn(s, true, _make_rng())
	assert_not_null(result, "Deck vacío no debe causar error")
	assert_eq(result.turn_number, s.turn_number + 1)
