extends GutTest
## Tests para Stats: creación de instancias, setters, señales, gestión de buildings.


func _make_empire() -> Empire:
	var e := Empire.new()
	e.name = "Test Empire"
	e.color = Color.RED
	return e


func _make_stats_resource() -> Stats:
	var s := Stats.new()
	s.initial_gold = 100
	s.initial_gold_per_turn = 10
	s.cards_per_turn = 3
	s.starting_deck = CardPile.new()
	s.empire = _make_empire()
	s.possible_buildings = []
	s.event_chance = 0.5
	s.available_events = []
	return s


# --- create_instance ---

func test_create_instance_sets_initial_gold():
	var res := _make_stats_resource()
	var inst: Stats = res.create_instance()
	assert_eq(inst.total_gold, 100)


func test_create_instance_sets_initial_gold_per_turn():
	var res := _make_stats_resource()
	var inst: Stats = res.create_instance()
	assert_eq(inst.gold_per_turn, 10)


func test_create_instance_sets_food_to_zero():
	var res := _make_stats_resource()
	var inst: Stats = res.create_instance()
	assert_eq(inst.food, 0)


func test_create_instance_creates_empty_piles():
	var res := _make_stats_resource()
	var inst: Stats = res.create_instance()
	assert_not_null(inst.draw_pile)
	assert_not_null(inst.discard_pile)
	assert_not_null(inst.played_pile)
	assert_true(inst.draw_pile.empty())
	assert_true(inst.discard_pile.empty())
	assert_true(inst.played_pile.empty())


func test_create_instance_duplicates_deck():
	var res := _make_stats_resource()
	var card := Card.new()
	card.id = "test"
	res.starting_deck.add_card(card)
	var inst: Stats = res.create_instance()
	assert_eq(inst.deck.cards.size(), 1)


func test_create_instance_resets_turn_number():
	var res := _make_stats_resource()
	var inst: Stats = res.create_instance()
	assert_eq(inst.turn_number, 0)


func test_create_instance_resets_unique_events():
	var res := _make_stats_resource()
	var inst: Stats = res.create_instance()
	assert_eq(inst.used_unique_events.size(), 0)


# --- Setters with signals ---

func test_set_gold_emits_stats_changed():
	var s := _make_stats_resource().create_instance()
	watch_signals(s)
	s.total_gold = 200
	assert_signal_emitted(s, "stats_changed")


func test_set_gold_per_turn_emits_stats_changed():
	var s := _make_stats_resource().create_instance()
	watch_signals(s)
	s.gold_per_turn = 20
	assert_signal_emitted(s, "stats_changed")


func test_set_food_emits_stats_changed():
	var s := _make_stats_resource().create_instance()
	watch_signals(s)
	s.food = 10
	assert_signal_emitted(s, "stats_changed")


func test_set_cards_per_turn_clamped_min():
	var s := _make_stats_resource().create_instance()
	s.cards_per_turn = -5
	assert_eq(s.cards_per_turn, 1, "Should clamp to minimum 1")


func test_set_cards_per_turn_clamped_max():
	var s := _make_stats_resource().create_instance()
	s.cards_per_turn = 50
	assert_eq(s.cards_per_turn, 20, "Should clamp to maximum 20")


func test_set_cards_per_turn_normal_value():
	var s := _make_stats_resource().create_instance()
	s.cards_per_turn = 5
	assert_eq(s.cards_per_turn, 5)


# --- add_possible_building / remove_possible_building ---

func test_add_possible_building():
	var s := _make_stats_resource().create_instance()
	var b := Building.new()
	b.name = "Mine"
	s.add_possible_building(b)
	assert_true(b in s.possible_buildings)


func test_add_possible_building_emits_signal():
	var s := _make_stats_resource().create_instance()
	var b := Building.new()
	b.name = "Mine"
	watch_signals(s)
	s.add_possible_building(b)
	assert_signal_emitted(s, "possible_buildings_changed")


func test_add_possible_building_no_duplicate():
	var s := _make_stats_resource().create_instance()
	var b := Building.new()
	b.name = "Mine"
	s.add_possible_building(b)
	s.add_possible_building(b)
	var count := 0
	for building in s.possible_buildings:
		if building == b:
			count += 1
	assert_eq(count, 1, "Should not add duplicate")


func test_remove_possible_building():
	var s := _make_stats_resource().create_instance()
	var b := Building.new()
	b.name = "Mine"
	s.add_possible_building(b)
	s.remove_possible_building(b)
	assert_false(b in s.possible_buildings)


func test_remove_possible_building_emits_signal():
	var s := _make_stats_resource().create_instance()
	var b := Building.new()
	b.name = "Mine"
	s.add_possible_building(b)
	watch_signals(s)
	s.remove_possible_building(b)
	assert_signal_emitted(s, "possible_buildings_changed")


func test_remove_nonexistent_building_no_error():
	var s := _make_stats_resource().create_instance()
	var b := Building.new()
	b.name = "Nonexistent"
	# Should not crash
	s.remove_possible_building(b)
	assert_eq(s.possible_buildings.size(), 0)
