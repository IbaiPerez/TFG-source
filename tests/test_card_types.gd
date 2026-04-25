extends GutTest
## Tests para los tipos específicos de cartas: GenerateGoldCard, CardDrawCard, ColonizeCard, BuildCard.


# --- GenerateGoldCard ---

func test_generate_gold_card_adds_gold():
	var card := GenerateGoldCard.new()
	card.id = "gold"
	card.amount = 50
	card.target = Card.Target.SELF

	var stats := Stats.new()
	stats.total_gold = 100
	stats.gold_per_turn = 0
	stats.food = 0
	stats.draw_pile = CardPile.new()
	stats.discard_pile = CardPile.new()
	stats.played_pile = CardPile.new()

	card.apply_effects([], stats)
	assert_eq(stats.total_gold, 150, "Gold should increase by card amount")


func test_generate_gold_card_tooltip_contains_amount():
	var card := GenerateGoldCard.new()
	card.amount = 30
	var tooltip := card._build_tooltip()
	assert_true(tooltip.contains("30"), "Tooltip should contain the amount")


# --- CardDrawCard ---

func test_card_draw_card_tooltip_singular():
	var card := CardDrawCard.new()
	card.amount = 1
	var tooltip := card._build_tooltip()
	assert_true(tooltip.contains("una"), "Singular tooltip for 1 card")


func test_card_draw_card_tooltip_plural():
	var card := CardDrawCard.new()
	card.amount = 3
	var tooltip := card._build_tooltip()
	assert_true(tooltip.contains("3"), "Plural tooltip should contain amount")


# --- BuildCard ---

func test_build_card_is_valid_target_false_for_non_tile():
	var card := BuildCard.new()
	card.buildings = []
	var stats := Stats.new()
	stats.empire = Empire.new()
	stats.total_gold = 100
	var node := Node.new()
	assert_false(card.is_valid_target(node, stats))
	node.free()


func test_build_card_get_valid_targets_empty_with_no_buildings():
	var card := BuildCard.new()
	card.buildings = []
	var stats := Stats.new()
	stats.empire = Empire.new()
	stats.empire.controlled_tiles = []
	var targets := card.get_valid_targets(stats)
	assert_eq(targets.size(), 0)


# --- ColonizeCard ---

func test_colonize_card_tooltip_not_empty():
	var card := ColonizeCard.new()
	var tooltip := card._build_tooltip()
	assert_true(tooltip.length() > 0, "Colonize tooltip should not be empty")
