extends GutTest

## INVARIANTE: ninguna carta que un imperio pueda jugar es el Resource compartido
## del `.tres`; siempre es una copia suya.
##
## Por qué importa. Al jugar, tanto la IA como los paneles del jugador ESCRIBEN en la
## carta antes de resolverla: `BuildCard.chosen`, `RecruitCard.chosen`,
## `RecoverCard.chosen`, `OpenFrontCard.target_enemy_tile`/`battle_front_manager`.
## Si dos imperios compartieran la instancia, esas escrituras se pisarían entre sí
## —y en una partida en espejo (mismo template de mazo para ambos bandos, que es lo
## que hacen las simulaciones) sería el caso normal, no el raro.
##
## El código YA lo evita, y a propósito: cada punto de entrada a las pilas duplica.
## Lo que faltaba era una prueba que lo fijara, porque el invariante es fácil de
## romper sin darse cuenta — basta añadir un `discard_pile.add_card(carta_del_tres)`
## nuevo y no hay nada que avise. Estos tests son esa red.
##
## Puntos de entrada cubiertos aquí: arranque de partida, evento AddCard, evento
## AddRandomPoolCard, compra en tienda y efecto de edificio AddCardToDeck.
## (`GameStateSerializer` cubre el suyo con `template.duplicate(true)` al cargar.)


func _shared_card(id: String = "carta_compartida") -> GenerateGoldCard:
	# Hace de Resource del catálogo: el mismo objeto para todos los imperios.
	var c := GenerateGoldCard.new()
	c.id = id
	c.amount = 10
	return c


func _stats_with_piles() -> Stats:
	var s := Stats.new()
	s.deck = CardPile.new()
	s.draw_pile = CardPile.new()
	s.discard_pile = CardPile.new()
	s.played_pile = CardPile.new()
	return s


func _event_context(stats: Stats) -> EventContext:
	var ctx := EventContext.new()
	ctx.stats = stats
	return ctx


# ------------------------------------------------------------------
#  Arranque de partida
# ------------------------------------------------------------------

func test_two_empires_from_same_template_get_their_own_cards() -> void:
	# Espejo del flujo real: Stats.create_instance() + EmpireController.start_game,
	# que hace `draw_pile = deck.duplicate(true)`.
	var template := Stats.new()
	var pile := CardPile.new()
	pile.add_card(_shared_card())
	template.starting_deck = pile

	var a := template.create_instance() as Stats
	var b := template.create_instance() as Stats
	a.draw_pile = a.deck.duplicate(true)
	b.draw_pile = b.deck.duplicate(true)

	assert_ne(a.draw_pile.cards[0], b.draw_pile.cards[0],
		"cada imperio debe jugar con SU copia de la carta, no con una compartida")

	# Y la prueba de fuego: escribir en la de uno no toca la del otro.
	a.draw_pile.cards[0].id = "mutada_por_A"
	assert_eq(b.draw_pile.cards[0].id, "carta_compartida",
		"mutar la carta de un imperio no puede afectar a la del otro")


# ------------------------------------------------------------------
#  Puntos de entrada en runtime
# ------------------------------------------------------------------

func test_add_card_event_inserts_a_copy() -> void:
	var stats := _stats_with_piles()
	var shared := _shared_card()
	AddCardEffect.new(shared).execute(_event_context(stats))

	assert_eq(stats.discard_pile.cards.size(), 1, "el efecto debe añadir una carta")
	assert_ne(stats.discard_pile.cards[0], shared,
		"AddCardEffect debe insertar una COPIA, no el Resource del catálogo")


func test_shop_purchase_inserts_a_copy() -> void:
	var stats := _stats_with_piles()
	stats.total_gold = 100
	var shared := _shared_card()
	var item := ShopItem.new()
	item.card = shared
	item.price = 10
	item.purchase(stats)

	assert_eq(stats.discard_pile.cards.size(), 1, "la compra debe añadir una carta")
	assert_ne(stats.discard_pile.cards[0], shared,
		"ShopItem.purchase debe insertar una COPIA del artículo")


func test_random_pool_event_inserts_a_copy() -> void:
	var stats := _stats_with_piles()
	var shared := _shared_card()
	stats.unlocked_card_pool = [UnlockedCardEntry.new(shared, 10.0, 0.0, 1.0)]
	AddRandomPoolCardEffect.new().execute(_event_context(stats))

	assert_eq(stats.discard_pile.cards.size(), 1,
		"con una única entrada en el pool, el efecto debe añadirla")
	assert_ne(stats.discard_pile.cards[0], shared,
		"AddRandomPoolCardEffect debe insertar una COPIA de la carta del pool")


func test_building_effect_inserts_a_copy() -> void:
	var stats := _stats_with_piles()
	var shared := _shared_card()
	var effect := AddCardToDeckEffect.new()
	effect.card = shared
	var tile := add_child_autofree(Tile.new()) as Tile
	effect.apply_effect(tile, stats)

	assert_eq(stats.discard_pile.cards.size(), 1, "el edificio debe añadir su carta")
	assert_ne(stats.discard_pile.cards[0], shared,
		"AddCardToDeckEffect debe insertar una COPIA (su propio comentario lo exige)")


# ------------------------------------------------------------------
#  La consecuencia: mutar al jugar es seguro
# ------------------------------------------------------------------

func test_playing_mutates_only_the_owning_empires_copy() -> void:
	# `RecruitCard.chosen` es el caso que cita el comentario de AddCardToDeckEffect:
	# la IA lo escribe justo antes de resolver la carta.
	var shared := RecruitCard.new()
	shared.id = "recruit"

	var a := _stats_with_piles()
	var b := _stats_with_piles()
	AddCardEffect.new(shared).execute(_event_context(a))
	AddCardEffect.new(shared).execute(_event_context(b))

	var troop := Troop.new()
	troop.name = "Piquero"
	(a.discard_pile.cards[0] as RecruitCard).chosen = troop

	assert_null((b.discard_pile.cards[0] as RecruitCard).chosen,
		"la elección de un imperio no puede filtrarse a la carta del otro")
	assert_null(shared.chosen,
		"y tampoco al Resource compartido del catálogo")
