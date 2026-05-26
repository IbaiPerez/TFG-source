extends GutTest

## Tests para los eventos de desbloqueo militar y sus condiciones.


func before_each() -> void:
	# Estos tests crean BattleFront directamente; mantenerlos aislados
	# del registro global para que no contaminen otras suites.
	BattleFront.clear_active_instances()


func after_each() -> void:
	BattleFront.clear_active_instances()


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
	s.event_chance = 1.0
	s.troop_pool = []
	return s


func _make_tile(empire: Empire = null, loc_type: int = Tile.location_type.Village) -> Tile:
	var tile := Tile.new()
	tile.mesh_data = TileMeshData.new()
	tile.mesh_data.type = Tile.biome_type.Grassland
	tile.natural_resource = NaturalResource.new()
	tile.buildings = []
	tile.location = LocationType.new()
	tile.location.type = loc_type
	tile.controller = empire
	tile.neighbors = []
	autofree(tile)
	return tile


func _make_troop(troop_name: String = "Milicia", atk: int = 3, def: int = 3,
		troop_type: int = Troop.TroopType.INFANTERIA_LIGERA) -> Troop:
	var troop := Troop.new()
	troop.name = troop_name
	troop.type = troop_type
	troop.attack = atk
	troop.defense = def
	troop.recruitment_cost_gold = 10
	troop.maintenance_gold = 2
	troop.maintenance_food = 1
	return troop


func _make_context(stats: Stats, turn: int = 5, bfm: BattleFrontManager = null) -> EventContext:
	var mgr := ModifierManager.new()
	add_child_autoqfree(mgr)
	return EventContext.build(stats, mgr, turn, bfm)


# ============================================================
#  HasAdjacentEnemyCondition
# ============================================================

func test_has_adjacent_enemy_true_when_neighbor_is_enemy() -> void:
	var own_empire := Empire.new()
	var enemy_empire := Empire.new()
	var stats := _make_stats()
	stats.empire = own_empire

	var own_tile := _make_tile(own_empire, Tile.location_type.Village)
	var enemy_tile := _make_tile(enemy_empire, Tile.location_type.Village)
	own_tile.neighbors = [enemy_tile]
	own_empire.controlled_tiles = [own_tile]
	stats.empire = own_empire

	var ctx := _make_context(stats)
	var condition := HasAdjacentEnemyCondition.new()
	assert_true(condition.is_met(ctx), "Debe detectar un vecino enemigo")


func test_has_adjacent_enemy_false_when_no_enemy_neighbor() -> void:
	var own_empire := Empire.new()
	var stats := _make_stats()
	stats.empire = own_empire

	var own_tile := _make_tile(own_empire, Tile.location_type.Village)
	var neutral_tile := _make_tile(null, Tile.location_type.Uncolonized)
	own_tile.neighbors = [neutral_tile]
	own_empire.controlled_tiles = [own_tile]

	var ctx := _make_context(stats)
	var condition := HasAdjacentEnemyCondition.new()
	assert_false(condition.is_met(ctx), "No debe dispararse sin vecino enemigo")


func test_has_adjacent_enemy_false_when_neighbor_is_own() -> void:
	var own_empire := Empire.new()
	var stats := _make_stats()
	stats.empire = own_empire

	var tile_a := _make_tile(own_empire)
	var tile_b := _make_tile(own_empire)
	tile_a.neighbors = [tile_b]
	own_empire.controlled_tiles = [tile_a, tile_b]

	var ctx := _make_context(stats)
	var condition := HasAdjacentEnemyCondition.new()
	assert_false(condition.is_met(ctx), "Vecino propio no es enemigo")


# ============================================================
#  HasTroopsCondition
# ============================================================

func test_has_troops_true_with_troops() -> void:
	var stats := _make_stats()
	stats.troop_pool = [_make_troop()]

	var ctx := _make_context(stats)
	var condition := HasTroopsCondition.new(1)
	assert_true(condition.is_met(ctx), "Debe detectar tropas reclutadas")


func test_has_troops_false_without_troops() -> void:
	var stats := _make_stats()
	stats.troop_pool = []

	var ctx := _make_context(stats)
	var condition := HasTroopsCondition.new(1)
	assert_false(condition.is_met(ctx), "Sin tropas no debe cumplirse")


func test_has_troops_min_count() -> void:
	var stats := _make_stats()
	stats.troop_pool = [_make_troop()]

	var ctx := _make_context(stats)
	var condition := HasTroopsCondition.new(2)
	assert_false(condition.is_met(ctx), "Con 1 tropa no se cumple min=2")

	stats.troop_pool.append(_make_troop("Caballería"))
	var ctx2 := _make_context(stats)
	assert_true(condition.is_met(ctx2), "Con 2 tropas se cumple min=2")


# ============================================================
#  HasActiveFrontsCondition
# ============================================================

func test_has_active_fronts_true() -> void:
	var stats := _make_stats()
	var bfm := BattleFrontManager.new()
	bfm.stats = stats

	# Crear un frente activo manualmente
	var atk_tile := _make_tile(stats.empire)
	var def_tile := _make_tile(Empire.new())
	atk_tile.neighbors = [def_tile]
	def_tile.neighbors = [atk_tile]
	stats.empire.controlled_tiles = [atk_tile]
	add_child_autoqfree(bfm)

	var front := BattleFront.new(atk_tile, def_tile, stats.empire, def_tile.controller)
	bfm.active_fronts.append(front)

	var ctx := _make_context(stats, 5, bfm)
	var condition := HasActiveFrontsCondition.new(1)
	assert_true(condition.is_met(ctx), "Debe detectar frentes activos")


func test_has_active_fronts_false() -> void:
	var stats := _make_stats()
	var bfm := BattleFrontManager.new()
	bfm.stats = stats
	add_child_autoqfree(bfm)

	var ctx := _make_context(stats, 5, bfm)
	var condition := HasActiveFrontsCondition.new(1)
	assert_false(condition.is_met(ctx), "Sin frentes activos no debe cumplirse")


# ============================================================
#  EventContext datos militares
# ============================================================

func test_context_includes_troop_pool_size() -> void:
	var stats := _make_stats()
	stats.troop_pool = [_make_troop(), _make_troop()]
	stats.empire.controlled_tiles = []

	var ctx := _make_context(stats)
	assert_eq(ctx.troop_pool_size, 2, "Contexto debe reflejar tamaño del pool de tropas")


func test_context_includes_active_front_count() -> void:
	var stats := _make_stats()
	var bfm := BattleFrontManager.new()
	bfm.stats = stats
	add_child_autoqfree(bfm)
	stats.empire.controlled_tiles = []

	var front := BattleFront.new(_make_tile(), _make_tile(), Empire.new(), Empire.new())
	bfm.active_fronts.append(front)

	var ctx := _make_context(stats, 5, bfm)
	assert_eq(ctx.active_front_count, 1, "Contexto debe reflejar frentes activos")


func test_context_has_adjacent_enemy_flag() -> void:
	var own_empire := Empire.new()
	var enemy_empire := Empire.new()
	var stats := _make_stats()
	stats.empire = own_empire

	var own_tile := _make_tile(own_empire)
	var enemy_tile := _make_tile(enemy_empire)
	own_tile.neighbors = [enemy_tile]
	own_empire.controlled_tiles = [own_tile]

	var ctx := _make_context(stats)
	assert_true(ctx.has_adjacent_enemy, "Contexto debe detectar vecino enemigo")


# ============================================================
#  Eventos de desbloqueo - condiciones
# ============================================================

func test_unlock_recruit_event_conditions_not_met_without_town() -> void:
	var own_empire := Empire.new()
	var enemy_empire := Empire.new()
	var stats := _make_stats()
	stats.empire = own_empire

	# Village adyacente a enemigo, pero no Town
	var own_tile := _make_tile(own_empire, Tile.location_type.Village)
	var enemy_tile := _make_tile(enemy_empire)
	own_tile.neighbors = [enemy_tile]
	own_empire.controlled_tiles = [own_tile]

	var ctx := _make_context(stats)
	var event := UnlockRecruitEvent.new()
	assert_false(event.is_available(ctx), "Sin ciudad no debe activarse")


func test_unlock_recruit_event_conditions_met() -> void:
	var own_empire := Empire.new()
	var enemy_empire := Empire.new()
	var stats := _make_stats()
	stats.empire = own_empire

	# Town adyacente a enemigo
	var own_tile := _make_tile(own_empire, Tile.location_type.Town)
	var enemy_tile := _make_tile(enemy_empire)
	own_tile.neighbors = [enemy_tile]
	own_empire.controlled_tiles = [own_tile]

	var ctx := _make_context(stats)
	var event := UnlockRecruitEvent.new()
	assert_true(event.is_available(ctx), "Con ciudad y vecino enemigo debe activarse")


func test_unlock_open_front_requires_recruit_and_troops() -> void:
	var stats := _make_stats()
	stats.empire.controlled_tiles = []
	stats.troop_pool = []

	var ctx := _make_context(stats)
	var event := UnlockOpenFrontEvent.new()
	assert_false(event.is_available(ctx), "Sin evento previo ni tropas no debe activarse")

	# Solo evento previo, sin tropas
	stats.used_unique_events = ["unlock_recruit"]
	var ctx2 := _make_context(stats)
	assert_false(event.is_available(ctx2), "Con evento previo pero sin tropas no debe activarse")

	# Evento previo + tropas
	stats.troop_pool = [_make_troop()]
	var ctx3 := _make_context(stats)
	assert_true(event.is_available(ctx3), "Con evento previo y tropas debe activarse")


# ============================================================
#  Ejecución de efectos
# ============================================================

func test_unlock_recruit_choice_adds_card_to_discard() -> void:
	var stats := _make_stats()
	stats.empire.controlled_tiles = []
	stats.possible_buildings = []
	var ctx := _make_context(stats)

	var event := UnlockRecruitEvent.new()
	var choice := event.choices[0]
	choice.execute(ctx)

	assert_eq(stats.discard_pile.cards.size(), 1, "Debe añadir carta de Reclutar al descarte")
	assert_true(stats.discard_pile.cards[0] is RecruitCard, "La carta debe ser RecruitCard")


func test_unlock_open_front_choice_adds_card_to_discard() -> void:
	var stats := _make_stats()
	stats.empire.controlled_tiles = []
	stats.possible_buildings = []
	var ctx := _make_context(stats)

	var event := UnlockOpenFrontEvent.new()
	var choice := event.choices[0]
	choice.execute(ctx)

	assert_eq(stats.discard_pile.cards.size(), 1, "Debe añadir carta de Abrir Frente al descarte")
	assert_true(stats.discard_pile.cards[0] is OpenFrontCard, "La carta debe ser OpenFrontCard")


func test_unlock_recruit_not_skippable() -> void:
	var event := UnlockRecruitEvent.new()
	assert_false(event.allow_skip, "Evento de reclutar no debe poder saltarse")


func test_all_military_events_are_unique() -> void:
	assert_true(UnlockRecruitEvent.new().unique)
	assert_true(UnlockOpenFrontEvent.new().unique)


# ============================================================
#  Las cartas se cargan desde los .tres (icono y stats incluidos)
# ============================================================

func test_unlock_open_front_card_loaded_from_resource() -> void:
	var stats := _make_stats()
	stats.empire.controlled_tiles = []
	stats.possible_buildings = []
	var ctx := _make_context(stats)

	var event := UnlockOpenFrontEvent.new()
	event.choices[0].execute(ctx)

	var card := stats.discard_pile.cards[0] as OpenFrontCard
	var resource := UnlockOpenFrontEvent.OPEN_FRONT_CARD
	assert_eq(card.id, resource.id, "id debe coincidir con el del .tres")
	assert_eq(card.type, resource.type, "type debe coincidir con el del .tres")
	assert_eq(card.target, resource.target, "target debe coincidir con el del .tres")
	assert_eq(card.needs_confirmation, resource.needs_confirmation,
			"needs_confirmation debe coincidir con el del .tres")
	assert_not_null(card.icon, "La carta debe llevar el icono definido en el .tres")
	assert_eq(card.icon, resource.icon, "El icono debe ser el del .tres")


func test_unlock_open_front_pool_entry_uses_resource() -> void:
	var stats := _make_stats()
	stats.empire.controlled_tiles = []
	stats.possible_buildings = []
	var ctx := _make_context(stats)

	var event := UnlockOpenFrontEvent.new()
	event.choices[0].execute(ctx)

	assert_eq(stats.unlocked_card_pool.size(), 1, "Debe añadir 1 entrada al pool")
	var entry := stats.unlocked_card_pool[0]
	assert_eq(entry.card, UnlockOpenFrontEvent.OPEN_FRONT_CARD,
			"La entrada del pool debe referenciar el recurso .tres")


func test_unlock_open_front_card_added_is_a_copy() -> void:
	# AddCardEffect debe duplicar el recurso para no mutar el .tres compartido.
	var stats := _make_stats()
	stats.empire.controlled_tiles = []
	stats.possible_buildings = []
	var ctx := _make_context(stats)

	var event := UnlockOpenFrontEvent.new()
	event.choices[0].execute(ctx)

	var card := stats.discard_pile.cards[0] as OpenFrontCard
	assert_ne(card, UnlockOpenFrontEvent.OPEN_FRONT_CARD,
			"La carta del descarte debe ser una copia, no el recurso compartido")


# ============================================================
#  HasRecruitedTroopOfTypeCondition
#
#  La condicion lee `stats.types_ever_recruited` (contador historico
#  incrementado en `Stats.recruit_troop`), no `stats.troop_pool`. Esto
#  desacopla "tengo este tipo AHORA" de "he reclutado este tipo alguna
#  vez", que es lo que las doctrinas tacticas necesitan.
# ============================================================

func test_has_recruited_troop_of_type_true_when_counter_has_type() -> void:
	var stats := _make_stats()
	stats.types_ever_recruited = { Troop.TroopType.CABALLERIA: 1 }

	var ctx := _make_context(stats)
	var cond := HasRecruitedTroopOfTypeCondition.new(Troop.TroopType.CABALLERIA, 1)
	assert_true(cond.is_met(ctx), "Debe cumplirse con 1 caballería en el contador")


func test_has_recruited_troop_of_type_false_when_no_match() -> void:
	var stats := _make_stats()
	stats.types_ever_recruited = { Troop.TroopType.INFANTERIA_LIGERA: 3 }

	var ctx := _make_context(stats)
	var cond := HasRecruitedTroopOfTypeCondition.new(Troop.TroopType.CABALLERIA, 1)
	assert_false(cond.is_met(ctx), "No debe cumplirse si nunca se reclutó ese tipo")


func test_has_recruited_troop_of_type_false_with_empty_counter() -> void:
	var stats := _make_stats()
	stats.types_ever_recruited = {}

	var ctx := _make_context(stats)
	var cond := HasRecruitedTroopOfTypeCondition.new(Troop.TroopType.PIQUEROS, 1)
	assert_false(cond.is_met(ctx), "Contador vacío nunca cumple")


func test_has_recruited_troop_of_type_respects_min_count() -> void:
	var stats := _make_stats()
	stats.types_ever_recruited = { Troop.TroopType.CABALLERIA: 1 }

	var ctx := _make_context(stats)
	var cond := HasRecruitedTroopOfTypeCondition.new(Troop.TroopType.CABALLERIA, 2)
	assert_false(cond.is_met(ctx), "Sólo se reclutó 1 cab, requisito 2 → falla")

	stats.types_ever_recruited[Troop.TroopType.CABALLERIA] = 2
	var ctx2 := _make_context(stats)
	assert_true(cond.is_met(ctx2), "Ya se reclutaron 2 cabs → cumple")


func test_has_recruited_troop_of_type_invalid_type_returns_false() -> void:
	var stats := _make_stats()
	stats.types_ever_recruited = { Troop.TroopType.INFANTERIA_LIGERA: 1 }

	var ctx := _make_context(stats)
	var cond := HasRecruitedTroopOfTypeCondition.new(-1, 1)
	assert_false(cond.is_met(ctx), "Tipo inválido (-1) nunca cumple")


func test_has_recruited_troop_of_type_independent_from_pool() -> void:
	# Regresion del bug original: la tropa se reclutó pero el AIController la
	# asignó inmediatamente a un frente, dejando el pool vacío. La condicion
	# debe seguir cumpliéndose porque lee el contador historico, no el pool.
	var stats := _make_stats()
	stats.troop_pool = []  # Pool vacío (todo asignado a frentes).
	stats.types_ever_recruited = { Troop.TroopType.CABALLERIA: 1 }

	var ctx := _make_context(stats)
	var cond := HasRecruitedTroopOfTypeCondition.new(Troop.TroopType.CABALLERIA, 1)
	assert_true(cond.is_met(ctx),
		"La condicion debe cumplirse aunque la tropa ya no esté en el pool")


# ============================================================
#  Eventos de desbloqueo de tácticas (uno por carta)
# ============================================================

func _make_full_ctx_with_troop(troop_type: int) -> EventContext:
	var stats := _make_stats()
	stats.empire.controlled_tiles = []
	stats.possible_buildings = []
	stats.used_unique_events = ["unlock_open_front"]
	# La condicion HasRecruitedTroopOfTypeCondition lee el contador historico,
	# asi que populamos `types_ever_recruited`. Mantenemos tambien el pool
	# poblado para reflejar el estado normal del juego (la tropa acaba de
	# reclutarse y aun no esta asignada a un frente).
	stats.types_ever_recruited = { troop_type: 1 }
	stats.troop_pool = [_make_troop("X", 3, 3, troop_type)]
	return _make_context(stats)


func test_unlock_cavalry_charge_requires_open_front_and_cavalry() -> void:
	var stats := _make_stats()
	stats.empire.controlled_tiles = []
	var ctx_no_prereqs := _make_context(stats)

	var event := UnlockCavalryChargeEvent.new()
	assert_false(event.is_available(ctx_no_prereqs),
		"Sin evento previo ni tropas no debe activarse")

	# Sólo evento previo, sin caballería
	stats.used_unique_events = ["unlock_open_front"]
	var ctx_no_troop := _make_context(stats)
	assert_false(event.is_available(ctx_no_troop),
		"Con evento previo pero sin caballería no debe activarse")

	# Ahora con caballería reclutada (en el contador historico)
	stats.types_ever_recruited = { Troop.TroopType.CABALLERIA: 1 }
	var ctx_ok := _make_context(stats)
	assert_true(event.is_available(ctx_ok),
		"Con evento previo + caballería debe activarse")


func test_unlock_cavalry_charge_does_not_trigger_with_other_troop_type() -> void:
	var stats := _make_stats()
	stats.empire.controlled_tiles = []
	stats.used_unique_events = ["unlock_open_front"]
	# Sólo piqueros reclutados, no caballería.
	stats.types_ever_recruited = { Troop.TroopType.PIQUEROS: 1 }

	var ctx := _make_context(stats)
	var event := UnlockCavalryChargeEvent.new()
	assert_false(event.is_available(ctx),
		"Tener piqueros NO debe desbloquear la doctrina de carga de caballería")


func test_unlock_cavalry_charge_choice_adds_card_and_pool() -> void:
	var ctx := _make_full_ctx_with_troop(Troop.TroopType.CABALLERIA)
	var event := UnlockCavalryChargeEvent.new()
	event.choices[0].execute(ctx)

	assert_eq(ctx.stats.discard_pile.cards.size(), 1,
		"Debe añadir 1 carta al descarte")
	assert_true(ctx.stats.discard_pile.cards[0] is TacticCard)
	assert_eq(ctx.stats.unlocked_card_pool.size(), 1,
		"Debe añadir 1 entrada al pool de tienda")


func test_unlock_phalanx_requires_pikemen() -> void:
	var stats := _make_stats()
	stats.empire.controlled_tiles = []
	stats.used_unique_events = ["unlock_open_front"]
	stats.types_ever_recruited = { Troop.TroopType.CABALLERIA: 1 }

	var ctx_no_piq := _make_context(stats)
	var event := UnlockPhalanxEvent.new()
	assert_false(event.is_available(ctx_no_piq),
		"Sin piqueros no debe activarse la doctrina de falange")

	stats.types_ever_recruited[Troop.TroopType.PIQUEROS] = 1
	var ctx_ok := _make_context(stats)
	assert_true(event.is_available(ctx_ok))


func test_unlock_arrow_rain_requires_ranged() -> void:
	var stats := _make_stats()
	stats.empire.controlled_tiles = []
	stats.used_unique_events = ["unlock_open_front"]
	stats.types_ever_recruited = { Troop.TroopType.INFANTERIA_LIGERA: 1 }

	var ctx_no_dis := _make_context(stats)
	var event := UnlockArrowRainEvent.new()
	assert_false(event.is_available(ctx_no_dis))

	stats.types_ever_recruited[Troop.TroopType.A_DISTANCIA] = 1
	var ctx_ok := _make_context(stats)
	assert_true(event.is_available(ctx_ok))


func test_unlock_ambush_requires_light_infantry() -> void:
	var stats := _make_stats()
	stats.empire.controlled_tiles = []
	stats.used_unique_events = ["unlock_open_front"]
	stats.types_ever_recruited = { Troop.TroopType.CABALLERIA: 1 }

	var ctx_no_lig := _make_context(stats)
	var event := UnlockAmbushEvent.new()
	assert_false(event.is_available(ctx_no_lig))

	stats.types_ever_recruited[Troop.TroopType.INFANTERIA_LIGERA] = 1
	var ctx_ok := _make_context(stats)
	assert_true(event.is_available(ctx_ok))


func test_unlock_frontal_assault_requires_heavy_infantry() -> void:
	var stats := _make_stats()
	stats.empire.controlled_tiles = []
	stats.used_unique_events = ["unlock_open_front"]
	stats.types_ever_recruited = { Troop.TroopType.INFANTERIA_LIGERA: 1 }

	var ctx_no_pes := _make_context(stats)
	var event := UnlockFrontalAssaultEvent.new()
	assert_false(event.is_available(ctx_no_pes))

	stats.types_ever_recruited[Troop.TroopType.INFANTERIA_PESADA] = 1
	var ctx_ok := _make_context(stats)
	assert_true(event.is_available(ctx_ok))


func test_all_tactic_unlock_events_are_unique() -> void:
	assert_true(UnlockCavalryChargeEvent.new().unique)
	assert_true(UnlockPhalanxEvent.new().unique)
	assert_true(UnlockArrowRainEvent.new().unique)
	assert_true(UnlockAmbushEvent.new().unique)
	assert_true(UnlockFrontalAssaultEvent.new().unique)


func test_tactic_unlock_events_are_skippable() -> void:
	# A diferencia de unlock_recruit/open_front (no skippable), las
	# doctrinas de táctica son opcionales: el jugador puede no querer
	# especializarse en esa rama.
	assert_true(UnlockCavalryChargeEvent.new().allow_skip)
	assert_true(UnlockPhalanxEvent.new().allow_skip)
	assert_true(UnlockArrowRainEvent.new().allow_skip)
	assert_true(UnlockAmbushEvent.new().allow_skip)
	assert_true(UnlockFrontalAssaultEvent.new().allow_skip)


func test_tactic_unlock_card_added_is_a_copy() -> void:
	# AddCardEffect debe duplicar el recurso para no mutar el .tres compartido.
	var ctx := _make_full_ctx_with_troop(Troop.TroopType.CABALLERIA)
	var event := UnlockCavalryChargeEvent.new()
	event.choices[0].execute(ctx)

	var card := ctx.stats.discard_pile.cards[0] as TacticCard
	assert_ne(card, UnlockCavalryChargeEvent.TACTIC_CARD,
			"La carta del descarte debe ser una copia, no el recurso compartido")
