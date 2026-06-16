extends GutTest

## Test de regresion para UnlockRecruitEvent.
##
## Bug original: el evento construia la RecruitCard con `RecruitCard.new()`
## y configuraba id/type/target/needs_confirmation, pero NO le pasaba
## `available_troops`. La carta entraba al deck y al pool con la lista de
## tropas vacia, asi que `AIOptionsBuilder._add_recruit_options` devolvia
## sin opciones y la IA nunca reclutaba aunque tuviera la carta en la mano.
##
## El fix usa el `.tres` (que ya trae las 5 tropas configuradas) en lugar
## de construir la carta a mano. Estos tests aseguran que cualquier
## refactor futuro mantenga la carta jugable.


func test_recruit_card_in_add_card_effect_has_available_troops() -> void:
	# AddCardEffect mete la carta en el discard_pile; comprobamos que la
	# carta tal y como sale del evento ya trae available_troops poblado.
	var event := UnlockRecruitEvent.new()
	assert_eq(event.choices.size(), 1, "El evento debe tener 1 choice")

	var add_card_effect: AddCardEffect = null
	for effect in event.choices[0].effects:
		if effect is AddCardEffect:
			add_card_effect = effect
			break
	assert_not_null(add_card_effect, "Debe haber un AddCardEffect en la choice")

	var card: Card = add_card_effect.card
	assert_true(card is RecruitCard,
		"AddCardEffect debe llevar una RecruitCard")
	var recruit := card as RecruitCard
	assert_false(recruit.available_troops.is_empty(),
		"available_troops NO debe estar vacio (regresion del bug original)")


func test_recruit_card_in_pool_effect_has_available_troops() -> void:
	# AddToCardPoolEffect registra la carta en unlocked_card_pool. Tiene que
	# ser la MISMA carta jugable que AddCardEffect (mismas tropas).
	var event := UnlockRecruitEvent.new()
	var pool_effect: AddToCardPoolEffect = null
	for effect in event.choices[0].effects:
		if effect is AddToCardPoolEffect:
			pool_effect = effect
			break
	assert_not_null(pool_effect, "Debe haber un AddToCardPoolEffect en la choice")

	var entry: UnlockedCardEntry = pool_effect.entry
	assert_not_null(entry, "El effect debe llevar un UnlockedCardEntry")
	assert_true(entry.card is RecruitCard,
		"La entry debe envolver una RecruitCard")
	var recruit := entry.card as RecruitCard
	assert_false(recruit.available_troops.is_empty(),
		"available_troops en el pool tampoco debe estar vacio")


func test_unlock_recruit_event_also_unlocks_cuartel_building() -> void:
	# Regresion: al desbloquear Recruit tambien se debe añadir el Cuartel a
	# possible_buildings (via UnlockBuildingEffect). Sin esto el jugador
	# tiene la carta pero no puede construir lo que multiplica su efecto.
	var event := UnlockRecruitEvent.new()
	var unlock_building_effect: UnlockBuildingEffect = null
	for effect in event.choices[0].effects:
		if effect is UnlockBuildingEffect:
			unlock_building_effect = effect
			break
	assert_not_null(unlock_building_effect,
		"Debe haber un UnlockBuildingEffect en la choice del evento")
	assert_eq(unlock_building_effect.building.name, "BLD_CUARTEL_NAME",
		"El edificio desbloqueado debe ser el Cuartel")


func test_recruit_card_generates_options_when_played() -> void:
	# Integracion ligera: con la carta producida por el evento y un stats
	# con oro suficiente, AIOptionsBuilder debe generar al menos una opcion
	# (1 por tropa asequible).
	var event := UnlockRecruitEvent.new()
	var add_card_effect: AddCardEffect = null
	for effect in event.choices[0].effects:
		if effect is AddCardEffect:
			add_card_effect = effect
			break
	var recruit := add_card_effect.card as RecruitCard

	# Stats minimo con oro y produccion de sobra para cualquier tropa. El
	# nuevo `can_afford_troop` (Opcion 3b) bloquea recruit si gpt o food
	# no cubren el mantenimiento; sin gpt/food explicitamente positivos
	# el filtro descartaria todas las tropas.
	var stats := Stats.new()
	stats.total_gold = 9999
	stats.gold_per_turn = 100
	stats.food = 100
	stats.draw_pile = CardPile.new()
	stats.discard_pile = CardPile.new()
	stats.played_pile = CardPile.new()
	var empire := Empire.new()
	empire.name = "TestIA"
	empire.controlled_tiles = []
	stats.empire = empire

	var ctx := AITurnContext.new()
	ctx.stats = stats
	ctx.rng = RandomNumberGenerator.new()
	ctx.drawn_cards = []

	var options := AIOptionsBuilder.build_options(recruit, ctx)
	assert_gt(options.size(), 0,
		"Con oro suficiente y la carta del evento, debe haber al menos 1 opcion de reclutar")
	for opt in options:
		assert_true(opt is AIRecruitOption,
			"Cada opcion debe ser un AIRecruitOption")
