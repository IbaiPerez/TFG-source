extends GutTest

## Tests para la resolución de tienda de la simulación (Fase C v2 — F2.5c).
## La tienda es un ShopEvent que se enruta por el mismo chance node. Lo crítico
## (PLAN §3.7) es que el mazo refleje compras/purgas; la decisión es suelo
## heurístico. Cubre: compra, no-compra por oro/umbral, purga, protección de
## ColonizeCard, límite de purgas, escalado de precio y disparo end-to-end.


func _rng(s: int = 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _entry(card: Card, weight: float = 5.0) -> UnlockedCardEntry:
	return UnlockedCardEntry.new(card, weight, 0.0, 1.0)


func _draw_card(id: String = "draw") -> CardDrawCard:
	var c := CardDrawCard.new()
	c.id = id
	c.amount = 1
	return c


func _generic_card(id: String, type: int = 0) -> Card:
	var c := Card.new()
	c.id = id
	c.type = type
	return c


func _basic_shop() -> ShopEvent:
	var e := ShopEvent.new()
	e.id = "basic_shop"
	e.category = EventCategory.Type.SHOP
	e.shop_type = ShopEvent.ShopType.BASIC
	return e


# ============================================================
#  Compra
# ============================================================

func test_shop_buys_affordable_valuable_card() -> void:
	var s := AIRealState.new()
	s.own.gold = 1000
	s.own.unlocked_card_pool = [_entry(_draw_card())] as Array[UnlockedCardEntry]
	AIRealEvents._resolve_shop(_basic_shop(), s.own, 10, _rng())
	assert_eq(s.own.deck.size(), 1, "Compra la carta del pool (valiosa y asequible)")
	assert_lt(s.own.gold, 1000, "El oro disminuye por la compra")


func test_shop_does_not_buy_when_too_expensive() -> void:
	var s := AIRealState.new()
	s.own.gold = 5   # menos que cualquier precio base (mín 30)
	s.own.unlocked_card_pool = [_entry(_draw_card())] as Array[UnlockedCardEntry]
	AIRealEvents._resolve_shop(_basic_shop(), s.own, 10, _rng())
	assert_eq(s.own.deck.size(), 0, "Sin oro suficiente no compra")
	assert_eq(s.own.gold, 5, "El oro no cambia")


func test_shop_skips_low_value_card_with_large_deck() -> void:
	# Aislamos la DECISIÓN de compra (la purga también actuaría sobre un mazo
	# grande, así que comprobamos _should_buy directamente).
	var s := AIRealState.new()
	var deck: Array[Card] = []
	for i in range(20):
		deck.append(_generic_card("c%d" % i))
	s.own.deck = deck
	var cheap := _generic_card("cheap")
	assert_false(AIRealEvents._should_buy(cheap, s.own),
		"Con mazo grande, una carta de bajo valor no supera el umbral de compra")
	# Una carta valiosa (CardDraw) sí se compraría aun con mazo grande.
	assert_true(AIRealEvents._should_buy(_draw_card(), s.own),
		"Una carta valiosa sí supera el umbral incluso con mazo grande")


# ============================================================
#  Purga
# ============================================================

func test_shop_purges_weakest_card_when_deck_large() -> void:
	var s := AIRealState.new()
	s.own.gold = 100
	var deck: Array[Card] = []
	for i in range(20):
		deck.append(_generic_card("c%d" % i))
	s.own.deck = deck
	# Pool vacío → no compra; solo prueba la purga.
	AIRealEvents._resolve_shop(_basic_shop(), s.own, 5, _rng())
	assert_eq(s.own.deck.size(), 19, "Purga 1 carta (max_purges básico = 1)")
	assert_eq(s.own.gold, 80, "Descuenta el coste de purga (20)")
	assert_eq(s.own.total_purges_done, 1, "Incrementa el contador global de purgas")


func test_shop_does_not_purge_small_valuable_deck() -> void:
	var s := AIRealState.new()
	s.own.gold = 100
	# Mazo pequeño de cartas valiosas (CardDraw) → por encima del umbral de purga.
	s.own.deck = [_draw_card("a"), _draw_card("b")] as Array[Card]
	AIRealEvents._resolve_shop(_basic_shop(), s.own, 5, _rng())
	assert_eq(s.own.deck.size(), 2, "No purga un mazo pequeño y valioso")
	assert_eq(s.own.gold, 100, "El oro no cambia")


func test_shop_protects_last_colonize_card() -> void:
	var s := AIRealState.new()
	s.own.gold = 100
	# Mazo grande pero con una única ColonizeCard: debe conservarse.
	var deck: Array[Card] = [ColonizeCard.new()]
	for i in range(20):
		deck.append(_generic_card("c%d" % i))
	s.own.deck = deck
	AIRealEvents._resolve_shop(_basic_shop(), s.own, 5, _rng())
	var colonize_left := 0
	for c in s.own.deck:
		if c is ColonizeCard:
			colonize_left += 1
	assert_eq(colonize_left, 1, "La última ColonizeCard nunca se purga")


func test_shop_purge_cost_scales_with_total_purges() -> void:
	var s := AIRealState.new()
	s.own.gold = 100
	s.own.total_purges_done = 2   # coste = 20 + 2*8 = 36
	var deck: Array[Card] = []
	for i in range(20):
		deck.append(_generic_card("c%d" % i))
	s.own.deck = deck
	AIRealEvents._resolve_shop(_basic_shop(), s.own, 5, _rng())
	assert_eq(s.own.gold, 64, "Coste de purga escalado: 100 − (20 + 2×8)")


# ============================================================
#  Precio
# ============================================================

func test_shop_price_within_scaled_range() -> void:
	var s := AIRealState.new()
	s.own.gold = 1000
	s.own.unlocked_card_pool = [_entry(_draw_card())] as Array[UnlockedCardEntry]
	AIRealEvents._resolve_shop(_basic_shop(), s.own, 8, _rng())  # turno = base_turn → sin escalado
	var spent := 1000 - s.own.gold
	# CardDraw es BASIC → precio base en [30, 50] sin escalado en turno 8.
	assert_between(spent, 30, 50, "El precio cae en el rango base BASIC sin escalado")


# ============================================================
#  Disparo end-to-end vía el chance node
# ============================================================

func test_shop_fires_through_process_turn_event() -> void:
	var s := AIRealState.new()
	s.own.gold = 1000
	s.own.unlocked_card_pool = [_entry(_draw_card())] as Array[UnlockedCardEntry]
	var shop := _basic_shop()
	s.own.available_events = [shop] as Array[TurnEvent]
	var w := EventCategoryWeights.new()
	w.event_chance_curve = null
	w.event_chance_fallback = 1.0
	s.own.category_weights = w
	var fired := AIRealEvents.process_turn_event(s, AIRealState.OWNER_SELF, _rng())
	assert_eq(fired, shop, "El ShopEvent dispara por el chance node")
	assert_eq(s.own.deck.size(), 1, "La tienda compró la carta durante la resolución")
