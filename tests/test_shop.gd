extends GutTest
## Tests para el sistema de tienda: ShopItem, ShopConfig, ShopGenerator, ShopEvent.


# ============================================================
#  Helpers
# ============================================================

func _make_stats(p_gold:int = 100, p_turn:int = 10) -> Stats:
	var s := Stats.new()
	s.total_gold = p_gold
	s.gold_per_turn = 15
	s.food = 10
	s.cards_per_turn = 3
	s.draw_pile = CardPile.new()
	s.discard_pile = CardPile.new()
	s.played_pile = CardPile.new()
	s.deck = CardPile.new()
	s.empire = Empire.new()
	s.empire.controlled_tiles = []
	s.used_unique_events = []
	s.available_events = []
	s.event_chance = 1.0
	s.turn_number = p_turn
	s.total_purges_done = 0
	return s


func _make_card(p_id:String = "test", p_type:Card.Type = Card.Type.BASIC) -> Card:
	var c := Card.new()
	c.id = p_id
	c.type = p_type
	return c


func _make_context(stats:Stats, turn:int = 10) -> EventContext:
	var mgr := ModifierManager.new()
	add_child_autoqfree(mgr)
	return EventContext.build(stats, mgr, turn)


func _make_shop_item(card:Card = null, price:int = 30, stock:int = 1) -> ShopItem:
	var item := ShopItem.new()
	item.card = card if card else _make_card()
	item.price = price
	item.stock = stock
	return item


func _make_shop_config() -> ShopConfig:
	var config := ShopConfig.new()
	config.purge_cost = 20
	config.allow_purge = true
	config.max_purges = 2
	return config


# ============================================================
#  ShopItem
# ============================================================

func test_item_is_available_with_stock():
	var item := _make_shop_item(null, 30, 2)
	assert_true(item.is_available())


func test_item_not_available_after_sold_out():
	var item := _make_shop_item(null, 30, 1)
	var stats := _make_stats(100)
	item.purchase(stats)
	assert_false(item.is_available())


func test_item_unlimited_stock():
	var item := _make_shop_item(null, 10, -1)
	var stats := _make_stats(1000)
	for i in 5:
		item.purchase(stats)
	assert_true(item.is_available(), "Stock -1 deberia ser ilimitado")


func test_item_can_afford_true():
	var item := _make_shop_item(null, 30)
	assert_true(item.can_afford(50))


func test_item_can_afford_exact():
	var item := _make_shop_item(null, 30)
	assert_true(item.can_afford(30))


func test_item_cannot_afford():
	var item := _make_shop_item(null, 30)
	assert_false(item.can_afford(20))


func test_item_purchase_deducts_gold():
	var stats := _make_stats(100)
	var item := _make_shop_item(null, 35)
	item.purchase(stats)
	assert_eq(stats.total_gold, 65)


func test_item_purchase_adds_card_to_discard():
	var stats := _make_stats(100)
	var card := _make_card("purchased_card")
	var item := _make_shop_item(card, 10)
	item.purchase(stats)
	assert_eq(stats.discard_pile.cards.size(), 1)
	assert_eq(stats.discard_pile.cards[0].id, "purchased_card")


func test_item_purchase_duplicates_card():
	var stats := _make_stats(100)
	var original := _make_card("original")
	var item := _make_shop_item(original, 10)
	item.purchase(stats)
	# La carta en el discard_pile no debe ser la misma instancia
	assert_ne(stats.discard_pile.cards[0], original,
		"Deberia duplicar la carta, no usar la misma instancia")


func test_item_purchase_increments_sold_count():
	var stats := _make_stats(1000)
	var item := _make_shop_item(null, 10, 3)
	item.purchase(stats)
	item.purchase(stats)
	assert_eq(item._sold_count, 2)


# ============================================================
#  ShopConfig - Purga
# ============================================================

func test_config_can_purge_with_gold():
	var config := _make_shop_config()
	assert_true(config.can_purge(50))


func test_config_cannot_purge_without_gold():
	var config := _make_shop_config()
	assert_false(config.can_purge(10))


func test_config_cannot_purge_when_disabled():
	var config := _make_shop_config()
	config.allow_purge = false
	assert_false(config.can_purge(100))


func test_config_cannot_purge_over_max():
	var config := _make_shop_config()
	config.max_purges = 1
	config._purges_done_this_visit = 1
	assert_false(config.can_purge(100))


func test_config_purge_removes_from_draw_pile():
	var config := _make_shop_config()
	var stats := _make_stats(100)
	var card := _make_card("to_remove")
	stats.draw_pile.add_card(card)
	var result := config.purge_card(card, stats)
	assert_true(result)
	assert_true(stats.draw_pile.empty())


func test_config_purge_removes_from_discard_pile():
	var config := _make_shop_config()
	var stats := _make_stats(100)
	var card := _make_card("to_remove")
	stats.discard_pile.add_card(card)
	var result := config.purge_card(card, stats)
	assert_true(result)
	assert_true(stats.discard_pile.empty())


func test_config_purge_deducts_gold():
	var config := _make_shop_config()
	config.purge_cost = 25
	var stats := _make_stats(100)
	var card := _make_card("to_remove")
	stats.draw_pile.add_card(card)
	config.purge_card(card, stats)
	assert_eq(stats.total_gold, 75)


func test_config_purge_increments_global_counter():
	var config := _make_shop_config()
	var stats := _make_stats(100)
	var card := _make_card("to_remove")
	stats.draw_pile.add_card(card)
	config.purge_card(card, stats)
	assert_eq(stats.total_purges_done, 1)


func test_config_purge_increments_visit_counter():
	var config := _make_shop_config()
	var stats := _make_stats(100)
	var card := _make_card("to_remove")
	stats.draw_pile.add_card(card)
	config.purge_card(card, stats)
	assert_eq(config._purges_done_this_visit, 1)


func test_config_purge_cost_scales_after_purge():
	var config := _make_shop_config()
	config.purge_cost = ShopGenerator._get_purge_cost(0)  # 20
	var stats := _make_stats(200)
	var card1 := _make_card("c1")
	var card2 := _make_card("c2")
	stats.draw_pile.add_card(card1)
	stats.draw_pile.add_card(card2)

	var first_cost := config.purge_cost
	config.purge_card(card1, stats)
	var second_cost := config.purge_cost

	assert_gt(second_cost, first_cost,
		"El coste de purga deberia aumentar tras cada uso")


func test_config_purge_fails_if_card_not_in_piles():
	var config := _make_shop_config()
	var stats := _make_stats(100)
	var card := _make_card("ghost")
	var result := config.purge_card(card, stats)
	assert_false(result)
	assert_eq(stats.total_gold, 100, "No deberia deducir oro si falla")


func test_config_purge_fails_without_gold():
	var config := _make_shop_config()
	config.purge_cost = 50
	var stats := _make_stats(30)
	var card := _make_card("to_remove")
	stats.draw_pile.add_card(card)
	var result := config.purge_card(card, stats)
	assert_false(result)
	assert_eq(stats.draw_pile.cards.size(), 1, "La carta no deberia eliminarse")


# ============================================================
#  ShopGenerator - Escalado de precios
# ============================================================

func test_purge_cost_base():
	var cost := ShopGenerator._get_purge_cost(0)
	assert_eq(cost, 20, "Coste base de purga deberia ser 20")


func test_purge_cost_scales_linearly():
	var cost_0 := ShopGenerator._get_purge_cost(0)
	var cost_1 := ShopGenerator._get_purge_cost(1)
	var cost_3 := ShopGenerator._get_purge_cost(3)
	assert_eq(cost_0, 20)
	assert_eq(cost_1, 28)   # 20 + 1*8
	assert_eq(cost_3, 44)   # 20 + 3*8


func test_scaled_price_no_scaling_at_base_turn():
	# En el turno base, no hay escalado
	var price := ShopGenerator._scaled_price(40, 40, 8, 8)
	assert_eq(price, 40, "Sin escalado en el turno base")


func test_scaled_price_increases_past_base_turn():
	# 5 turnos despues del base: +10% (5 * 0.02)
	# Con base fijo 40: 40 * 1.10 = 44
	var price := ShopGenerator._scaled_price(40, 40, 13, 8)
	assert_eq(price, 44)


func test_scaled_price_no_negative_scaling():
	# Antes del turno base no hay escalado negativo
	var price := ShopGenerator._scaled_price(40, 40, 5, 8)
	assert_eq(price, 40, "No deberia haber escalado negativo antes del turno base")


# ============================================================
#  ShopGenerator - Generacion de tiendas
# ============================================================

func test_basic_shop_has_2_or_3_items():
	var stats := _make_stats(100, 10)
	# Forzar pool con cartas de test
	ShopGenerator._pool_loaded = true
	ShopGenerator._basic_cards = [
		_make_card("b1"), _make_card("b2"), _make_card("b3"), _make_card("b4"),
	]
	ShopGenerator._special_cards = [_make_card("s1", Card.Type.SPECIAL)]
	ShopGenerator._single_use_cards = [_make_card("su1", Card.Type.SINGLE_USE)]

	var config := ShopGenerator.generate_basic_shop(stats)
	assert_gte(config.items.size(), 2, "Minimo 2 items")
	assert_lte(config.items.size(), 3, "Maximo 3 items")


func test_basic_shop_allows_1_purge():
	var stats := _make_stats(100, 10)
	ShopGenerator._pool_loaded = true
	ShopGenerator._basic_cards = [_make_card("b1"), _make_card("b2"), _make_card("b3")]
	var config := ShopGenerator.generate_basic_shop(stats)
	assert_true(config.allow_purge)
	assert_eq(config.max_purges, 1)


func test_basic_shop_prices_in_range():
	var stats := _make_stats(100, 8)  # Turno base, sin escalado
	ShopGenerator._pool_loaded = true
	ShopGenerator._basic_cards = [_make_card("b1"), _make_card("b2"), _make_card("b3")]
	var config := ShopGenerator.generate_basic_shop(stats)
	for item in config.items:
		assert_gte(item.price, 30, "Precio minimo basico: 30")
		assert_lte(item.price, 50, "Precio maximo basico: 50")


func test_special_shop_has_3_items():
	var stats := _make_stats(100, 14)
	ShopGenerator._pool_loaded = true
	ShopGenerator._basic_cards = [_make_card("b1"), _make_card("b2")]
	ShopGenerator._special_cards = [
		_make_card("s1", Card.Type.SPECIAL),
		_make_card("s2", Card.Type.SPECIAL),
	]
	ShopGenerator._single_use_cards = [_make_card("su1", Card.Type.SINGLE_USE)]

	var config := ShopGenerator.generate_special_shop(stats)
	assert_eq(config.items.size(), 3, "1 basica + 1 especial + 1 mixta")


func test_special_shop_allows_2_or_3_purges():
	var stats := _make_stats(100, 14)
	ShopGenerator._pool_loaded = true
	ShopGenerator._basic_cards = [_make_card("b1")]
	ShopGenerator._special_cards = [_make_card("s1", Card.Type.SPECIAL)]
	ShopGenerator._single_use_cards = [_make_card("su1", Card.Type.SINGLE_USE)]

	var config := ShopGenerator.generate_special_shop(stats)
	assert_true(config.allow_purge)
	assert_gte(config.max_purges, 2)
	assert_lte(config.max_purges, 3)


func test_special_shop_prices_basic_in_range():
	var stats := _make_stats(100, 12)  # Turno base especial
	ShopGenerator._pool_loaded = true
	ShopGenerator._basic_cards = [_make_card("b1")]
	ShopGenerator._special_cards = [_make_card("s1", Card.Type.SPECIAL)]
	ShopGenerator._single_use_cards = [_make_card("su1", Card.Type.SINGLE_USE)]

	var config := ShopGenerator.generate_special_shop(stats)
	# Primer item es basico
	assert_gte(config.items[0].price, 30)
	assert_lte(config.items[0].price, 50)


func test_special_shop_prices_special_in_range():
	var stats := _make_stats(100, 12)  # Turno base especial
	ShopGenerator._pool_loaded = true
	ShopGenerator._basic_cards = [_make_card("b1")]
	ShopGenerator._special_cards = [_make_card("s1", Card.Type.SPECIAL)]
	ShopGenerator._single_use_cards = [_make_card("su1", Card.Type.SINGLE_USE)]

	var config := ShopGenerator.generate_special_shop(stats)
	# Items 2 y 3 son especiales
	assert_gte(config.items[1].price, 50)
	assert_lte(config.items[1].price, 80)


func test_generator_items_have_stock_1():
	var stats := _make_stats(100, 10)
	ShopGenerator._pool_loaded = true
	ShopGenerator._basic_cards = [_make_card("b1"), _make_card("b2"), _make_card("b3")]

	var config := ShopGenerator.generate_basic_shop(stats)
	for item in config.items:
		assert_eq(item.stock, 1, "Cada item deberia tener stock 1")


func test_generator_purge_cost_uses_global_count():
	var stats := _make_stats(100, 10)
	stats.total_purges_done = 3
	ShopGenerator._pool_loaded = true
	ShopGenerator._basic_cards = [_make_card("b1"), _make_card("b2")]

	var config := ShopGenerator.generate_basic_shop(stats)
	var expected := ShopGenerator._get_purge_cost(3)  # 20 + 3*8 = 44
	assert_eq(config.purge_cost, expected)


func test_pick_random_cards_no_duplicates():
	ShopGenerator._pool_loaded = true
	var pool:Array[Card] = [
		_make_card("a"), _make_card("b"), _make_card("c"), _make_card("d"),
	]
	var picked := ShopGenerator._pick_random_cards(pool, 3)
	assert_eq(picked.size(), 3)

	# Verificar que no hay duplicados
	var ids := {}
	for card in picked:
		assert_false(ids.has(card.id), "No deberia haber cartas duplicadas")
		ids[card.id] = true


func test_pick_random_cards_empty_pool():
	var pool:Array[Card] = []
	var picked := ShopGenerator._pick_random_cards(pool, 3)
	assert_eq(picked.size(), 0)


func test_pick_random_cards_pool_smaller_than_count():
	var pool:Array[Card] = [_make_card("a")]
	var picked := ShopGenerator._pick_random_cards(pool, 5)
	assert_eq(picked.size(), 1, "No deberia pedir mas cartas de las disponibles")


# ============================================================
#  ShopEvent - Condiciones
# ============================================================

func test_basic_shop_event_not_available_early():
	var evt := BasicShopEvent.new()
	var stats := _make_stats(100, 5)
	var ctx := _make_context(stats, 5)
	assert_false(evt.is_available(ctx), "No deberia estar disponible antes del turno 8")


func test_basic_shop_event_available_at_turn_8():
	var evt := BasicShopEvent.new()
	var stats := _make_stats(100, 8)
	# Necesita 3+ tiles controlados
	for i in 3:
		var t := Tile.new()
		add_child_autoqfree(t)
		stats.empire.controlled_tiles.append(t)
	var ctx := _make_context(stats, 8)
	assert_true(evt.is_available(ctx))


func test_special_shop_event_not_available_early():
	var evt := SpecialShopEvent.new()
	var stats := _make_stats(100, 10)
	for i in 5:
		var t := Tile.new()
		add_child_autoqfree(t)
		stats.empire.controlled_tiles.append(t)
	var ctx := _make_context(stats, 10)
	assert_false(evt.is_available(ctx), "No deberia estar disponible antes del turno 12")


func test_special_shop_event_available_at_turn_12():
	var evt := SpecialShopEvent.new()
	var stats := _make_stats(100, 12)
	for i in 5:
		var t := Tile.new()
		add_child_autoqfree(t)
		stats.empire.controlled_tiles.append(t)
	var ctx := _make_context(stats, 12)
	assert_true(evt.is_available(ctx))


func test_special_shop_event_not_available_low_gold():
	var evt := SpecialShopEvent.new()
	var stats := _make_stats(20, 14)
	for i in 6:
		var t := Tile.new()
		add_child_autoqfree(t)
		stats.empire.controlled_tiles.append(t)
	var ctx := _make_context(stats, 14)
	assert_false(evt.is_available(ctx), "Necesita 40+ oro")


func test_special_shop_event_not_available_few_tiles():
	var evt := SpecialShopEvent.new()
	var stats := _make_stats(100, 14)
	for i in 3:
		var t := Tile.new()
		add_child_autoqfree(t)
		stats.empire.controlled_tiles.append(t)
	var ctx := _make_context(stats, 14)
	assert_false(evt.is_available(ctx), "Necesita 5+ tiles controlados")


# ============================================================
#  ShopEvent - Generacion
# ============================================================

func test_shop_event_generates_basic_config():
	var evt := BasicShopEvent.new()
	var stats := _make_stats(100, 10)
	ShopGenerator._pool_loaded = true
	ShopGenerator._basic_cards = [_make_card("b1"), _make_card("b2"), _make_card("b3")]

	var config := evt.generate_shop(stats)
	assert_not_null(config)
	assert_gte(config.items.size(), 2)
	assert_eq(config.max_purges, 1)


func test_shop_event_generates_special_config():
	var evt := SpecialShopEvent.new()
	var stats := _make_stats(100, 14)
	ShopGenerator._pool_loaded = true
	ShopGenerator._basic_cards = [_make_card("b1")]
	ShopGenerator._special_cards = [_make_card("s1", Card.Type.SPECIAL)]
	ShopGenerator._single_use_cards = [_make_card("su1", Card.Type.SINGLE_USE)]

	var config := evt.generate_shop(stats)
	assert_not_null(config)
	assert_eq(config.items.size(), 3)
	assert_gte(config.max_purges, 2)


# ============================================================
#  Integracion: flujo completo compra + purga
# ============================================================

func test_full_buy_and_purge_flow():
	var stats := _make_stats(200, 10)
	stats.draw_pile.add_card(_make_card("old_card"))

	ShopGenerator._pool_loaded = true
	ShopGenerator._basic_cards = [_make_card("new_basic"), _make_card("b2")]

	var config := ShopGenerator.generate_basic_shop(stats)
	var initial_gold := stats.total_gold

	# Comprar primer item
	var item := config.items[0]
	var buy_price := item.price
	assert_true(item.can_afford(stats.total_gold))
	item.purchase(stats)
	assert_eq(stats.total_gold, initial_gold - buy_price)
	assert_eq(stats.discard_pile.cards.size(), 1)

	# Purgar carta del draw_pile
	var purge_cost := config.purge_cost
	var gold_before_purge := stats.total_gold
	var card_to_purge := stats.draw_pile.cards[0]
	assert_true(config.can_purge(stats.total_gold))
	config.purge_card(card_to_purge, stats)
	assert_eq(stats.total_gold, gold_before_purge - purge_cost)
	assert_true(stats.draw_pile.empty())
	assert_eq(stats.total_purges_done, 1)

	# No deberia poder purgar mas (max_purges = 1 en basica)
	assert_false(config.can_purge(stats.total_gold))


func test_purge_cost_escalation_across_visits():
	## Simula dos visitas a la tienda para verificar que el coste
	## de purga se acumula entre visitas.
	var stats := _make_stats(500, 10)
	stats.draw_pile.add_card(_make_card("c1"))
	stats.draw_pile.add_card(_make_card("c2"))
	stats.draw_pile.add_card(_make_card("c3"))

	ShopGenerator._pool_loaded = true
	ShopGenerator._basic_cards = [_make_card("b1"), _make_card("b2")]

	# Primera visita
	var config1 := ShopGenerator.generate_basic_shop(stats)
	var cost1 := config1.purge_cost
	assert_eq(cost1, 20, "Primera purga: coste base")
	config1.purge_card(stats.draw_pile.cards[0], stats)
	assert_eq(stats.total_purges_done, 1)

	# Segunda visita (nueva config)
	var config2 := ShopGenerator.generate_basic_shop(stats)
	var cost2 := config2.purge_cost
	assert_eq(cost2, 28, "Segunda visita: coste escalado (20 + 1*8)")
	config2.purge_card(stats.draw_pile.cards[0], stats)

	# Tercera visita
	var config3 := ShopGenerator.generate_basic_shop(stats)
	var cost3 := config3.purge_cost
	assert_eq(cost3, 36, "Tercera visita: coste escalado (20 + 2*8)")


# ============================================================
#  Limpieza del estado estatico del generador
# ============================================================

func after_each():
	# Resetear el pool cacheado para no contaminar otros tests
	ShopGenerator._pool_loaded = false
	ShopGenerator._basic_cards.clear()
	ShopGenerator._special_cards.clear()
	ShopGenerator._single_use_cards.clear()
