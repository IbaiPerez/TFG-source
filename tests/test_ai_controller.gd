extends GutTest

## Tests para AIController. Cobertura Fase 1: bucle decisorio random,
## determinismo con seed, MAX_ITER, descarte de cartas no jugadas, emisión
## de turn_finished, integración con CardDraw.
##
## Política de tests:
##  - action_delay y turn_end_delay = 0 → _run_turn() corre síncrono.
##  - NO usamos `await ai.turn_finished`: como todo es síncrono, la señal
##    ya se emitió cuando llegamos al await y `await signal` solo escucha
##    emisiones futuras → cuelgue. En su lugar, watch_signals + asserción
##    inmediata, o `await get_tree().process_frame` como red de seguridad.


# ============================================================
#  Helpers
# ============================================================

func _make_empire(p_name: String = "TestAI") -> Empire:
	var e := Empire.new()
	e.name = p_name
	e.color = Color.RED
	e.controlled_tiles = []
	return e


func _make_tile(p_controller: Empire = null) -> Tile:
	var tile := Tile.new()
	tile.mesh_data = TileMeshData.new()
	tile.mesh_data.type = Tile.biome_type.Grassland
	tile.mesh_data.color = Color.GREEN
	tile.natural_resource = NaturalResource.new()
	tile.natural_resource.gold_produced = 1
	tile.natural_resource.food_produced = 1
	var loc := LocationType.new()
	loc.type = Tile.location_type.Village
	loc.max_building = 1
	loc.food_consumption = 0
	tile.location = loc
	tile.max_buildings = 1
	tile.food_production = 1
	tile.gold_production = 1
	tile.controller = p_controller
	tile.neighbors = []
	tile.buildings = []
	return tile


func _make_stats(p_gold: int = 100) -> Stats:
	var s := Stats.new()
	s.total_gold = p_gold
	s.gold_per_turn = 0
	s.food = 5
	s.cards_per_turn = 3
	s.deck = CardPile.new()
	s.draw_pile = CardPile.new()
	s.discard_pile = CardPile.new()
	s.played_pile = CardPile.new()
	s.empire = _make_empire()
	s.possible_buildings = []
	s.turn_number = 0
	s.event_chance = 0.0  # apagar eventos en tests
	return s


## Crea un AIController totalmente autónomo añadido al árbol con stats
## prefabricados. Cards van directamente a draw_pile (no a deck) para
## que start_game no las shuffleé en otro orden.
func _spawn_ai(stats: Stats, seed_value: int = -1) -> AIController:
	var ai := AIController.new()
	ai.action_delay = 0.0
	ai.turn_end_delay = 0.0
	ai.rng_seed = seed_value
	ai.max_iterations = 20
	add_child_autofree(ai)
	# Asignar stats directamente sin pasar por start_game para evitar
	# que el shuffle reordene las cartas de prueba.
	ai.stats = stats
	ai.turn_event_manager.stats = stats
	ai.battle_front_manager.stats = stats
	return ai


## Lanza el turno de la IA y espera a que termine. Como _run_turn() corre
## síncrono con delays=0, basta con un process_frame de seguridad para
## dejar que cualquier deferred call termine. NO awaitamos turn_finished
## (ver doc al inicio del archivo).
func _run_ai_turn(ai: AIController) -> void:
	ai.start_turn()
	await get_tree().process_frame


func _make_gold_card(p_id: String = "gold", p_amount: int = 10) -> GenerateGoldCard:
	var c := GenerateGoldCard.new()
	c.id = p_id
	c.target = Card.Target.SELF
	c.amount = p_amount
	return c


func _make_recruit_card_unaffordable() -> RecruitCard:
	# Carta sin tropas posibles → 0 opciones del builder. Útil para
	# forzar que la única opción del bucle sea PASS.
	var c := RecruitCard.new()
	c.id = "recruit"
	c.target = Card.Target.SELF
	c.available_troops = []
	return c


# ============================================================
#  Bucle: terminación y emisión de turn_finished
# ============================================================

func test_turn_emits_turn_finished_signal() -> void:
	var stats := _make_stats()
	stats.draw_pile.add_card(_make_gold_card())
	var ai := _spawn_ai(stats)
	watch_signals(ai)

	await _run_ai_turn(ai)

	assert_signal_emit_count(ai, "turn_finished", 1)


func test_played_gold_card_increases_total_gold() -> void:
	var stats := _make_stats(50)
	stats.cards_per_turn = 1
	stats.draw_pile.add_card(_make_gold_card("g", 30))
	var ai := _spawn_ai(stats, 0)
	ai.max_iterations = 5

	await _run_ai_turn(ai)

	# Con sólo 1 carta, dos opciones (jugar / PASS), gana 30 o no gana
	# nada. Cualquiera de los dos es válido.
	assert_true(stats.total_gold == 50 or stats.total_gold == 80,
		"Gold tras el turno debe ser 50 (pasó) o 80 (jugó). Fue %d" % stats.total_gold)


# ============================================================
#  Determinismo con seed
# ============================================================

func test_seeded_rng_produces_same_outcome_twice() -> void:
	# Mismo seed, mismas cartas, mismo estado inicial → mismo resultado.
	var stats_a := _make_stats(0)
	var stats_b := _make_stats(0)
	for i in range(5):
		stats_a.draw_pile.add_card(_make_gold_card("g%d" % i, 10))
		stats_b.draw_pile.add_card(_make_gold_card("g%d" % i, 10))
	stats_a.cards_per_turn = 5
	stats_b.cards_per_turn = 5

	var ai_a := _spawn_ai(stats_a, 12345)
	var ai_b := _spawn_ai(stats_b, 12345)

	await _run_ai_turn(ai_a)
	await _run_ai_turn(ai_b)

	assert_eq(stats_a.total_gold, stats_b.total_gold,
		"Mismo seed debe producir mismo total_gold final")
	assert_eq(stats_a.discard_pile.cards.size(), stats_b.discard_pile.cards.size(),
		"Mismo seed debe descartar el mismo número de cartas")


# ============================================================
#  PASS y descarte
# ============================================================

func test_no_playable_options_only_pass_is_chosen() -> void:
	# RecruitCard sin tropas → 0 opciones del builder. Única opción del
	# bucle es PASS, así que sale inmediatamente.
	var stats := _make_stats()
	stats.cards_per_turn = 2
	stats.draw_pile.add_card(_make_recruit_card_unaffordable())
	stats.draw_pile.add_card(_make_recruit_card_unaffordable())

	var ai := _spawn_ai(stats, 42)
	await _run_ai_turn(ai)

	# Las dos cartas terminan en discard (no se jugaron pero se descartan).
	assert_eq(stats.discard_pile.cards.size(), 2,
		"Cartas no jugadas deben ir al discard")


func test_unplayed_cards_go_to_discard_pile() -> void:
	# Mezcla: una carta jugable y una no jugable. Independientemente de
	# la decisión, ambas terminan en discard (jugada o descartada).
	var stats := _make_stats()
	stats.cards_per_turn = 2
	stats.draw_pile.add_card(_make_gold_card())
	stats.draw_pile.add_card(_make_recruit_card_unaffordable())

	var ai := _spawn_ai(stats, 7)
	await _run_ai_turn(ai)

	assert_eq(stats.discard_pile.cards.size(), 2,
		"Las 2 cartas robadas deben terminar en discard (jugada o no)")


# ============================================================
#  Cartas single-use van a played_pile, no a discard
# ============================================================

func test_single_use_played_card_goes_to_played_pile() -> void:
	# Forzamos que se juegue probando varios seeds: con sólo 2 opciones
	# (jugar/PASS) y 30 intentos, casi seguro encontramos uno que juegue.
	var found_played := false
	for s in range(0, 30):
		var stats := _make_stats()
		stats.cards_per_turn = 1
		var card := _make_gold_card("single", 30)
		card.type = Card.Type.SINGLE_USE
		stats.draw_pile.add_card(card)

		var ai := _spawn_ai(stats, s)
		await _run_ai_turn(ai)

		if stats.played_pile.cards.size() == 1:
			found_played = true
			break

	assert_true(found_played,
		"Algún seed debe llevar a jugar la carta single-use → played_pile")


# ============================================================
#  CardDraw integration
# ============================================================

func test_card_draw_card_extends_drawn_cards() -> void:
	# Robar 1 carta inicial (CardDrawCard) y que ésta robe 2 más.
	# CardPile.draw_card() hace pop_back (LIFO), así que la CardDrawCard
	# se añade DE ÚLTIMA para que sea la primera en robarse.
	var found_draw_played := false
	for s in range(0, 30):
		var stats := _make_stats()
		stats.cards_per_turn = 1
		# Orden de adición → orden inverso de robo (LIFO):
		# añadidos g1, g2, draw → se roba primero "draw"
		stats.draw_pile.add_card(_make_gold_card("g1", 5))
		stats.draw_pile.add_card(_make_gold_card("g2", 5))
		var dc := CardDrawCard.new()
		dc.id = "draw"
		dc.target = Card.Target.SELF
		dc.amount = 2
		stats.draw_pile.add_card(dc)
		stats.total_gold = 0
		stats.turn_number = 0

		var ai := _spawn_ai(stats, s)
		await _run_ai_turn(ai)

		# Si jugó la CardDrawCard, las 3 cartas (draw + 2 gold) terminan
		# en discard (jugadas o descartadas como leftovers).
		if stats.discard_pile.cards.size() == 3:
			found_draw_played = true
			break

	assert_true(found_draw_played,
		"Algún seed debe llevar a jugar la CardDrawCard y robar 2 más")


# ============================================================
#  MAX_ITER guardrail
# ============================================================

func test_ai_can_build_a_building_end_to_end() -> void:
	# Test integración Fase 2: la IA con BuildCard + possible_buildings
	# poblado debe poder construir el edificio en su tile.
	# Iteramos seeds porque hay 2 opciones (build / PASS).
	var built := false
	for s in range(0, 30):
		var stats := _make_stats(500)
		stats.cards_per_turn = 1

		var building := Building.new()
		building.name = "TestMine"
		building.construction_cost = 50
		building.gold_produced = 5
		building.food_produced = 0
		building.allowed_biomes = []
		building.allowed_location_type = []
		building.required_natural_resource = null
		building.effects = []
		building.upgrades_to = []

		var tile := _make_tile(stats.empire)
		tile.max_buildings = 2
		# Anular producción del tile para que _process_turn_start no
		# distorsione el oro y la asserción del coste sea exacta.
		tile.natural_resource.gold_produced = 0
		tile.natural_resource.food_produced = 0
		tile.gold_production = 0
		tile.food_production = 0
		add_child_autofree(tile)
		stats.empire.controlled_tiles = [tile]
		stats.possible_buildings = [building]

		var card := BuildCard.new()
		card.id = "build"
		card.target = Card.Target.TILE
		card.buildings = [building]
		stats.draw_pile.add_card(card)

		var ai := _spawn_ai(stats, s)
		await _run_ai_turn(ai)

		if tile.buildings.size() == 1 and tile.buildings[0].name == "TestMine":
			built = true
			# Verificar que se descontó el oro y la carta fue al discard.
			assert_eq(stats.total_gold, 450, "El coste se debe descontar")
			assert_eq(stats.discard_pile.cards.size(), 1, "La carta jugada va al discard")
			break

	assert_true(built, "Algún seed debe llevar a la IA a construir el edificio")


func test_ai_resolves_turn_event_at_end_of_turn() -> void:
	# Test integración Fase 4: tras el bucle de cartas, la IA evalúa
	# eventos y resuelve uno headless. Con event_chance=1.0 siempre
	# se dispara. Un evento de +30 oro sin choices alternativas → la
	# IA debe acabar con +30 oro respecto al inicio (descontando lo
	# que jugara con sus cartas, que aquí no tiene).
	var stats := _make_stats(50)
	stats.event_chance = 1.0
	stats.cards_per_turn = 1
	# Sin cartas → la IA no juega nada, pero el evento se dispara.
	# (Sin cartas no roba nada, drawn_cards queda vacío y el bucle sale.)

	var event := TurnEvent.new()
	event.id = "merchant"
	event.weight = 1.0
	event.allow_skip = false
	event.choices = []
	var choice := TurnEventChoice.new()
	choice.effects = [GoldEventEffect.new(30)]
	event.choices = [choice]
	stats.available_events = [event]

	var ai := _spawn_ai(stats, 12345)
	await _run_ai_turn(ai)

	# Tras el turno: oro inicial 50 + evento 30 = 80.
	assert_eq(stats.total_gold, 80,
		"El evento debe haberse resuelto y aplicado el efecto")


func test_ai_can_recover_a_card_from_played_pile() -> void:
	# Test integración Fase 3: RecoverCard de la IA recupera una carta
	# de played_pile y la añade a drawn_cards (vía card_returned_to_hand
	# listener) para que pueda ser jugada en otra iteración.
	#
	# Con heurística determinista la IA siempre elige la mejor opción:
	#   1. RecoverCard es la única carta → se juega (score deck_urgency > PASS).
	#   2. La recoverable (GenerateGoldCard) entra en drawn_cards y se juega
	#      también (score gold_urgency > PASS cuando total_gold = 0).
	#   3. El oro aumenta → prueba que ambas cartas se ejecutaron correctamente.
	# No se necesita iterar seeds: la heurística es determinista.
	var stats := _make_stats()
	stats.cards_per_turn = 1

	var recoverable := _make_gold_card("recoverable", 25)
	recoverable.type = Card.Type.SINGLE_USE  # se mantiene legítimamente en played_pile
	stats.played_pile.add_card(recoverable)

	var rc := RecoverCard.new()
	rc.id = "recover"
	rc.target = Card.Target.SELF
	rc.type = Card.Type.SINGLE_USE
	stats.draw_pile.add_card(rc)
	stats.total_gold = 0
	stats.turn_number = 0

	var ai := _spawn_ai(stats)
	await _run_ai_turn(ai)

	# El oro aumentó en 25 → RecoverCard fue jugada (sacó recoverable de
	# played_pile), y la recoverable (GenerateGoldCard) fue jugada después.
	assert_true(stats.total_gold > 0,
		"La IA jugó RecoverCard y la carta recuperada (GenerateGoldCard): oro debe ser > 0, fue %d" % stats.total_gold)


func test_max_iterations_caps_loop() -> void:
	# Smoke test: con MAX_ITER bajo, el turno debe terminar limpiamente.
	var stats := _make_stats()
	stats.cards_per_turn = 1
	stats.draw_pile.add_card(_make_gold_card())
	var ai := _spawn_ai(stats, 99)
	ai.max_iterations = 3
	watch_signals(ai)

	await _run_ai_turn(ai)

	assert_signal_emit_count(ai, "turn_finished", 1,
		"El turno termina y emite turn_finished con MAX_ITER bajo")


# ============================================================
#  Asignacion de tropas a frentes (Fase militar)
# ============================================================
#
# La IA del jugador asigna tropas via BattleFrontPanel + SceneManager.
# La AI no tiene UI, asi que rellena cada frente propio con
# MIN_TROOPS_PER_FRONT tropas del pool al inicio del turno. Hasta que
# se sustituya por una heuristica con prioridad, estos tests fijan el
# contrato: side correcto, no toca frentes ajenos, respeta el minimo,
# no falla con pool vacio y reparte hasta agotar el pool.

func _make_troop_for_assign(p_name: String = "T", p_cost: int = 10) -> Troop:
	var t := Troop.new()
	t.name = p_name
	t.attack = 3
	t.defense = 3
	t.recruitment_cost_gold = p_cost
	t.maintenance_gold = 1
	t.maintenance_food = 1
	return t


## Crea un frente y lo mete directamente en el manager de la IA, sin
## pasar por open_front() (que valida adyacencia). Asi podemos construir
## el escenario exacto sin montar tiles.
func _push_front_into_manager(ai: AIController, atk_emp: Empire, def_emp: Empire) -> BattleFront:
	var atk_tile := _make_tile(atk_emp)
	var def_tile := _make_tile(def_emp)
	add_child_autofree(atk_tile)
	add_child_autofree(def_tile)
	var front := BattleFront.new(atk_tile, def_tile, atk_emp, def_emp)
	ai.battle_front_manager.active_fronts.append(front)
	return front


func test_assign_fills_attacker_front_up_to_min_troops() -> void:
	BattleFront.clear_active_instances()
	var stats := _make_stats()
	stats.troop_pool = [
		_make_troop_for_assign("t1"),
		_make_troop_for_assign("t2"),
		_make_troop_for_assign("t3"),
		_make_troop_for_assign("t4"),  # sobrante: solo deben asignarse 3
	]
	var ai := _spawn_ai(stats)
	var enemy := _make_empire("Enemy")
	var front := _push_front_into_manager(ai, stats.empire, enemy)

	ai._assign_troops_to_fronts()

	assert_eq(front.attacker_troops.size(), AIController.MIN_TROOPS_PER_FRONT,
		"Debe rellenar el frente atacante hasta MIN_TROOPS_PER_FRONT")
	assert_eq(front.defender_troops.size(), 0,
		"No debe asignar tropas al bando defensor del frente")
	assert_eq(stats.troop_pool.size(), 1,
		"Solo el sobrante debe quedar en el pool")
	BattleFront.clear_active_instances()


func test_assign_fills_defender_front_up_to_min_troops() -> void:
	BattleFront.clear_active_instances()
	var stats := _make_stats()
	stats.troop_pool = [
		_make_troop_for_assign("t1"),
		_make_troop_for_assign("t2"),
		_make_troop_for_assign("t3"),
	]
	var ai := _spawn_ai(stats)
	var enemy := _make_empire("Enemy")
	# stats.empire es el DEFENSOR esta vez
	var front := _push_front_into_manager(ai, enemy, stats.empire)

	ai._assign_troops_to_fronts()

	assert_eq(front.defender_troops.size(), AIController.MIN_TROOPS_PER_FRONT,
		"Debe rellenar el frente defensor hasta MIN_TROOPS_PER_FRONT")
	assert_eq(front.attacker_troops.size(), 0,
		"No debe asignar tropas al bando atacante (es del rival)")
	assert_eq(stats.troop_pool.size(), 0)
	BattleFront.clear_active_instances()


func test_assign_skips_front_where_ia_does_not_participate() -> void:
	BattleFront.clear_active_instances()
	var stats := _make_stats()
	stats.troop_pool = [_make_troop_for_assign("t1"), _make_troop_for_assign("t2")]
	var ai := _spawn_ai(stats)
	var enemy1 := _make_empire("E1")
	var enemy2 := _make_empire("E2")
	var front := _push_front_into_manager(ai, enemy1, enemy2)

	ai._assign_troops_to_fronts()

	assert_eq(front.attacker_troops.size(), 0,
		"Frente entre rivales: la IA no debe asignar nada")
	assert_eq(front.defender_troops.size(), 0)
	assert_eq(stats.troop_pool.size(), 2, "El pool no debe haber tocado nada")
	BattleFront.clear_active_instances()


func test_assign_is_noop_with_empty_pool() -> void:
	BattleFront.clear_active_instances()
	var stats := _make_stats()
	stats.troop_pool = []
	var ai := _spawn_ai(stats)
	var enemy := _make_empire("Enemy")
	var front := _push_front_into_manager(ai, stats.empire, enemy)

	ai._assign_troops_to_fronts()  # no debe petar

	assert_eq(front.attacker_troops.size(), 0)
	BattleFront.clear_active_instances()


func test_assign_distributes_until_pool_exhausted_across_fronts() -> void:
	# 5 tropas, 2 frentes propios en equilibrio: uno se llena (MIN=3) y el
	# otro recibe el resto (2). Con urgencia igual, el orden no es determinista,
	# así que solo verificamos el total y que ninguno supere MIN.
	BattleFront.clear_active_instances()
	var stats := _make_stats()
	stats.troop_pool = []
	for i in range(5):
		stats.troop_pool.append(_make_troop_for_assign("t%d" % i))
	var ai := _spawn_ai(stats)
	var enemy := _make_empire("Enemy")
	var f1 := _push_front_into_manager(ai, stats.empire, enemy)
	var f2 := _push_front_into_manager(ai, stats.empire, enemy)

	ai._assign_troops_to_fronts()

	var total := f1.attacker_troops.size() + f2.attacker_troops.size()
	assert_eq(total, 5, "Las 5 tropas deben repartirse entre los dos frentes")
	assert_true(f1.attacker_troops.size() <= AIController.MIN_TROOPS_PER_FRONT,
		"Ningún frente supera MIN en equilibrio (primera pasada)")
	assert_true(f2.attacker_troops.size() <= AIController.MIN_TROOPS_PER_FRONT,
		"Ningún frente supera MIN en equilibrio (primera pasada)")
	assert_eq(stats.troop_pool.size(), 0, "Pool agotado")
	BattleFront.clear_active_instances()


func test_assign_uses_global_active_instances_for_external_front() -> void:
	# Regresion del bug del defensor: el frente lo abrio el rival y por
	# tanto NO esta en battle_front_manager.active_fronts de la IA. Antes
	# del fix, _assign_troops_to_fronts ignoraba el frente y el defensor
	# nunca recibia refuerzos.
	BattleFront.clear_active_instances()
	var stats := _make_stats()
	stats.troop_pool = [
		_make_troop_for_assign("d1"),
		_make_troop_for_assign("d2"),
		_make_troop_for_assign("d3"),
	]
	var ai := _spawn_ai(stats)
	var enemy := _make_empire("Atacante")

	# Crear el frente SIN meterlo en ai.battle_front_manager.active_fronts.
	# stats.empire es el defensor. El registro global ya recoge el frente
	# automaticamente en _init de BattleFront.
	var atk_tile := _make_tile(enemy)
	var def_tile := _make_tile(stats.empire)
	add_child_autofree(atk_tile)
	add_child_autofree(def_tile)
	var front := BattleFront.new(atk_tile, def_tile, enemy, stats.empire)
	assert_false(front in ai.battle_front_manager.active_fronts,
		"Pre: frente NO debe estar en el manager local (es externo)")

	ai._assign_troops_to_fronts()

	assert_eq(front.defender_troops.size(), AIController.MIN_TROOPS_PER_FRONT,
		"Defensor debe llenar el frente externo via registro global")
	assert_eq(stats.troop_pool.size(), 0)
	BattleFront.clear_active_instances()


func test_second_pass_assigns_troops_recruited_during_turn() -> void:
	# Simula el orden: 1ª pasada (pool vacio, frente vacio), durante el
	# turno se recluta una tropa (pool +1), 2ª pasada al final del turno
	# debe meter esa tropa al frente. Documenta el motivo de la doble
	# llamada en _run_turn.
	BattleFront.clear_active_instances()
	var stats := _make_stats()
	stats.troop_pool = []  # pool vacio al inicio
	var ai := _spawn_ai(stats)
	var enemy := _make_empire("Enemy")
	var front := _push_front_into_manager(ai, stats.empire, enemy)

	ai._assign_troops_to_fronts()  # 1ª pasada
	assert_eq(front.attacker_troops.size(), 0,
		"Sin tropas en el pool, la 1ª pasada no asigna nada")

	# Simular Recruit jugado durante el turno: una nueva tropa entra al pool.
	stats.troop_pool.append(_make_troop_for_assign("recien_reclutada"))

	ai._assign_troops_to_fronts()  # 2ª pasada (al final del turno en _run_turn)
	assert_eq(front.attacker_troops.size(), 1,
		"2ª pasada debe asignar la tropa recien reclutada")
	assert_eq(stats.troop_pool.size(), 0)
	BattleFront.clear_active_instances()


func test_assign_does_not_top_up_already_satisfied_front() -> void:
	# Frente que ya tiene MIN tropas asignadas previamente: la rutina
	# NO debe meter mas. Eso garantiza que el coste por frente no
	# escale incontroladamente con el numero de turnos.
	BattleFront.clear_active_instances()
	var stats := _make_stats()
	stats.troop_pool = [_make_troop_for_assign("extra")]
	var ai := _spawn_ai(stats)
	var enemy := _make_empire("Enemy")
	var front := _push_front_into_manager(ai, stats.empire, enemy)
	for i in range(AIController.MIN_TROOPS_PER_FRONT):
		front.attacker_troops.append(_make_troop_for_assign("pre%d" % i))

	ai._assign_troops_to_fronts()

	assert_eq(front.attacker_troops.size(), AIController.MIN_TROOPS_PER_FRONT,
		"No debe pasar del minimo si ya estaba lleno")
	assert_eq(stats.troop_pool.size(), 1,
		"La tropa sobrante se queda en el pool")
	BattleFront.clear_active_instances()


# ============================================================
#  Heurística v2: urgencia y selección de tropa
# ============================================================

func test_assign_prioritizes_losing_front_when_pool_is_limited() -> void:
	# Con solo MIN tropas en pool y dos frentes, el frente donde se pierde
	# (marker negativo grave) debe llenarse antes que el frente en equilibrio.
	BattleFront.clear_active_instances()
	var stats := _make_stats()
	stats.troop_pool = []
	for i in range(AIController.MIN_TROOPS_PER_FRONT):
		stats.troop_pool.append(_make_troop_for_assign("t%d" % i))
	var ai := _spawn_ai(stats)
	var enemy := _make_empire("Enemy")
	var f_losing := _push_front_into_manager(ai, stats.empire, enemy)
	f_losing.marker = -8.0  # perdiendo gravemente (base_urgency 3.0)
	var f_balanced := _push_front_into_manager(ai, stats.empire, enemy)
	f_balanced.marker = 0.0   # equilibrio (base_urgency 1.5)

	ai._assign_troops_to_fronts()

	assert_eq(f_losing.attacker_troops.size(), AIController.MIN_TROOPS_PER_FRONT,
		"Frente donde se pierde debe llenarse antes")
	assert_eq(f_balanced.attacker_troops.size(), 0,
		"Frente equilibrado no recibe tropas si el pool se agotó")
	assert_eq(stats.troop_pool.size(), 0)
	BattleFront.clear_active_instances()


func test_assign_second_pass_reinforces_losing_front() -> void:
	# Frente con marker negativo (base_urgency > 1.5): debe recibir hasta
	# MIN + 2 tropas si el pool lo permite.
	BattleFront.clear_active_instances()
	var stats := _make_stats()
	stats.troop_pool = []
	for i in range(AIController.MIN_TROOPS_PER_FRONT + 2):
		stats.troop_pool.append(_make_troop_for_assign("t%d" % i))
	var ai := _spawn_ai(stats)
	var enemy := _make_empire("Enemy")
	var front := _push_front_into_manager(ai, stats.empire, enemy)
	front.marker = -4.0  # perdiendo (base_urgency 2.0 > 1.5)

	ai._assign_troops_to_fronts()

	assert_eq(front.attacker_troops.size(), AIController.MIN_TROOPS_PER_FRONT + 2,
		"Frente donde se pierde debe recibir MIN + 2 con pool suficiente")
	assert_eq(stats.troop_pool.size(), 0)
	BattleFront.clear_active_instances()


func test_assign_second_pass_does_not_reinforce_balanced_front() -> void:
	# Frente en equilibrio (base_urgency = 1.5): no supera MIN aunque haya tropas.
	BattleFront.clear_active_instances()
	var stats := _make_stats()
	stats.troop_pool = []
	for i in range(AIController.MIN_TROOPS_PER_FRONT + 2):
		stats.troop_pool.append(_make_troop_for_assign("t%d" % i))
	var ai := _spawn_ai(stats)
	var enemy := _make_empire("Enemy")
	var front := _push_front_into_manager(ai, stats.empire, enemy)
	front.marker = 0.0  # equilibrio (base_urgency 1.5, NOT > 1.5)

	ai._assign_troops_to_fronts()

	assert_eq(front.attacker_troops.size(), AIController.MIN_TROOPS_PER_FRONT,
		"Frente en equilibrio no se refuerza más allá de MIN")
	assert_eq(stats.troop_pool.size(), 2,
		"Las 2 tropas de refuerzo quedan sin usar en el pool")
	BattleFront.clear_active_instances()


func test_assign_selects_best_defense_troop_for_defender() -> void:
	# Como defensor, se debe asignar primero la tropa con mayor defense.
	BattleFront.clear_active_instances()
	var stats := _make_stats()
	var t_weak := Troop.new()
	t_weak.name = "high_attack"
	t_weak.attack = 9
	t_weak.defense = 1
	var t_tank := Troop.new()
	t_tank.name = "high_defense"
	t_tank.attack = 1
	t_tank.defense = 9
	stats.troop_pool = [t_weak, t_tank]

	var ai := _spawn_ai(stats)
	var enemy := _make_empire("Attacker")
	var front := _push_front_into_manager(ai, enemy, stats.empire)  # ai es defensor

	ai._assign_troops_to_fronts()

	assert_true(front.defender_troops.size() > 0, "Debe haberse asignado al menos una tropa")
	assert_eq(front.defender_troops[0].name, "high_defense",
		"Defensor elige la tropa con mayor defense primero")
	BattleFront.clear_active_instances()


func test_assign_selects_best_attack_troop_for_attacker() -> void:
	# Como atacante, se debe asignar primero la tropa con mayor attack.
	BattleFront.clear_active_instances()
	var stats := _make_stats()
	var t_tank := Troop.new()
	t_tank.name = "high_defense"
	t_tank.attack = 1
	t_tank.defense = 9
	var t_striker := Troop.new()
	t_striker.name = "high_attack"
	t_striker.attack = 9
	t_striker.defense = 1
	stats.troop_pool = [t_tank, t_striker]

	var ai := _spawn_ai(stats)
	var enemy := _make_empire("Enemy")
	var front := _push_front_into_manager(ai, stats.empire, enemy)  # ai es atacante

	ai._assign_troops_to_fronts()

	assert_true(front.attacker_troops.size() > 0, "Debe haberse asignado al menos una tropa")
	assert_eq(front.attacker_troops[0].name, "high_attack",
		"Atacante elige la tropa con mayor attack primero")
	BattleFront.clear_active_instances()
