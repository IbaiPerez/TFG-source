extends GutTest
## Tests para TurnEvent, TurnEventChoice, TurnEventCondition, TurnEventEffect,
## TurnEventCost, Comparison, CardRemovalFilter, y TurnEventManager.


# ============================================================
#  Helpers
# ============================================================

func _make_stats(p_gold: int = 100, p_food: int = 10) -> Stats:
	var s := Stats.new()
	s.total_gold = p_gold
	s.gold_per_turn = 15
	s.food = p_food
	s.cards_per_turn = 3
	s.draw_pile = CardPile.new()
	s.discard_pile = CardPile.new()
	s.played_pile = CardPile.new()
	s.empire = Empire.new()
	s.empire.controlled_tiles = []
	s.used_unique_events = []
	s.available_events = []
	s.event_chance = 1.0  # Siempre trigger para tests
	return s


func _make_card(p_id: String = "test", p_type: Card.Type = Card.Type.BASIC) -> Card:
	var c := Card.new()
	c.id = p_id
	c.type = p_type
	return c


func _make_context(stats: Stats, turn: int = 5) -> EventContext:
	var mgr := ModifierManager.new()
	add_child_autoqfree(mgr)
	return EventContext.build(stats, mgr, turn)


func _make_event(p_id: String = "evt", p_weight: float = 1.0,
		p_unique: bool = false) -> TurnEvent:
	var evt := TurnEvent.new()
	evt.id = p_id
	evt.weight = p_weight
	evt.unique = p_unique
	evt.conditions = []
	evt.choices = []
	return evt


# ============================================================
#  Comparison
# ============================================================

func test_comparison_greater():
	assert_true(Comparison.evaluate(10, Comparison.Type.GREATER, 5))
	assert_false(Comparison.evaluate(5, Comparison.Type.GREATER, 10))
	assert_false(Comparison.evaluate(5, Comparison.Type.GREATER, 5))


func test_comparison_greater_equal():
	assert_true(Comparison.evaluate(10, Comparison.Type.GREATER_EQUAL, 5))
	assert_true(Comparison.evaluate(5, Comparison.Type.GREATER_EQUAL, 5))
	assert_false(Comparison.evaluate(4, Comparison.Type.GREATER_EQUAL, 5))


func test_comparison_less():
	assert_true(Comparison.evaluate(3, Comparison.Type.LESS, 5))
	assert_false(Comparison.evaluate(5, Comparison.Type.LESS, 5))
	assert_false(Comparison.evaluate(7, Comparison.Type.LESS, 5))


func test_comparison_less_equal():
	assert_true(Comparison.evaluate(3, Comparison.Type.LESS_EQUAL, 5))
	assert_true(Comparison.evaluate(5, Comparison.Type.LESS_EQUAL, 5))
	assert_false(Comparison.evaluate(7, Comparison.Type.LESS_EQUAL, 5))


func test_comparison_equal():
	assert_true(Comparison.evaluate(5.0, Comparison.Type.EQUAL, 5.0))
	assert_false(Comparison.evaluate(5.0, Comparison.Type.EQUAL, 6.0))


# ============================================================
#  TurnEventCondition (base & subclasses)
# ============================================================

func test_base_condition_always_true():
	var cond := TurnEventCondition.new()
	var stats := _make_stats()
	var ctx := _make_context(stats)
	assert_true(cond.is_met(ctx))


func test_gold_threshold_condition_met():
	var cond := GoldThresholdCondition.new(50, Comparison.Type.GREATER_EQUAL)
	var stats := _make_stats(100)
	var ctx := _make_context(stats)
	assert_true(cond.is_met(ctx))


func test_gold_threshold_condition_not_met():
	var cond := GoldThresholdCondition.new(200, Comparison.Type.GREATER_EQUAL)
	var stats := _make_stats(100)
	var ctx := _make_context(stats)
	assert_false(cond.is_met(ctx))


func test_food_threshold_condition():
	var cond := FoodThresholdCondition.new(5, Comparison.Type.GREATER)
	var stats := _make_stats(100, 10)
	var ctx := _make_context(stats)
	assert_true(cond.is_met(ctx))


func test_turn_number_condition():
	var cond := TurnNumberCondition.new(3, Comparison.Type.GREATER_EQUAL)
	var stats := _make_stats()
	var ctx := _make_context(stats, 5)
	assert_true(cond.is_met(ctx))


func test_turn_number_condition_not_met():
	var cond := TurnNumberCondition.new(10, Comparison.Type.GREATER_EQUAL)
	var stats := _make_stats()
	var ctx := _make_context(stats, 5)
	assert_false(cond.is_met(ctx))


# ============================================================
#  TurnEvent.is_available
# ============================================================

func test_event_available_no_conditions():
	var evt := _make_event()
	var stats := _make_stats()
	var ctx := _make_context(stats)
	assert_true(evt.is_available(ctx))


func test_event_not_available_condition_fails():
	var evt := _make_event()
	evt.conditions = [GoldThresholdCondition.new(999, Comparison.Type.GREATER_EQUAL)]
	var stats := _make_stats(100)
	var ctx := _make_context(stats)
	assert_false(evt.is_available(ctx))


func test_event_available_all_conditions_pass():
	var evt := _make_event()
	evt.conditions = [
		GoldThresholdCondition.new(50, Comparison.Type.GREATER_EQUAL),
		TurnNumberCondition.new(3, Comparison.Type.GREATER_EQUAL),
	]
	var stats := _make_stats(100)
	var ctx := _make_context(stats, 5)
	assert_true(evt.is_available(ctx))


# ============================================================
#  TurnEventEffect subclasses
# ============================================================

func test_gold_event_effect_adds_gold():
	var effect := GoldEventEffect.new(50)
	var stats := _make_stats(100)
	var ctx := _make_context(stats)
	effect.execute(ctx)
	assert_eq(stats.total_gold, 150)


func test_gold_event_effect_subtracts_gold():
	var effect := GoldEventEffect.new(-30)
	var stats := _make_stats(100)
	var ctx := _make_context(stats)
	effect.execute(ctx)
	assert_eq(stats.total_gold, 70)


func test_food_event_effect():
	var effect := FoodEventEffect.new(20)
	var stats := _make_stats(100, 10)
	var ctx := _make_context(stats)
	effect.execute(ctx)
	assert_eq(stats.food, 30)


func test_scaled_gold_effect_base_only():
	var effect := ScaledGoldEffect.new(50.0, 0.0, 0.0)
	var stats := _make_stats(100)
	var ctx := _make_context(stats, 5)
	effect.execute(ctx)
	assert_eq(stats.total_gold, 150)


func test_scaled_gold_effect_with_turn_factor():
	var effect := ScaledGoldEffect.new(10.0, 2.0, 0.0)
	var stats := _make_stats(100)
	var ctx := _make_context(stats, 5)
	# amount = 10 + 5*2 + 0 = 20
	effect.execute(ctx)
	assert_eq(stats.total_gold, 120)


func test_scaled_gold_effect_with_gpt_percent():
	var effect := ScaledGoldEffect.new(0.0, 0.0, 0.5)
	var stats := _make_stats(100)
	stats.gold_per_turn = 20
	var ctx := _make_context(stats, 5)
	# amount = 0 + 0 + 20*0.5 = 10
	effect.execute(ctx)
	assert_eq(stats.total_gold, 110)


func test_unlock_building_effect():
	var stats := _make_stats()
	stats.possible_buildings = []
	var ctx := _make_context(stats)
	var b := Building.new()
	b.name = "Special"
	var effect := UnlockBuildingEffect.new(b)
	effect.execute(ctx)
	assert_true(b in stats.possible_buildings)


# ============================================================
#  TurnEventCost
# ============================================================

func test_cost_can_pay_enough_gold():
	var cost := TurnEventCost.new()
	cost.gold = 50
	var stats := _make_stats(100)
	var ctx := _make_context(stats)
	assert_true(cost.can_pay(ctx))


func test_cost_cannot_pay_not_enough_gold():
	var cost := TurnEventCost.new()
	cost.gold = 200
	var stats := _make_stats(100)
	var ctx := _make_context(stats)
	assert_false(cost.can_pay(ctx))


func test_cost_pay_deducts_gold():
	var cost := TurnEventCost.new()
	cost.gold = 30
	var stats := _make_stats(100)
	var ctx := _make_context(stats)
	cost.pay(ctx)
	assert_eq(stats.total_gold, 70)


func test_cost_pay_deducts_food():
	var cost := TurnEventCost.new()
	cost.food = 5
	var stats := _make_stats(100, 10)
	var ctx := _make_context(stats)
	cost.pay(ctx)
	assert_eq(stats.food, 5)


func test_scaled_gold_cost_can_pay():
	var cost := ScaledGoldCost.new(10.0, 2.0, 0.0)
	var stats := _make_stats(100)
	var ctx := _make_context(stats, 5)
	# cost = 10 + 5*2 = 20 <= 100
	assert_true(cost.can_pay(ctx))


func test_scaled_gold_cost_cannot_pay():
	var cost := ScaledGoldCost.new(50.0, 20.0, 0.0)
	var stats := _make_stats(100)
	var ctx := _make_context(stats, 10)
	# cost = 50 + 10*20 = 250 > 100
	assert_false(cost.can_pay(ctx))


func test_scaled_gold_cost_pay():
	var cost := ScaledGoldCost.new(10.0, 0.0, 0.0)
	var stats := _make_stats(100)
	var ctx := _make_context(stats, 5)
	cost.pay(ctx)
	assert_eq(stats.total_gold, 90)


# ============================================================
#  TurnEventChoice
# ============================================================

func test_choice_is_affordable_no_cost():
	var choice := TurnEventChoice.new()
	var stats := _make_stats()
	var ctx := _make_context(stats)
	assert_true(choice.is_affordable(ctx))


func test_choice_is_affordable_with_payable_cost():
	var choice := TurnEventChoice.new()
	var cost := TurnEventCost.new()
	cost.gold = 50
	choice.cost = cost
	var stats := _make_stats(100)
	var ctx := _make_context(stats)
	assert_true(choice.is_affordable(ctx))


func test_choice_not_affordable():
	var choice := TurnEventChoice.new()
	var cost := TurnEventCost.new()
	cost.gold = 200
	choice.cost = cost
	var stats := _make_stats(100)
	var ctx := _make_context(stats)
	assert_false(choice.is_affordable(ctx))


func test_choice_execute_applies_effects():
	var choice := TurnEventChoice.new()
	choice.effects = [GoldEventEffect.new(25)]
	var stats := _make_stats(100)
	var ctx := _make_context(stats)
	choice.execute(ctx)
	assert_eq(stats.total_gold, 125)


func test_choice_execute_pays_cost_then_applies():
	var choice := TurnEventChoice.new()
	var cost := TurnEventCost.new()
	cost.gold = 20
	choice.cost = cost
	choice.effects = [GoldEventEffect.new(50)]
	var stats := _make_stats(100)
	var ctx := _make_context(stats)
	choice.execute(ctx)
	# 100 - 20 + 50 = 130
	assert_eq(stats.total_gold, 130)


func test_choice_needs_player_input_false_by_default():
	var choice := TurnEventChoice.new()
	assert_false(choice.needs_player_input())


# ============================================================
#  CardRemovalFilter
# ============================================================

func test_filter_matches_by_id():
	var filter := CardRemovalFilter.new()
	filter.card_id = "Build"
	var stats := _make_stats()
	stats.draw_pile.add_card(_make_card("Build"))
	stats.draw_pile.add_card(_make_card("Colonize"))
	var candidates := filter.get_candidates(stats)
	assert_eq(candidates.size(), 1)
	assert_eq(candidates[0].id, "Build")


func test_filter_matches_by_type():
	var filter := CardRemovalFilter.new()
	filter.card_type = Card.Type.SINGLE_USE
	var stats := _make_stats()
	stats.draw_pile.add_card(_make_card("a", Card.Type.BASIC))
	stats.draw_pile.add_card(_make_card("b", Card.Type.SINGLE_USE))
	var candidates := filter.get_candidates(stats)
	assert_eq(candidates.size(), 1)
	assert_eq(candidates[0].id, "b")


func test_filter_find_first():
	var filter := CardRemovalFilter.new()
	filter.card_id = "target"
	var stats := _make_stats()
	stats.discard_pile.add_card(_make_card("target"))
	var result := filter.find_first(stats)
	assert_false(result.is_empty())
	assert_eq(result.card.id, "target")


func test_filter_find_first_empty_when_no_match():
	var filter := CardRemovalFilter.new()
	filter.card_id = "nonexistent"
	var stats := _make_stats()
	stats.draw_pile.add_card(_make_card("other"))
	var result := filter.find_first(stats)
	assert_true(result.is_empty())


func test_filter_has_match():
	var filter := CardRemovalFilter.new()
	filter.card_id = "Build"
	var stats := _make_stats()
	stats.draw_pile.add_card(_make_card("Build"))
	assert_true(filter.has_match(stats))


func test_filter_no_match():
	var filter := CardRemovalFilter.new()
	filter.card_id = "Build"
	var stats := _make_stats()
	stats.draw_pile.add_card(_make_card("Colonize"))
	assert_false(filter.has_match(stats))


# ============================================================
#  EventContext
# ============================================================

func test_context_build_populates_gold():
	var stats := _make_stats(200, 15)
	var ctx := _make_context(stats, 7)
	assert_eq(ctx.total_gold, 200)
	assert_eq(ctx.food, 15)
	assert_eq(ctx.turn_number, 7)


func test_context_card_count_by_id():
	var stats := _make_stats()
	stats.draw_pile.add_card(_make_card("Build"))
	stats.draw_pile.add_card(_make_card("Build"))
	stats.discard_pile.add_card(_make_card("Colonize"))
	var ctx := _make_context(stats)
	assert_eq(ctx.card_count_by_id.get("Build", 0), 2)
	assert_eq(ctx.card_count_by_id.get("Colonize", 0), 1)


func test_context_card_count_by_type():
	var stats := _make_stats()
	stats.draw_pile.add_card(_make_card("a", Card.Type.BASIC))
	stats.draw_pile.add_card(_make_card("b", Card.Type.BASIC))
	stats.draw_pile.add_card(_make_card("c", Card.Type.SPECIAL))
	var ctx := _make_context(stats)
	assert_eq(ctx.card_count_by_type.get(Card.Type.BASIC, 0), 2)
	assert_eq(ctx.card_count_by_type.get(Card.Type.SPECIAL, 0), 1)
