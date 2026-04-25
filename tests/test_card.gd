extends GutTest
## Tests para la clase base Card y sus propiedades/métodos.


func _create_card(p_id: String = "test_card", p_type: Card.Type = Card.Type.BASIC,
		p_target: Card.Target = Card.Target.TILE) -> Card:
	var card := Card.new()
	card.id = p_id
	card.type = p_type
	card.target = p_target
	return card


func test_is_tile_targeted_returns_true_for_tile_target():
	var card := _create_card("c", Card.Type.BASIC, Card.Target.TILE)
	assert_true(card.is_tile_targeted(), "TILE target should return true")


func test_is_tile_targeted_returns_false_for_self_target():
	var card := _create_card("c", Card.Type.BASIC, Card.Target.SELF)
	assert_false(card.is_tile_targeted(), "SELF target should return false")


func test_is_batle_front_targeted():
	var card := _create_card("c", Card.Type.BASIC, Card.Target.BATTLE_FRONT)
	assert_true(card.is_batle_front_targeted())


func test_is_batle_front_targeted_false_for_tile():
	var card := _create_card("c", Card.Type.BASIC, Card.Target.TILE)
	assert_false(card.is_batle_front_targeted())


func test_is_single_use_true():
	var card := _create_card("c", Card.Type.SINGLE_USE)
	assert_true(card.is_single_use())


func test_is_single_use_false_for_basic():
	var card := _create_card("c", Card.Type.BASIC)
	assert_false(card.is_single_use())


func test_is_single_use_false_for_special():
	var card := _create_card("c", Card.Type.SPECIAL)
	assert_false(card.is_single_use())


func test_get_tooltip_returns_tooltipe_text_when_set():
	var card := _create_card()
	card.tooltipe_text = "Custom tooltip"
	assert_eq(card.get_tooltip(), "Custom tooltip")


func test_get_tooltip_generates_from_build_tooltip_when_empty():
	var card := _create_card()
	card.tooltipe_text = ""
	# Base Card._build_tooltip() returns ""
	assert_eq(card.get_tooltip(), "")


func test_get_valid_targets_returns_empty_by_default():
	var card := _create_card()
	var stats := Stats.new()
	assert_eq(card.get_valid_targets(stats).size(), 0)


func test_is_valid_target_returns_false_by_default():
	var card := _create_card()
	var stats := Stats.new()
	var node := Node.new()
	assert_false(card.is_valid_target(node, stats))
	node.free()


func test_card_type_enum_values():
	assert_eq(Card.Type.BASIC, 0)
	assert_eq(Card.Type.SPECIAL, 1)
	assert_eq(Card.Type.SINGLE_USE, 2)


func test_card_target_enum_values():
	assert_eq(Card.Target.TILE, 0)
	assert_eq(Card.Target.SELF, 1)
	assert_eq(Card.Target.BATTLE_FRONT, 2)
