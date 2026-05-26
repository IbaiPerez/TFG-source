extends GutTest

## Tests para AIEventResolver. Cobertura Fase 4: resolución headless de
## TurnEvent (con/sin tile/card input, allow_skip, coste, unique) y
## ShopEvent (compra random subset asequible).


# ============================================================
#  Helpers
# ============================================================

func _make_stats(p_gold: int = 100, p_food: int = 10) -> Stats:
	var s := Stats.new()
	s.total_gold = p_gold
	s.gold_per_turn = 0
	s.food = p_food
	s.cards_per_turn = 3
	s.deck = CardPile.new()
	s.draw_pile = CardPile.new()
	s.discard_pile = CardPile.new()
	s.played_pile = CardPile.new()
	s.empire = Empire.new()
	s.empire.name = "TestAI"
	s.empire.controlled_tiles = []
	s.used_unique_events = []
	s.available_events = []
	s.possible_buildings = []
	s.unlocked_card_pool = []
	s.shop_exclusive_pool = []
	s.event_chance = 1.0
	s.turn_number = 5
	return s


func _make_context(stats: Stats) -> EventContext:
	var mgr := ModifierManager.new()
	add_child_autofree(mgr)
	return EventContext.build(stats, mgr, stats.turn_number)


func _make_manager(stats: Stats) -> TurnEventManager:
	var mgr := TurnEventManager.new()
	mgr.stats = stats
	add_child_autofree(mgr)
	return mgr


func _make_rng(seed_value: int = 12345) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _make_event(p_id: String = "evt", p_unique: bool = false,
		p_allow_skip: bool = false) -> TurnEvent:
	var evt := TurnEvent.new()
	evt.id = p_id
	evt.weight = 1.0
	evt.unique = p_unique
	evt.allow_skip = p_allow_skip
	evt.choices = []
	evt.conditions = []
	return evt


# ============================================================
#  TurnEvent: choice simple delegada al manager
# ============================================================

func test_simple_choice_resolved_via_manager_increases_gold() -> void:
	var stats := _make_stats(50)
	var event := _make_event("simple")
	var choice := TurnEventChoice.new()
	choice.effects = [GoldEventEffect.new(30)]
	event.choices = [choice]

	AIEventResolver.resolve(event, _make_context(stats), _make_rng(),
		_make_manager(stats))

	assert_eq(stats.total_gold, 80, "El effect debe haberse ejecutado")


# ============================================================
#  Filtrado de unaffordable
# ============================================================

func test_unaffordable_choice_is_filtered_out() -> void:
	var stats := _make_stats(5)  # muy poco oro
	var event := _make_event("expensive", false, false)

	var costly := TurnEventChoice.new()
	costly.cost = TurnEventCost.new()
	costly.cost.gold = 100
	costly.effects = [GoldEventEffect.new(50)]
	event.choices = [costly]

	# Sin choice asequible y sin allow_skip → no se resuelve nada.
	AIEventResolver.resolve(event, _make_context(stats), _make_rng(),
		_make_manager(stats))

	# El oro no aumenta y el coste no se paga.
	assert_eq(stats.total_gold, 5)


# ============================================================
#  Skip choice
# ============================================================

func test_skip_choice_added_when_allow_skip_and_no_affordable() -> void:
	# Único choice no asequible + allow_skip → la IA elige skip.
	var stats := _make_stats(0)
	var event := _make_event("skippable", true, true)

	var costly := TurnEventChoice.new()
	costly.cost = TurnEventCost.new()
	costly.cost.gold = 999
	costly.effects = [GoldEventEffect.new(50)]
	event.choices = [costly]

	AIEventResolver.resolve(event, _make_context(stats), _make_rng(),
		_make_manager(stats))

	# Como solo había skip como opción viable, fue lo elegido. Unique se marca.
	assert_eq(stats.total_gold, 0, "Skip no ejecuta efectos")
	assert_true("skippable" in stats.used_unique_events,
		"Evento único debe marcarse como usado tras skip")


# ============================================================
#  Unique tracking
# ============================================================

func test_unique_event_marked_after_resolve() -> void:
	var stats := _make_stats(0)
	var event := _make_event("unique_evt", true, false)
	var choice := TurnEventChoice.new()
	choice.effects = [GoldEventEffect.new(10)]
	event.choices = [choice]

	AIEventResolver.resolve(event, _make_context(stats), _make_rng(),
		_make_manager(stats))

	assert_true("unique_evt" in stats.used_unique_events,
		"Evento único debe quedar registrado tras resolverse")


func test_non_unique_event_not_marked() -> void:
	var stats := _make_stats(0)
	var event := _make_event("repeatable", false, false)
	var choice := TurnEventChoice.new()
	choice.effects = [GoldEventEffect.new(10)]
	event.choices = [choice]

	AIEventResolver.resolve(event, _make_context(stats), _make_rng(),
		_make_manager(stats))

	assert_false("repeatable" in stats.used_unique_events)


# ============================================================
#  Tile input choice
# ============================================================

func _make_town_tile_with_3_buildings(empire: Empire) -> Tile:
	var tile := Tile.new()
	tile.mesh_data = TileMeshData.new()
	tile.mesh_data.type = Tile.biome_type.Grassland
	tile.natural_resource = NaturalResource.new()
	tile.controller = empire
	var loc := LocationType.new()
	loc.type = Tile.location_type.Town
	tile.location = loc
	tile.buildings = [Building.new(), Building.new(), Building.new()]
	tile.neighbors = []
	return tile


func test_tile_input_choice_executes_with_eligible_tile() -> void:
	var stats := _make_stats(0)
	var tile := _make_town_tile_with_3_buildings(stats.empire)
	add_child_autofree(tile)
	stats.empire.controlled_tiles = [tile]

	var event := _make_event("urbanize", false, false)
	var choice := TurnEventChoice.new()
	choice.effects = [UrbanizeToMegalopolisEffect.new()]
	event.choices = [choice]

	# Vigilar la señal change_tile_location_type que UrbanizeToMegalopolisEffect emite.
	watch_signals(Events)
	AIEventResolver.resolve(event, _make_context(stats), _make_rng(),
		_make_manager(stats))

	assert_signal_emitted(Events, "change_tile_location_type",
		"El effect de tile debe disparar el cambio de location_type")


# ============================================================
#  Card input choice
# ============================================================

func test_card_input_choice_removes_random_candidate() -> void:
	var stats := _make_stats(0)
	# Sembrar discard con 2 cartas removibles
	var c1 := Card.new()
	c1.id = "removable"
	c1.type = Card.Type.BASIC
	var c2 := Card.new()
	c2.id = "removable"
	c2.type = Card.Type.BASIC
	stats.discard_pile.add_card(c1)
	stats.discard_pile.add_card(c2)

	var filter := CardRemovalFilter.new()
	filter.card_id = "removable"

	var effect := RemoveCardEventEffect.new(null, filter)
	var event := _make_event("remove_card", false, false)
	var choice := TurnEventChoice.new()
	choice.effects = [effect]
	event.choices = [choice]

	AIEventResolver.resolve(event, _make_context(stats), _make_rng(),
		_make_manager(stats))

	# Una de las dos debe haber sido eliminada del discard.
	assert_eq(stats.discard_pile.cards.size(), 1,
		"Una carta candidata debe haberse eliminado")


# ============================================================
#  ShopEvent (smoke + behavior)
# ============================================================

func _populate_minimal_pool(stats: Stats) -> void:
	# El generador de tienda necesita pools poblados para producir items.
	for i in range(3):
		var c := Card.new()
		c.id = "p%d" % i
		c.type = Card.Type.BASIC
		stats.unlocked_card_pool.append(UnlockedCardEntry.new(c, 5.0, 0.0, 1.0))


func test_shop_event_smoke_does_not_crash() -> void:
	var stats := _make_stats(200)
	_populate_minimal_pool(stats)

	var event := ShopEvent.new()
	event.id = "shop"
	event.shop_type = ShopEvent.ShopType.BASIC
	event.allow_skip = false
	event.choices = []

	# Smoke: no debe crashear y oro no debe quedar negativo.
	AIEventResolver.resolve(event, _make_context(stats), _make_rng(),
		_make_manager(stats))

	assert_true(stats.total_gold >= 0, "El oro no debe quedar negativo")


func test_shop_event_eventually_buys_at_least_one_item() -> void:
	# Con varios seeds y mucho oro, alguno comprará ≥ 1 carta.
	var bought := false
	for s in range(0, 20):
		var stats := _make_stats(10000)
		_populate_minimal_pool(stats)
		var initial_discard := stats.discard_pile.cards.size()

		var event := ShopEvent.new()
		event.id = "shop_buy"
		event.shop_type = ShopEvent.ShopType.BASIC
		event.choices = []

		AIEventResolver.resolve(event, _make_context(stats), _make_rng(s),
			_make_manager(stats))

		if stats.discard_pile.cards.size() > initial_discard:
			bought = true
			break

	assert_true(bought,
		"Algún seed debe llevar a la IA a comprar al menos 1 carta de la tienda")


func test_shop_event_marks_unique_when_applicable() -> void:
	var stats := _make_stats(200)
	_populate_minimal_pool(stats)

	var event := ShopEvent.new()
	event.id = "unique_shop"
	event.shop_type = ShopEvent.ShopType.BASIC
	event.unique = true
	event.choices = []

	AIEventResolver.resolve(event, _make_context(stats), _make_rng(),
		_make_manager(stats))

	assert_true("unique_shop" in stats.used_unique_events,
		"Shop único debe marcarse como usado tras resolverse")


# ============================================================
#  Determinismo con seed
# ============================================================

func test_seeded_rng_produces_same_outcome_twice() -> void:
	# Dos resoluciones del mismo evento con el mismo seed deben dar el
	# mismo total_gold final.
	var build_stats := func() -> Stats:
		var s := _make_stats(0)
		return s

	var build_event := func() -> TurnEvent:
		var ev := _make_event("det", false, true)
		# Dos choices viables + skip → 3 opciones
		var c1 := TurnEventChoice.new()
		c1.effects = [GoldEventEffect.new(10)]
		var c2 := TurnEventChoice.new()
		c2.effects = [GoldEventEffect.new(20)]
		ev.choices = [c1, c2]
		return ev

	var s_a := build_stats.call() as Stats
	var s_b := build_stats.call() as Stats
	AIEventResolver.resolve(build_event.call(), _make_context(s_a),
		_make_rng(99), _make_manager(s_a))
	AIEventResolver.resolve(build_event.call(), _make_context(s_b),
		_make_rng(99), _make_manager(s_b))

	assert_eq(s_a.total_gold, s_b.total_gold,
		"Mismo seed debe producir mismo resultado")
