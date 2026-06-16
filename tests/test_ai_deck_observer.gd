extends GutTest

## Tests para AIDeckObserver y AIDeterminizer (Fase C — información imperfecta).
##
## AIDeckObserver: registra cartas del rival que no están en su starting_deck.
## AIDeterminizer: samplea manos simuladas del deck conocido para SO-ISMCTS.


# ============================================================
#  Helpers
# ============================================================

func _make_card(p_id: String) -> Card:
	var c := Card.new()
	c.id = p_id
	return c


func _make_stats_with_starting_deck(cards: Array[Card]) -> Stats:
	var s := Stats.new()
	s.total_gold = 100
	s.gold_per_turn = 10
	s.food = 5
	s.cards_per_turn = 2
	var starting := CardPile.new()
	for c in cards:
		starting.add_card(c)
	s.starting_deck = starting
	s.deck = starting.duplicate()
	s.draw_pile = CardPile.new()
	s.discard_pile = CardPile.new()
	s.played_pile = CardPile.new()
	var emp := Empire.new()
	emp.name = "TestEmpire"
	emp.color = Color.BLUE
	emp.controlled_tiles = []
	s.empire = emp
	s.possible_buildings = []
	s.turn_number = 0
	s.event_chance = 0.0
	return s


func _make_rng(seed_val: int = 42) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	return r


# ============================================================
#  AIDeckObserver — inicialización
# ============================================================

func test_observer_starts_empty() -> void:
	var colonize := _make_card("colonize")
	var rival_stats := _make_stats_with_starting_deck([colonize])
	var obs := AIDeckObserver.new()
	obs.init(rival_stats, [colonize])
	assert_eq(obs.acquired_cards.size(), 0,
		"Sin cartas jugadas, acquired_cards debe estar vacío")
	obs.cleanup()


# ============================================================
#  AIDeckObserver — filtrado por rival_stats
# ============================================================

func test_observer_ignores_own_cards() -> void:
	var card := _make_card("colonize")
	var own_stats := _make_stats_with_starting_deck([])
	var rival_stats := _make_stats_with_starting_deck([card])
	var obs := AIDeckObserver.new()
	obs.init(rival_stats, [card])

	# Simular carta jugada por la propia IA (no el rival)
	Events.card_played.emit(card, own_stats)

	assert_eq(obs.acquired_cards.size(), 0,
		"Cartas propias no deben registrarse como adquiridas por el rival")
	obs.cleanup()


func test_observer_ignores_cards_in_starting_deck() -> void:
	var colonize := _make_card("colonize")
	var rival_stats := _make_stats_with_starting_deck([colonize])
	var obs := AIDeckObserver.new()
	obs.init(rival_stats, [colonize])

	Events.card_played.emit(colonize, rival_stats)

	assert_eq(obs.acquired_cards.size(), 0,
		"Cartas del starting_deck no deben registrarse como adquiridas")
	obs.cleanup()


# ============================================================
#  AIDeckObserver — detección de adquisiciones
# ============================================================

func test_observer_registers_unknown_card() -> void:
	var colonize := _make_card("colonize")
	var shop_card := _make_card("library")  # no está en starting_deck
	var rival_stats := _make_stats_with_starting_deck([colonize])
	var obs := AIDeckObserver.new()
	obs.init(rival_stats, [colonize])

	Events.card_played.emit(shop_card, rival_stats)

	assert_eq(obs.acquired_cards.size(), 1,
		"Una carta no conocida debe registrarse como adquirida")
	assert_eq(obs.acquired_cards[0].id, "library",
		"La carta registrada debe ser la jugada")
	obs.cleanup()


func test_observer_does_not_duplicate_same_id() -> void:
	var colonize := _make_card("colonize")
	var shop_card := _make_card("library")
	var rival_stats := _make_stats_with_starting_deck([colonize])
	var obs := AIDeckObserver.new()
	obs.init(rival_stats, [colonize])

	Events.card_played.emit(shop_card, rival_stats)
	Events.card_played.emit(shop_card, rival_stats)

	assert_eq(obs.acquired_cards.size(), 1,
		"El mismo id adquirido no debe duplicarse")
	obs.cleanup()


func test_observer_registers_multiple_different_acquired_cards() -> void:
	var colonize := _make_card("colonize")
	var rival_stats := _make_stats_with_starting_deck([colonize])
	var obs := AIDeckObserver.new()
	obs.init(rival_stats, [colonize])

	Events.card_played.emit(_make_card("library"), rival_stats)
	Events.card_played.emit(_make_card("observatory"), rival_stats)

	assert_eq(obs.acquired_cards.size(), 2,
		"Dos adquisiciones distintas deben registrarse")
	obs.cleanup()


# ============================================================
#  AIDeckObserver — cleanup desconecta el signal
# ============================================================

func test_cleanup_stops_observing() -> void:
	var colonize := _make_card("colonize")
	var shop_card := _make_card("library")
	var rival_stats := _make_stats_with_starting_deck([colonize])
	var obs := AIDeckObserver.new()
	obs.init(rival_stats, [colonize])
	obs.cleanup()

	# Después del cleanup, jugar una carta no debe registrarse.
	Events.card_played.emit(shop_card, rival_stats)

	assert_eq(obs.acquired_cards.size(), 0,
		"Tras cleanup, las cartas jugadas no deben registrarse")


# ============================================================
#  AIDeterminizer.build_known_deck
# ============================================================

func test_build_known_deck_without_observer_returns_base() -> void:
	var c1 := _make_card("colonize")
	var c2 := _make_card("build")
	var rival_stats := _make_stats_with_starting_deck([c1, c2])
	var emp := Empire.new()
	emp.name = "Rival"
	emp.color = Color.RED
	emp.controlled_tiles = []
	rival_stats.empire = emp

	var ctrl := EmpireController.new()
	add_child_autofree(ctrl)
	ctrl._init_managers()
	ctrl.stats = rival_stats

	var view := AIEmpirePublicView.from_controller(ctrl)
	var deck := AIDeterminizer.build_known_deck(view, null)

	assert_eq(deck.size(), 2,
		"Sin observer, build_known_deck debe devolver solo el starting_deck")


func test_build_known_deck_appends_acquired_cards() -> void:
	var colonize := _make_card("colonize")
	var shop_card := _make_card("library")
	var rival_stats := _make_stats_with_starting_deck([colonize])
	var emp := Empire.new()
	emp.name = "Rival"
	emp.color = Color.RED
	emp.controlled_tiles = []
	rival_stats.empire = emp

	var ctrl := EmpireController.new()
	add_child_autofree(ctrl)
	ctrl._init_managers()
	ctrl.stats = rival_stats

	var obs := AIDeckObserver.new()
	obs.init(rival_stats, [colonize])
	Events.card_played.emit(shop_card, rival_stats)

	var view := AIEmpirePublicView.from_controller(ctrl)
	var deck := AIDeterminizer.build_known_deck(view, obs)

	assert_eq(deck.size(), 2,
		"build_known_deck debe incluir starting_deck + acquired_cards")
	var ids: Array[String] = []
	for c in deck:
		ids.append(c.id)
	assert_true("colonize" in ids, "starting_deck debe estar en el resultado")
	assert_true("library" in ids, "La adquisición debe estar en el resultado")
	obs.cleanup()


func test_build_known_deck_with_null_rival_view_returns_empty() -> void:
	var deck := AIDeterminizer.build_known_deck(null, null)
	assert_eq(deck.size(), 0, "Vista null debe devolver deck vacío")


# ============================================================
#  AIDeterminizer.build_known_deck — deck_size como techo
# ============================================================

func _make_ctrl_with_piles(starting: Array[Card],
		draw_cards: Array[Card], discard_cards: Array[Card]) -> EmpireController:
	var rival_stats := _make_stats_with_starting_deck(starting)
	for c in draw_cards:
		rival_stats.draw_pile.add_card(c)
	for c in discard_cards:
		rival_stats.discard_pile.add_card(c)
	var ctrl := EmpireController.new()
	add_child_autofree(ctrl)
	ctrl._init_managers()
	ctrl.stats = rival_stats
	return ctrl


func test_deck_size_equals_draw_plus_discard() -> void:
	var c1 := _make_card("a")
	var c2 := _make_card("b")
	var c3 := _make_card("c")
	var ctrl := _make_ctrl_with_piles([c1, c2, c3], [c1, c2], [c3])
	var view := AIEmpirePublicView.from_controller(ctrl)
	assert_eq(view.deck_size, 3, "deck_size debe ser draw_pile + discard_pile")


func test_build_known_deck_truncates_when_deck_size_smaller() -> void:
	# 3 cartas en starting_deck pero solo 2 en circulación (1 purgada)
	var c1 := _make_card("a")
	var c2 := _make_card("b")
	var c3 := _make_card("c")
	var ctrl := _make_ctrl_with_piles([c1, c2, c3], [c1, c2], [])
	var view := AIEmpirePublicView.from_controller(ctrl)
	assert_eq(view.deck_size, 2, "deck_size debe ser 2 tras purga de 1 carta")
	var deck := AIDeterminizer.build_known_deck(view, null)
	assert_eq(deck.size(), 2, "build_known_deck no debe exceder deck_size")


func test_build_known_deck_no_truncation_when_deck_size_matches() -> void:
	var c1 := _make_card("a")
	var c2 := _make_card("b")
	var ctrl := _make_ctrl_with_piles([c1, c2], [c1], [c2])
	var view := AIEmpirePublicView.from_controller(ctrl)
	var deck := AIDeterminizer.build_known_deck(view, null)
	assert_eq(deck.size(), 2, "Sin purgas, deck no debe truncarse")


func test_build_known_deck_deck_size_zero_does_not_truncate() -> void:
	# deck_size = 0 significa que los piles no están inicializados (test context):
	# no debe truncar a 0 en ese caso (condición guard: deck_size > 0).
	var c1 := _make_card("a")
	var c2 := _make_card("b")
	var rival_stats := _make_stats_with_starting_deck([c1, c2])
	# draw_pile y discard_pile están vacíos por _make_stats → deck_size = 0
	var ctrl := EmpireController.new()
	add_child_autofree(ctrl)
	ctrl._init_managers()
	ctrl.stats = rival_stats
	var view := AIEmpirePublicView.from_controller(ctrl)
	assert_eq(view.deck_size, 0)
	var deck := AIDeterminizer.build_known_deck(view, null)
	assert_eq(deck.size(), 2, "deck_size=0 no debe truncar (piles no inicializados)")


# ============================================================
#  AIDeterminizer.sample
# ============================================================

func test_sample_returns_correct_hand_size() -> void:
	var cards: Array[Card] = []
	for i in range(8):
		cards.append(_make_card("card_%d" % i))
	var hand := AIDeterminizer.sample(cards, 3, _make_rng())
	assert_eq(hand.size(), 3, "sample debe devolver exactamente hand_size cartas")


func test_sample_returns_all_when_hand_size_exceeds_deck() -> void:
	var cards: Array[Card] = [_make_card("a"), _make_card("b")]
	var hand := AIDeterminizer.sample(cards, 5, _make_rng())
	assert_eq(hand.size(), 2, "Con deck < hand_size debe devolver todo el deck")


func test_sample_empty_deck_returns_empty() -> void:
	var hand := AIDeterminizer.sample([], 3, _make_rng())
	assert_eq(hand.size(), 0, "Deck vacío debe devolver mano vacía")


func test_sample_zero_hand_size_returns_empty() -> void:
	var cards: Array[Card] = [_make_card("a"), _make_card("b")]
	var hand := AIDeterminizer.sample(cards, 0, _make_rng())
	assert_eq(hand.size(), 0, "hand_size 0 debe devolver mano vacía")


func test_sample_no_duplicates() -> void:
	var cards: Array[Card] = []
	for i in range(10):
		cards.append(_make_card("card_%d" % i))
	var hand := AIDeterminizer.sample(cards, 5, _make_rng())
	var seen: Dictionary = {}
	for c in hand:
		assert_false(c.id in seen, "No debe haber cartas duplicadas en la mano")
		seen[c.id] = true


func test_sample_is_deterministic_with_same_seed() -> void:
	var cards: Array[Card] = []
	for i in range(8):
		cards.append(_make_card("card_%d" % i))
	var hand1 := AIDeterminizer.sample(cards, 3, _make_rng(99))
	var hand2 := AIDeterminizer.sample(cards, 3, _make_rng(99))
	var ids1: Array[String] = []
	for c in hand1: ids1.append(c.id)
	var ids2: Array[String] = []
	for c in hand2: ids2.append(c.id)
	assert_eq(ids1, ids2, "Con el mismo seed el sample debe ser idéntico")


func test_sample_differs_with_different_seeds() -> void:
	var cards: Array[Card] = []
	for i in range(10):
		cards.append(_make_card("card_%d" % i))
	var hand1 := AIDeterminizer.sample(cards, 5, _make_rng(1))
	var hand2 := AIDeterminizer.sample(cards, 5, _make_rng(2))
	var ids1: Array[String] = []
	for c in hand1: ids1.append(c.id)
	var ids2: Array[String] = []
	for c in hand2: ids2.append(c.id)
	# Con 10 cartas y 5 muestreadas es muy improbable obtener el mismo resultado.
	assert_ne(ids1, ids2, "Seeds distintos deben producir manos distintas")
