extends GutTest
## Tests para CardPile: draw, add, remove, shuffle, clear, signals.


var pile: CardPile


func before_each():
	pile = CardPile.new()


func _make_card(p_id: String) -> Card:
	var c := Card.new()
	c.id = p_id
	return c


# --- empty ---

func test_new_pile_is_empty():
	assert_true(pile.empty())


func test_pile_not_empty_after_add():
	pile.add_card(_make_card("a"))
	assert_false(pile.empty())


# --- add_card / draw_card ---

func test_add_card_increases_size():
	pile.add_card(_make_card("a"))
	pile.add_card(_make_card("b"))
	assert_eq(pile.cards.size(), 2)


func test_draw_card_returns_last_added():
	pile.add_card(_make_card("first"))
	pile.add_card(_make_card("second"))
	var drawn := pile.draw_card()
	assert_eq(drawn.id, "second", "draw_card pops from back")


func test_draw_card_decreases_size():
	pile.add_card(_make_card("a"))
	pile.add_card(_make_card("b"))
	pile.draw_card()
	assert_eq(pile.cards.size(), 1)


func test_draw_all_cards_empties_pile():
	pile.add_card(_make_card("a"))
	pile.add_card(_make_card("b"))
	pile.draw_card()
	pile.draw_card()
	assert_true(pile.empty())


# --- remove_card ---

func test_remove_card_returns_true_when_found():
	var card := _make_card("target")
	pile.add_card(card)
	assert_true(pile.remove_card(card))


func test_remove_card_returns_false_when_not_found():
	var card := _make_card("not_in_pile")
	assert_false(pile.remove_card(card))


func test_remove_card_decreases_size():
	var card := _make_card("a")
	pile.add_card(card)
	pile.add_card(_make_card("b"))
	pile.remove_card(card)
	assert_eq(pile.cards.size(), 1)


# --- shuffle ---

func test_shuffle_preserves_size():
	for i in 10:
		pile.add_card(_make_card("card_%d" % i))
	pile.shuffle()
	assert_eq(pile.cards.size(), 10)


# --- clear ---

func test_clear_empties_pile():
	pile.add_card(_make_card("a"))
	pile.add_card(_make_card("b"))
	pile.clear()
	assert_true(pile.empty())
	assert_eq(pile.cards.size(), 0)


# --- signal card_pile_size_changed ---

func test_add_card_emits_signal():
	watch_signals(pile)
	pile.add_card(_make_card("a"))
	assert_signal_emitted(pile, "card_pile_size_changed")


func test_draw_card_emits_signal():
	pile.add_card(_make_card("a"))
	watch_signals(pile)
	pile.draw_card()
	assert_signal_emitted(pile, "card_pile_size_changed")


func test_remove_card_emits_signal_on_success():
	var card := _make_card("a")
	pile.add_card(card)
	watch_signals(pile)
	pile.remove_card(card)
	assert_signal_emitted(pile, "card_pile_size_changed")


func test_clear_emits_signal():
	pile.add_card(_make_card("a"))
	watch_signals(pile)
	pile.clear()
	assert_signal_emitted(pile, "card_pile_size_changed")


# --- _to_string ---

func test_to_string_format():
	pile.add_card(_make_card("Alpha"))
	pile.add_card(_make_card("Beta"))
	var s := pile._to_string()
	assert_true(s.contains("1: Alpha"))
	assert_true(s.contains("2: Beta"))
