extends GutTest

## Tests para AddCardToDeckEffect (scripts/building/effect/add_card_to_deck_effect.gd).
##
## Este BuildingEffect mete una carta en `stats.discard_pile` cuando se
## construye el edificio. Es el mecanismo que usa el Cuartel para añadir
## una RecruitCard al deck al construirse (escala la frecuencia de plays
## de Reclutar además de su throughput).


const RECRUIT_CARD := preload("res://resources/cards/recruit_card.tres")


var stats: Stats


func before_each() -> void:
	stats = Stats.new()
	stats.total_gold = 100
	stats.draw_pile = CardPile.new()
	stats.discard_pile = CardPile.new()
	stats.played_pile = CardPile.new()
	stats.possible_buildings = []


# ============================================================
#  apply_effect
# ============================================================

func test_apply_effect_adds_card_to_discard_pile() -> void:
	var effect := AddCardToDeckEffect.new()
	effect.card = RECRUIT_CARD

	effect.apply_effect(null, stats)
	assert_eq(stats.discard_pile.cards.size(), 1,
		"apply_effect debe meter una carta en discard_pile")


func test_apply_effect_duplicates_the_card() -> void:
	# Critico: el .tres es un recurso compartido. Si no duplicamos, la
	# carta del deck es la misma instancia que el resto del juego usa
	# y mutar `chosen` desde RecruitCard.apply_effects contaminaria a
	# todos. Verificamos que la carta en discard NO es el recurso
	# precargado.
	var effect := AddCardToDeckEffect.new()
	effect.card = RECRUIT_CARD

	effect.apply_effect(null, stats)
	var added: Card = stats.discard_pile.cards[0]
	assert_ne(added, RECRUIT_CARD,
		"La carta añadida debe ser un duplicate, no el recurso compartido")
	assert_eq(added.id, RECRUIT_CARD.id,
		"Pero el duplicate conserva el id (es la misma carta funcionalmente)")


func test_apply_effect_with_null_card_is_safe() -> void:
	var effect := AddCardToDeckEffect.new()
	effect.card = null
	effect.apply_effect(null, stats)
	assert_eq(stats.discard_pile.cards.size(), 0,
		"Si card es null no se mete nada (defensivo)")


func test_apply_effect_with_null_stats_is_safe() -> void:
	var effect := AddCardToDeckEffect.new()
	effect.card = RECRUIT_CARD
	# No debe crashear; simplemente no hace nada.
	effect.apply_effect(null, null)
	pass_test("apply_effect no crashea con stats null")


func test_apply_effect_multiple_times_adds_multiple_cards() -> void:
	# Construir 2 Cuarteles → meter 2 cartas. apply_effect debe ser idempotente
	# en el sentido de "cada llamada añade exactamente una".
	var effect := AddCardToDeckEffect.new()
	effect.card = RECRUIT_CARD

	effect.apply_effect(null, stats)
	effect.apply_effect(null, stats)
	assert_eq(stats.discard_pile.cards.size(), 2,
		"Cada apply_effect debe añadir una carta nueva")


# ============================================================
#  remove_effect / should_reapply_on_load
# ============================================================

func test_remove_effect_is_noop() -> void:
	# Demoler el Cuartel NO debe quitar la carta del deck — la carta ya
	# se "gastó" al construir. Si quieres revertir, hace falta otra
	# mecanica explicita.
	var effect := AddCardToDeckEffect.new()
	effect.card = RECRUIT_CARD

	effect.apply_effect(null, stats)
	assert_eq(stats.discard_pile.cards.size(), 1)
	effect.remove_effect(null, stats)
	assert_eq(stats.discard_pile.cards.size(), 1,
		"remove_effect es no-op: la carta sigue en el deck")


func test_should_reapply_on_load_returns_false() -> void:
	# La carta ya viene en el snapshot del deck. Re-aplicar al cargar el
	# save la duplicaria.
	var effect := AddCardToDeckEffect.new()
	assert_false(effect.should_reapply_on_load(),
		"AddCardToDeckEffect NO debe re-aplicarse al cargar save")


# ============================================================
#  first_only — solo dispara en el primer edificio del mismo nombre
# ============================================================

func _make_tile_with_buildings(buildings_names: Array[String]) -> Tile:
	# Util para los tests de first_only: crea una Tile con una lista de
	# Buildings (instancias planas) cuyos `name` son los pasados. No
	# necesitamos mas — `_empire_already_has_another` solo mira el name.
	var tile := Tile.new()
	for n in buildings_names:
		var b := Building.new()
		b.name = n
		tile.buildings.append(b)
	autofree(tile)
	return tile


func test_first_only_triggers_when_no_other_instance() -> void:
	var effect := AddCardToDeckEffect.new()
	effect.card = RECRUIT_CARD
	effect.first_only = true

	# Tile que acaba de tener el Cuartel construido — solo hay 1 instancia
	# de "Cuartel" en el imperio (la tile esta en controlled_tiles).
	var tile := _make_tile_with_buildings(["Cuartel"])
	var empire := Empire.new()
	empire.controlled_tiles = [tile]
	stats.empire = empire

	effect.apply_effect(tile, stats)
	assert_eq(stats.discard_pile.cards.size(), 1,
		"first_only=true con 1 instancia debe añadir la carta")


func test_first_only_skips_when_another_instance_exists() -> void:
	var effect := AddCardToDeckEffect.new()
	effect.card = RECRUIT_CARD
	effect.first_only = true

	# Dos tiles, ambas con "Cuartel". La segunda es la que acaba de
	# construirse (last appended). El effect debe ver que ya hay otra
	# instancia y saltarse el add_card.
	var tile_other := _make_tile_with_buildings(["Cuartel"])
	var tile_new := _make_tile_with_buildings(["Cuartel"])
	var empire := Empire.new()
	empire.controlled_tiles = [tile_other, tile_new]
	stats.empire = empire

	effect.apply_effect(tile_new, stats)
	assert_eq(stats.discard_pile.cards.size(), 0,
		"first_only=true con otra instancia previa NO debe añadir carta")


func test_first_only_false_always_triggers() -> void:
	# Comportamiento default: si first_only es false, siempre añade la
	# carta sin importar cuantas instancias existan. Garantia de
	# backwards compat para edificios que quieran spam (futuros casos).
	var effect := AddCardToDeckEffect.new()
	effect.card = RECRUIT_CARD
	effect.first_only = false

	var tile_other := _make_tile_with_buildings(["Cuartel"])
	var tile_new := _make_tile_with_buildings(["Cuartel"])
	var empire := Empire.new()
	empire.controlled_tiles = [tile_other, tile_new]
	stats.empire = empire

	effect.apply_effect(tile_new, stats)
	assert_eq(stats.discard_pile.cards.size(), 1,
		"first_only=false (default) añade siempre, aunque haya otras instancias")


func test_first_only_with_different_named_buildings_still_triggers() -> void:
	# Otra Tile tiene un edificio DISTINTO (Library) → no debe contar como
	# "ya existente" para Cuartel. El name discrimina.
	var effect := AddCardToDeckEffect.new()
	effect.card = RECRUIT_CARD
	effect.first_only = true

	var tile_other := _make_tile_with_buildings(["Library"])
	var tile_new := _make_tile_with_buildings(["Cuartel"])
	var empire := Empire.new()
	empire.controlled_tiles = [tile_other, tile_new]
	stats.empire = empire

	effect.apply_effect(tile_new, stats)
	assert_eq(stats.discard_pile.cards.size(), 1,
		"Una Library distinta no impide que el primer Cuartel dispare")
