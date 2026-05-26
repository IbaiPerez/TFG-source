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


# ============================================================
#  EventCategoryWeights
# ============================================================

func _make_weights(p_core_priority:float = 0.9) -> EventCategoryWeights:
	var w := EventCategoryWeights.new()
	w.core_priority_chance = p_core_priority
	# Por defecto, los tests asumen que el evento siempre dispara para
	# poder verificar la lógica de selección sin lidiar con la fase A.
	w.event_chance_fallback = 1.0
	w.core_progression_fallback = 1.0
	w.optional_progression_fallback = 1.0
	w.flavour_fallback = 1.0
	w.deck_fallback = 1.0
	w.shop_fallback = 1.0
	w.spirit_fallback = 1.0
	w.decision_fallback = 1.0
	return w


func test_weights_returns_fallback_when_curve_is_null():
	var w := _make_weights()
	w.flavour_fallback = 4.5
	assert_almost_eq(w.get_weight(EventCategory.Type.FLAVOUR, 10), 4.5, 0.0001)


## Helper: construye una Curve lista para usarse como peso de categoría.
## Nota: Curve clampa los puntos al rango [min_value, max_value]. Por
## defecto Godot deja ese rango en [0, 1]. Esta función lo abre a
## [0, p_max_value] para poder usar valores arbitrarios de peso.
func _make_weight_curve(p_min_domain:float, p_max_domain:float,
		p_max_value:float = 100.0) -> Curve:
	var curve := Curve.new()
	# El orden importa: min/max_value antes de add_point para que los
	# puntos no se clampen al rango por defecto [0, 1].
	curve.min_value = 0.0
	curve.max_value = p_max_value
	curve.min_domain = p_min_domain
	curve.max_domain = p_max_domain
	return curve


## Test diagnóstico: usa valores dentro del rango por defecto [0, 1] para
## descartar problemas de clamping y verificar que la curva se está
## sampleando correctamente sobre su dominio.
func test_weights_curve_basic_sampling_within_default_range():
	var w := _make_weights()
	var curve := Curve.new()
	curve.min_domain = 1.0
	curve.max_domain = 100.0
	# Valores dentro del [0, 1] default para no depender de max_value.
	curve.add_point(Vector2(1.0, 0.2))
	curve.add_point(Vector2(100.0, 0.8))
	w.flavour_curve = curve

	# La curva debe estar siendo usada (no el fallback de 1.0)
	var mid:float = w.get_weight(EventCategory.Type.FLAVOUR, 50)
	assert_between(mid, 0.2, 0.8)


func test_weights_clamps_turn_to_curve_domain():
	var w := _make_weights()
	var curve := _make_weight_curve(1.0, 100.0, 10.0)
	curve.add_point(Vector2(1.0, 2.0))
	curve.add_point(Vector2(100.0, 8.0))
	w.flavour_curve = curve

	# Turn dentro de dominio: interpolación entre 2.0 y 8.0 a turno 50
	var mid:float = w.get_weight(EventCategory.Type.FLAVOUR, 50)
	assert_between(mid, 2.0, 8.0)

	# Turn por encima del dominio: clampa al extremo (8.0)
	var beyond:float = w.get_weight(EventCategory.Type.FLAVOUR, 999)
	assert_almost_eq(beyond, 8.0, 0.01)

	# Turn por debajo del dominio: clampa al extremo (2.0)
	var below:float = w.get_weight(EventCategory.Type.FLAVOUR, 0)
	assert_almost_eq(below, 2.0, 0.01)


func test_weights_curve_takes_precedence_over_fallback():
	var w := _make_weights()
	w.flavour_fallback = 1.0
	# Curva constante en y=7.0 (dentro del rango max_value=10)
	var curve := _make_weight_curve(1.0, 100.0, 10.0)
	curve.add_point(Vector2(1.0, 7.0))
	curve.add_point(Vector2(100.0, 7.0))
	w.flavour_curve = curve
	# La curva (constante 7.0) debe ganar sobre el fallback 1.0
	assert_almost_eq(w.get_weight(EventCategory.Type.FLAVOUR, 30), 7.0, 0.01)


# ============================================================
#  EventCategoryWeights.event_chance dinámico
# ============================================================

func test_event_chance_returns_fallback_when_curve_is_null():
	var w := _make_weights()
	w.event_chance_fallback = 0.7
	assert_almost_eq(w.get_event_chance(15), 0.7, 0.0001)


func test_event_chance_uses_curve_when_present():
	var w := _make_weights()
	w.event_chance_fallback = 0.1
	# Curve dentro del rango por defecto [0, 1] (probabilidad)
	var curve := Curve.new()
	curve.min_domain = 1.0
	curve.max_domain = 100.0
	curve.add_point(Vector2(1.0, 0.5))
	curve.add_point(Vector2(100.0, 0.9))
	w.event_chance_curve = curve

	# La curva debe ganar sobre el fallback 0.1
	var early:float = w.get_event_chance(1)
	assert_almost_eq(early, 0.5, 0.01)
	var late:float = w.get_event_chance(100)
	assert_almost_eq(late, 0.9, 0.01)
	# A mitad, valor intermedio entre 0.5 y 0.9
	var mid:float = w.get_event_chance(50)
	assert_between(mid, 0.5, 0.9)


func test_event_chance_clamps_turn_to_curve_domain():
	var w := _make_weights()
	var curve := Curve.new()
	curve.min_domain = 1.0
	curve.max_domain = 100.0
	curve.add_point(Vector2(1.0, 0.5))
	curve.add_point(Vector2(100.0, 0.9))
	w.event_chance_curve = curve

	# Turn por encima del dominio se clampa al final de la curva
	assert_almost_eq(w.get_event_chance(999), 0.9, 0.01)
	# Turn por debajo del dominio se clampa al inicio
	assert_almost_eq(w.get_event_chance(0), 0.5, 0.01)


func test_event_chance_clamps_output_to_zero_one():
	# Aunque la curva pudiera devolver valores fuera de [0, 1] por
	# overshoot de tangentes, el método debe clampar el resultado.
	var w := _make_weights()
	var curve := Curve.new()
	curve.min_domain = 1.0
	curve.max_domain = 10.0
	curve.min_value = -5.0
	curve.max_value = 5.0
	curve.add_point(Vector2(1.0, -2.0))
	curve.add_point(Vector2(10.0, 3.0))
	w.event_chance_curve = curve

	# Valor inicial -2.0 debe clamparse a 0.0
	assert_almost_eq(w.get_event_chance(1), 0.0, 0.01)
	# Valor final 3.0 debe clamparse a 1.0
	assert_almost_eq(w.get_event_chance(10), 1.0, 0.01)


func test_manager_uses_event_chance_curve():
	# Con curva que devuelve 0.0, no debe disparar nunca
	var stats := _make_stats()
	stats.event_chance = 1.0  # legacy: si se usa, dispararía siempre
	var weights := _make_weights()
	var curve := Curve.new()
	curve.min_domain = 1.0
	curve.max_domain = 100.0
	curve.add_point(Vector2(1.0, 0.0))
	curve.add_point(Vector2(100.0, 0.0))
	weights.event_chance_curve = curve
	stats.category_weights = weights
	stats.available_events = [
		_make_categorized_event("a", EventCategory.Type.FLAVOUR)
	]
	var mgr := _make_manager(stats)
	var ctx := _make_context(stats)
	# La curva fuerza chance=0, el legacy stats.event_chance debe ignorarse
	for i in range(20):
		assert_null(mgr.evaluate(ctx))


func test_manager_falls_back_to_stats_event_chance_when_no_weights():
	# Si category_weights es null, el manager usa stats.event_chance legacy
	var stats := _make_stats()
	stats.event_chance = 0.0  # nunca dispara
	stats.category_weights = null
	stats.available_events = [
		_make_categorized_event("a", EventCategory.Type.FLAVOUR)
	]
	var mgr := _make_manager(stats)
	var ctx := _make_context(stats)
	for i in range(20):
		assert_null(mgr.evaluate(ctx))


# ============================================================
#  TurnEventManager con categorías
# ============================================================

func _make_manager(stats:Stats) -> TurnEventManager:
	var mgr := TurnEventManager.new()
	mgr.stats = stats
	add_child_autoqfree(mgr)
	return mgr


func _make_categorized_event(p_id:String, p_category:int,
		p_weight:float = 1.0, p_unique:bool = false) -> TurnEvent:
	var evt := TurnEvent.new()
	evt.id = p_id
	evt.weight = p_weight
	evt.unique = p_unique
	evt.category = p_category
	evt.conditions = []
	evt.choices = []
	return evt


func test_manager_returns_null_when_event_chance_fails():
	var stats := _make_stats()
	stats.available_events = [
		_make_categorized_event("a", EventCategory.Type.FLAVOUR)
	]
	# Forzamos event_chance=0 vía el fallback de category_weights.
	# (stats.event_chance legacy se ignora cuando hay category_weights)
	var weights := _make_weights()
	weights.event_chance_fallback = 0.0
	stats.category_weights = weights
	var mgr := _make_manager(stats)
	var ctx := _make_context(stats)
	# Con event_chance=0.0 nunca debe devolver evento
	for i in range(20):
		assert_null(mgr.evaluate(ctx))


func test_manager_returns_null_when_no_events_available():
	var stats := _make_stats()
	stats.event_chance = 1.0
	stats.available_events = []
	stats.category_weights = _make_weights()
	var mgr := _make_manager(stats)
	var ctx := _make_context(stats)
	assert_null(mgr.evaluate(ctx))


func test_manager_prioritizes_core_when_priority_chance_one():
	var stats := _make_stats()
	stats.event_chance = 1.0
	stats.available_events = [
		_make_categorized_event("core", EventCategory.Type.CORE_PROGRESSION),
		_make_categorized_event("flavour", EventCategory.Type.FLAVOUR),
	]
	stats.category_weights = _make_weights(1.0)  # CORE priority = 100%
	var mgr := _make_manager(stats)
	var ctx := _make_context(stats)
	# Con priority=1.0 siempre debe disparar el CORE
	for i in range(20):
		var picked = mgr.evaluate(ctx)
		assert_not_null(picked)
		assert_eq(picked.id, "core")


func test_manager_skips_core_priority_when_chance_zero():
	# Con priority=0.0 CORE nunca pasa la fase B y compite normal en C.
	# Si solo hay CORE disponible aún debe poder dispararse vía C.
	var stats := _make_stats()
	stats.event_chance = 1.0
	stats.available_events = [
		_make_categorized_event("core", EventCategory.Type.CORE_PROGRESSION),
	]
	stats.category_weights = _make_weights(0.0)
	var mgr := _make_manager(stats)
	var ctx := _make_context(stats)
	var picked = mgr.evaluate(ctx)
	assert_not_null(picked)
	assert_eq(picked.id, "core")


func test_manager_excludes_categories_without_candidates():
	# Solo hay un evento DECK disponible: el manager solo puede pickear DECK.
	var stats := _make_stats()
	stats.event_chance = 1.0
	stats.available_events = [
		_make_categorized_event("deck_only", EventCategory.Type.DECK),
	]
	stats.category_weights = _make_weights()
	var mgr := _make_manager(stats)
	var ctx := _make_context(stats)
	for i in range(10):
		var picked = mgr.evaluate(ctx)
		assert_not_null(picked)
		assert_eq(picked.id, "deck_only")


func test_manager_skips_used_unique_events():
	var stats := _make_stats()
	stats.event_chance = 1.0
	stats.available_events = [
		_make_categorized_event("once", EventCategory.Type.FLAVOUR, 1.0, true),
	]
	stats.used_unique_events = ["once"]
	stats.category_weights = _make_weights()
	var mgr := _make_manager(stats)
	var ctx := _make_context(stats)
	# El único evento ya está consumido, no hay nada que disparar
	assert_null(mgr.evaluate(ctx))


func test_manager_resolve_marks_unique_as_used():
	var stats := _make_stats()
	var evt := _make_categorized_event("uniq", EventCategory.Type.FLAVOUR, 1.0, true)
	var choice := TurnEventChoice.new()
	choice.effects = []
	evt.choices = [choice]
	var mgr := _make_manager(stats)
	var ctx := _make_context(stats)
	mgr.resolve(evt, choice, ctx)
	assert_has(stats.used_unique_events, "uniq")


func test_manager_works_without_category_weights():
	# Si stats.category_weights es null, el manager cae a peso uniforme
	# por categoría y core_priority_chance default = 0.9.
	var stats := _make_stats()
	stats.event_chance = 1.0
	stats.category_weights = null
	stats.available_events = [
		_make_categorized_event("only", EventCategory.Type.FLAVOUR),
	]
	var mgr := _make_manager(stats)
	var ctx := _make_context(stats)
	var picked = mgr.evaluate(ctx)
	assert_not_null(picked)
	assert_eq(picked.id, "only")


# ============================================================
#  Asignación de categoría en eventos representativos
# ============================================================

func test_construction_boom_is_core_progression():
	var evt := ConstructionBoomEvent.new()
	assert_eq(evt.category, EventCategory.Type.CORE_PROGRESSION)


func test_unlock_recruit_is_core_progression():
	var evt := UnlockRecruitEvent.new()
	assert_eq(evt.category, EventCategory.Type.CORE_PROGRESSION)


func test_unlock_upgrade_is_core_progression():
	var evt := UnlockUpgradeEvent.new()
	assert_eq(evt.category, EventCategory.Type.CORE_PROGRESSION)


func test_unlock_caravana_is_optional_progression():
	var evt := UnlockCaravanaEvent.new()
	assert_eq(evt.category, EventCategory.Type.OPTIONAL_PROGRESSION)


func test_unlock_palacio_is_optional_progression():
	var evt := UnlockPalacioEvent.new()
	assert_eq(evt.category, EventCategory.Type.OPTIONAL_PROGRESSION)


func test_bandits_is_flavour():
	var evt := BanditsEvent.new()
	assert_eq(evt.category, EventCategory.Type.FLAVOUR)


func test_wise_travelers_is_flavour():
	var evt := WiseTravelersEvent.new()
	assert_eq(evt.category, EventCategory.Type.FLAVOUR)


func test_mercenaries_is_flavour():
	var evt := MercenariesEvent.new()
	assert_eq(evt.category, EventCategory.Type.FLAVOUR)


func test_card_offering_is_deck():
	var evt := CardOfferingEvent.new()
	assert_eq(evt.category, EventCategory.Type.DECK)


func test_deck_purge_is_deck():
	var evt := DeckPurgeEvent.new()
	assert_eq(evt.category, EventCategory.Type.DECK)


func test_basic_shop_is_shop():
	var evt := BasicShopEvent.new()
	assert_eq(evt.category, EventCategory.Type.SHOP)


func test_special_shop_is_shop():
	var evt := SpecialShopEvent.new()
	assert_eq(evt.category, EventCategory.Type.SHOP)


func test_spirit_pacto_is_spirit():
	var evt := SpiritPactoEvent.new()
	assert_eq(evt.category, EventCategory.Type.SPIRIT)


func test_megalopolis_is_decision():
	var evt := MegalopolisEvent.new()
	assert_eq(evt.category, EventCategory.Type.DECISION)


func test_default_turn_event_category_is_flavour():
	# Un TurnEvent.new() sin categoría explícita debe defaultear a FLAVOUR
	# (definido en turn_event.gd para los tests/factories que no setean
	# categoría explícitamente).
	var evt := TurnEvent.new()
	assert_eq(evt.category, EventCategory.Type.FLAVOUR)
