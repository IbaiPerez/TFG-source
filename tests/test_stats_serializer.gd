extends GutTest
## Tests de StatsSerializer: round-trip de Stats sin escena.


var initial_stats:Stats


func before_each() -> void:
	# Usamos las stats iniciales reales del proyecto como plantilla.
	# Esto garantiza que template_path resuelva correctamente al cargar.
	initial_stats = load("res://resources/stats/initial_stats.tres") as Stats
	assert_not_null(initial_stats, "initial_stats.tres no se pudo cargar")


func _make_filled_stats() -> Stats:
	var stats:Stats = initial_stats.create_instance()
	stats.total_gold = 42
	stats.gold_per_turn = 7
	stats.food = 9
	stats.turn_number = 12
	stats.total_purges_done = 2
	stats.used_unique_events = ["evt_a", "evt_b"]
	# Mete tres cartas distintas en draw_pile para verificar orden literal.
	var col_card:Card = load("res://resources/cards/colonize_card.tres") as Card
	var draw_card:Card = load("res://resources/cards/card_draw_card.tres") as Card
	var rec_card:Card = load("res://resources/cards/recover_card.tres") as Card
	stats.draw_pile.add_card(col_card.duplicate())
	stats.draw_pile.add_card(draw_card.duplicate())
	stats.draw_pile.add_card(rec_card.duplicate())
	# Una en discard_pile y otra en played_pile.
	stats.discard_pile.add_card(col_card.duplicate())
	stats.played_pile.add_card(rec_card.duplicate())
	return stats


# --- Snapshots básicos -------------------------------------------------

func test_to_dict_captures_resources():
	var stats := _make_filled_stats()
	var d := StatsSerializer.to_dict(stats)
	assert_eq(d["total_gold"], 42)
	assert_eq(d["gold_per_turn"], 7)
	assert_eq(d["food"], 9)


func test_to_dict_captures_progress():
	var stats := _make_filled_stats()
	var d := StatsSerializer.to_dict(stats)
	assert_eq(d["turn_number"], 12)
	assert_eq(d["total_purges_done"], 2)
	assert_eq(d["used_unique_events"], ["evt_a", "evt_b"])


func test_to_dict_records_draw_pile_order():
	var stats := _make_filled_stats()
	var d := StatsSerializer.to_dict(stats)
	var keys:Array = d["draw_pile"]
	assert_eq(keys.size(), 3)
	# Las cartas son duplicates → su path queda vacío y SaveResourceRegistry
	# devuelve `card.id` como clave estable. Lo importante es el orden.
	assert_eq(keys[0], "Colonize")
	assert_eq(keys[1], "CardDraw")
	assert_eq(keys[2], "Recover")


# --- Round-trip --------------------------------------------------------

func test_round_trip_preserves_resources():
	var stats := _make_filled_stats()
	var d := StatsSerializer.to_dict(stats)
	var restored := StatsSerializer.from_dict(d, stats.empire)
	assert_not_null(restored)
	assert_eq(restored.total_gold, 42)
	assert_eq(restored.gold_per_turn, 7)
	assert_eq(restored.food, 9)


func test_round_trip_preserves_progress():
	var stats := _make_filled_stats()
	var d := StatsSerializer.to_dict(stats)
	var restored := StatsSerializer.from_dict(d, stats.empire)
	assert_eq(restored.turn_number, 12)
	assert_eq(restored.total_purges_done, 2)
	assert_eq(restored.used_unique_events, ["evt_a", "evt_b"])


func test_round_trip_preserves_pile_order():
	var stats := _make_filled_stats()
	var d := StatsSerializer.to_dict(stats)
	var restored := StatsSerializer.from_dict(d, stats.empire)
	assert_eq(restored.draw_pile.cards.size(), 3)
	# El orden literal del draw_pile importa: la siguiente carta robada
	# debe ser la misma que en el snapshot. Verificamos por `card.id` —
	# las cartas en pilas son duplicates, su `resource_path` queda vacío
	# y el discriminador estable es `id`.
	assert_eq(restored.draw_pile.cards[0].id, "Colonize")
	assert_eq(restored.draw_pile.cards[1].id, "CardDraw")
	assert_eq(restored.draw_pile.cards[2].id, "Recover")


func test_round_trip_preserves_unlocked_pools():
	var stats := _make_filled_stats()
	var d := StatsSerializer.to_dict(stats)
	var restored := StatsSerializer.from_dict(d, stats.empire)
	# initial_stats define unlocked_card_pool con colonize y shop_exclusive_pool
	# con card_draw + recover. Verificamos que persisten.
	assert_eq(restored.unlocked_card_pool.size(), stats.unlocked_card_pool.size())
	assert_eq(restored.shop_exclusive_pool.size(), stats.shop_exclusive_pool.size())


func test_round_trip_with_empty_pools_works():
	var stats:Stats = initial_stats.create_instance()
	var d := StatsSerializer.to_dict(stats)
	var restored := StatsSerializer.from_dict(d, stats.empire)
	assert_not_null(restored)
	assert_eq(restored.draw_pile.cards.size(), 0)
	assert_eq(restored.discard_pile.cards.size(), 0)
	assert_eq(restored.played_pile.cards.size(), 0)


func test_from_dict_returns_null_on_empty_dict():
	var restored := StatsSerializer.from_dict({}, null)
	assert_null(restored)


# --- types_ever_recruited (contador historico) -------------------------

func test_round_trip_preserves_types_ever_recruited():
	var stats := _make_filled_stats()
	# Tres tipos con conteos distintos. JSON solo soporta claves String, asi
	# que el serializer convierte int → str ida y vuelta; este test bloquea
	# regresiones en esa conversion.
	stats.types_ever_recruited = {
		Troop.TroopType.CABALLERIA: 2,
		Troop.TroopType.PIQUEROS: 1,
		Troop.TroopType.A_DISTANCIA: 5,
	}
	var d := StatsSerializer.to_dict(stats)
	var restored := StatsSerializer.from_dict(d, stats.empire)
	assert_eq(int(restored.types_ever_recruited.get(Troop.TroopType.CABALLERIA, 0)), 2)
	assert_eq(int(restored.types_ever_recruited.get(Troop.TroopType.PIQUEROS, 0)), 1)
	assert_eq(int(restored.types_ever_recruited.get(Troop.TroopType.A_DISTANCIA, 0)), 5)


func test_round_trip_types_ever_recruited_empty():
	var stats:Stats = initial_stats.create_instance()
	# create_instance() inicializa a {}; verificamos que sobrevive el round-trip.
	var d := StatsSerializer.to_dict(stats)
	var restored := StatsSerializer.from_dict(d, stats.empire)
	assert_eq(restored.types_ever_recruited.size(), 0)


func test_from_dict_defaults_types_ever_recruited_when_missing():
	# Saves antiguos no tienen el campo: el serializer debe asumir {} para
	# que la carga no falle. El jugador pierde el historial pero la partida
	# sigue jugable.
	var stats := _make_filled_stats()
	var d := StatsSerializer.to_dict(stats)
	d.erase("types_ever_recruited")
	var restored := StatsSerializer.from_dict(d, stats.empire)
	assert_eq(restored.types_ever_recruited.size(), 0,
		"Save antiguo sin campo → restored.types_ever_recruited == {}")
