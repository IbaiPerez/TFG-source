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


## Resuelve la tienda sobre el imperio propio de `s` (C6 §1.6.5b: _resolve_shop
## recibe state/owner para poder construir la vista del valorador unificado).
func _resolve(s: AIRealState, turn: int, rng: RandomNumberGenerator) -> void:
	AIRealShop._resolve_shop(_basic_shop(), s, AIRealState.OWNER_SELF, s.own, turn, rng)


## Vista del imperio propio, para los helpers de decisión que la reciben.
func _view(s: AIRealState) -> SnapshotStateView:
	return SnapshotStateView.new(s, AIRealState.OWNER_SELF, HeuristicWeights.get_default())


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
	_resolve(s, 10, _rng())
	assert_eq(s.own.deck.size(), 1, "Compra la carta del pool (valiosa y asequible)")
	assert_lt(s.own.gold, 1000, "El oro disminuye por la compra")


func test_shop_does_not_buy_when_too_expensive() -> void:
	var s := AIRealState.new()
	s.own.gold = 5   # menos que cualquier precio base (mín 30)
	s.own.unlocked_card_pool = [_entry(_draw_card())] as Array[UnlockedCardEntry]
	_resolve(s, 10, _rng())
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
	assert_false(AIShopPolicy.should_buy(_view(s), cheap),
		"Con mazo grande, una carta de bajo valor no supera el umbral de compra")
	# Una carta valiosa (CardDraw) sí se compraría aun con mazo grande.
	assert_true(AIShopPolicy.should_buy(_view(s), _draw_card()),
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
	_resolve(s, 5, _rng())
	assert_eq(s.own.deck.size(), 19, "Purga 1 carta (max_purges básico = 1)")
	assert_eq(s.own.gold, 80, "Descuenta el coste de purga (20)")
	assert_eq(s.own.total_purges_done, 1, "Incrementa el contador global de purgas")


func test_shop_does_not_purge_small_valuable_deck() -> void:
	var s := AIRealState.new()
	s.own.gold = 100
	# Mazo pequeño de cartas valiosas (CardDraw) → por encima del umbral de purga.
	s.own.deck = [_draw_card("a"), _draw_card("b")] as Array[Card]
	_resolve(s, 5, _rng())
	assert_eq(s.own.deck.size(), 2, "No purga un mazo pequeño y valioso")
	assert_eq(s.own.gold, 100, "El oro no cambia")


## Casilla propia con un vecino libre → colonizable_count() > 0.
func _with_colonizable_tile(s: AIRealState) -> void:
	var own_tile := AIRealState.TileSnap.new()
	own_tile.id = 0
	own_tile.owner = AIRealState.OWNER_SELF
	own_tile.location_type = Tile.location_type.Village
	own_tile.max_buildings = 3
	own_tile.neighbor_ids = [1]
	var free_tile := AIRealState.TileSnap.new()
	free_tile.id = 1
	free_tile.owner = AIRealState.OWNER_NONE
	free_tile.location_type = Tile.location_type.Uncolonized
	free_tile.max_buildings = 3
	free_tile.neighbor_ids = [0]
	s.tiles[0] = own_tile
	s.tiles[1] = free_tile


func _colonize_cards_in(s: AIRealState) -> int:
	var n := 0
	for c in s.own.deck:
		if c is ColonizeCard:
			n += 1
	return n


func test_shop_protects_last_colonize_card_while_expansion_possible() -> void:
	var s := AIRealState.new()
	s.own.gold = 100
	_with_colonizable_tile(s)   # queda territorio libre → la protección aplica
	# Mazo grande pero con una única ColonizeCard: debe conservarse.
	var deck: Array[Card] = [ColonizeCard.new()]
	for i in range(20):
		deck.append(_generic_card("c%d" % i))
	s.own.deck = deck
	_resolve(s, 5, _rng())
	assert_eq(_colonize_cards_in(s), 1,
		"Con casillas colonizables, la última ColonizeCard nunca se purga")


func test_shop_purges_colonize_card_when_nothing_left_to_colonize() -> void:
	# Regla unificada (C6 §1.6.4, semántica del mundo vivo): la protección exige que
	# QUEDE algo que colonizar. Sin territorio libre la carta es inútil y es purgable.
	# El espejo del snapshot la protegía siempre, aunque el mapa estuviera cerrado.
	var s := AIRealState.new()
	s.own.gold = 100
	# Sin tiles → colonizable_count() == 0.
	var deck: Array[Card] = [ColonizeCard.new()]
	for i in range(20):
		deck.append(_generic_card("c%d" % i))
	s.own.deck = deck
	_resolve(s, 5, _rng())
	assert_eq(_colonize_cards_in(s), 0,
		"Sin nada que colonizar, la ColonizeCard es la primera en purgarse")


func test_shop_purge_cost_scales_with_total_purges() -> void:
	var s := AIRealState.new()
	s.own.gold = 100
	s.own.total_purges_done = 2   # coste = 20 + 2*8 = 36
	var deck: Array[Card] = []
	for i in range(20):
		deck.append(_generic_card("c%d" % i))
	s.own.deck = deck
	_resolve(s, 5, _rng())
	assert_eq(s.own.gold, 64, "Coste de purga escalado: 100 − (20 + 2×8)")


# ============================================================
#  Precio
# ============================================================

func test_shop_price_within_scaled_range() -> void:
	var s := AIRealState.new()
	s.own.gold = 1000
	s.own.unlocked_card_pool = [_entry(_draw_card())] as Array[UnlockedCardEntry]
	_resolve(s, 8, _rng())  # turno = base_turn → sin escalado
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
