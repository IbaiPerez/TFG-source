extends Node
class_name EmpireController

## Clase base para cualquier controlador de imperio (jugador o IA).
## Contiene la logica compartida de turno: stats, modificadores, eventos,
## produccion, gestion de mazo, y ability del imperio.

signal turn_finished(controller:EmpireController)

var stats:Stats
var modifier_manager:ModifierManager
var turn_event_manager:TurnEventManager
var battle_front_manager:BattleFrontManager

func _init_managers() -> void:
	modifier_manager = ModifierManager.new()
	add_child(modifier_manager)

	turn_event_manager = TurnEventManager.new()
	add_child(turn_event_manager)

	battle_front_manager = BattleFrontManager.new()
	add_child(battle_front_manager)

	Events.request_add_modifier.connect(_on_request_add_modifier)
	Events.request_remove_modifier.connect(_on_request_remove_modifier)

func start_game(new_stats:Stats) -> void:
	stats = new_stats
	# Back-reference para que cartas que necesiten consultar bonuses (p.ej.
	# RecruitCard leyendo `get_troops_per_recruit_bonus`) puedan hacerlo
	# sin lookups en el scene tree.
	stats.modifier_manager = modifier_manager
	stats.draw_pile = stats.deck.duplicate(true)
	stats.draw_pile.shuffle()
	stats.discard_pile = CardPile.new()
	stats.played_pile = CardPile.new()
	stats.empire.tile_conquered.connect(_on_tile_conquered)
	stats.empire.tile_lost.connect(_on_tile_lost)
	turn_event_manager.stats = stats
	battle_front_manager.stats = stats
	_apply_empire_ability()


## Variante de start_game para cuando estamos cargando una partida.
##
## A diferencia de start_game(), aquí:
## - NO se reshufflea el deck (las pilas vienen ya restauradas con el
##   orden literal que tenían en el save).
## - NO se reaplica la ability del imperio (sus modifiers y buildings
##   exclusivos ya están en el snapshot, restaurarlos otra vez los
##   duplicaría).
## - Se conectan las mismas señales que start_game() para que los
##   handlers de turno funcionen igual a partir de aquí.
func restore_from_save(restored_stats:Stats) -> void:
	stats = restored_stats
	stats.modifier_manager = modifier_manager
	if stats.empire != null:
		if not stats.empire.tile_conquered.is_connected(_on_tile_conquered):
			stats.empire.tile_conquered.connect(_on_tile_conquered)
		if not stats.empire.tile_lost.is_connected(_on_tile_lost):
			stats.empire.tile_lost.connect(_on_tile_lost)
	turn_event_manager.stats = stats
	battle_front_manager.stats = stats

	# Reconectar señales de buildings de cada tile controlado, igual que
	# hace _process_turn_start() de forma defensiva.
	for t in stats.empire.controlled_tiles:
		if not t.building_completed.is_connected(_on_building_completed):
			t.building_completed.connect(_on_building_completed)
		if not t.building_demolished.is_connected(_on_building_demolished):
			t.building_demolished.connect(_on_building_demolished)

func _apply_empire_ability() -> void:
	var ability := stats.empire.ability
	if ability == null:
		return

	for mod in ability.create_modifiers():
		mod.duration = -1
		modifier_manager.add_modifier(mod, stats)

	for building in ability.exclusive_buildings:
		stats.add_possible_building(building)

## Calcula produccion y avanza el turno. Las subclases llaman a esto
## al inicio de su turno.
##
## El calculo numerico (tiles, modifiers, mantenimiento, recargos de
## frente) se delega en `ProductionCalculator` (refactor H2). Aqui solo
## quedan los efectos secundarios: tick de modifiers, reconexion de
## señales de building, escritura en `stats` y actualizacion del
## `combat_multiplier` segun el deficit resultante.
func _process_turn_start() -> void:
	stats.turn_number += 1
	modifier_manager.tick()

	# Aseguramos las señales de building en los tiles controlados antes
	# de calcular (mismo comportamiento defensivo que en el codigo previo).
	for t in stats.empire.controlled_tiles:
		if not t.building_completed.is_connected(_on_building_completed):
			t.building_completed.connect(_on_building_completed)
		if not t.building_demolished.is_connected(_on_building_demolished):
			t.building_demolished.connect(_on_building_demolished)

	var calc := ProductionCalculator.new(stats, modifier_manager, battle_front_manager)
	var result := calc.calculate_turn()

	# Las tres escrituras se agrupan en una sola emisión de stats_changed
	# (evita re-renders de UI redundantes al inicio de cada turno).
	stats.begin_update()
	stats.gold_per_turn = result["gold"]
	stats.food = result["food"]
	stats.total_gold += stats.gold_per_turn
	stats.end_update()

	# Penalizacion de combate por economia en deficit (Opcion 3).
	# Tras fijar gpt/food del turno, derivamos el combat_multiplier del
	# imperio segun cuanto del mantenimiento total no estamos cubriendo.
	_update_combat_multiplier(result["total_troop_maint"])

## Actualiza `stats.empire.combat_multiplier` segun el deficit economico.
##
## Idea: si la produccion de oro o comida cae en negativo, parte del
## mantenimiento de las tropas no esta cubierto. Calculamos cuanto del
## mantenimiento total se queda sin cubrir como ratio:
##   penalty = (max(0,-gpt) + max(0,-food)) / total_troop_maint
## y aplicamos `multiplier = 1 - penalty` clampeado a [0.1, 1.0]. El
## multiplier afecta al ataque/defensa de las tropas en BattleFront pero
## NUNCA llega a 0 — incluso en colapso absoluto las tropas conservan el
## 10% de sus stats.
##
## Si el imperio no tiene tropas (`total_troop_maint == 0`), no hay nada
## que penalizar y devolvemos a 1.0 explicitamente (cubre el caso de que
## el multiplier hubiera quedado bajo de un turno con tropas y luego
## todas se hayan resuelto/muerto).
func _update_combat_multiplier(total_troop_maint: int) -> void:
	if stats == null or stats.empire == null:
		return
	if total_troop_maint <= 0:
		stats.empire.combat_multiplier = 1.0
		return
	var deficit_gold := maxi(0, -stats.gold_per_turn)
	var deficit_food := maxi(0, -stats.food)
	var total_deficit := deficit_gold + deficit_food
	var penalty_ratio := float(total_deficit) / float(total_troop_maint)
	stats.empire.combat_multiplier = clampf(1.0 - penalty_ratio, 0.1, 1.0)


## Devuelve el numero efectivo de cartas por turno con bonuses.
func _get_effective_cards_per_turn() -> int:
	var effective := stats.cards_per_turn + modifier_manager.get_cards_per_turn_bonus()
	return clampi(effective, 1, 20)

## Roba una carta del draw_pile (reshuffleando si hace falta).
func _draw_single_card() -> Card:
	_reshuffle_deck_from_discard()
	var card := stats.draw_pile.draw_card()
	_reshuffle_deck_from_discard()
	return card

func _reshuffle_deck_from_discard() -> void:
	if not stats.draw_pile.empty():
		return
	while not stats.discard_pile.empty():
		stats.draw_pile.add_card(stats.discard_pile.draw_card())
	stats.draw_pile.shuffle()

## Evalua eventos de fin de turno. Retorna true si hay un evento pendiente.
func _evaluate_end_of_turn() -> bool:
	var context = EventContext.build(stats, modifier_manager, stats.turn_number, battle_front_manager)
	var event = turn_event_manager.evaluate(context)

	if event != null:
		Events.turn_event_triggered.emit(event, context)
		return true
	return false

## Procesa una carta jugada (descarte, devolucion a mano, o uso unico).
func _handle_card_played(card:Card) -> void:
	if modifier_manager.should_return_to_hand(card):
		Events.card_returned_to_hand.emit(card, stats)
	elif card.is_single_use():
		stats.played_pile.add_card(card)
	else:
		stats.discard_pile.add_card(card)

func _on_tile_conquered(tile:Tile):
	stats.gold_per_turn += tile.gold_production
	stats.food += tile.food_production
	tile.building_completed.connect(_on_building_completed)
	tile.building_demolished.connect(_on_building_demolished)

func _on_tile_lost(tile:Tile):
	# Simétrico con _on_tile_conquered: restamos la produccion COMPLETA del tile
	# (recurso natural + edificios − consumo de la localizacion), no solo el
	# recurso natural. Restar de menos inflaba el gold/food por turno mostrado
	# hasta que el recalculo completo de ProductionCalculator lo corregia al
	# inicio del siguiente turno.
	stats.gold_per_turn -= tile.gold_production
	stats.food -= tile.food_production
	tile.building_completed.disconnect(_on_building_completed)
	tile.building_demolished.disconnect(_on_building_demolished)

func _on_building_completed(building:Building):
	stats.gold_per_turn += building.gold_produced
	stats.food += building.food_produced

func _on_building_demolished(building:Building):
	stats.gold_per_turn -= building.gold_produced
	stats.food -= building.food_produced

## Callbacks para que los BuildingEffect puedan añadir/quitar modificadores.
func _on_request_add_modifier(modifier:Modifier, p_stats:Stats) -> void:
	if p_stats == stats:
		modifier_manager.add_modifier(modifier, stats)

func _on_request_remove_modifier(modifier:Modifier) -> void:
	if modifier in modifier_manager.active_modifiers:
		modifier_manager.remove_modifier(modifier)

## Procesa los frentes de batalla al inicio del turno.
func _process_battle_fronts() -> void:
	battle_front_manager.tick_all_fronts()

## Metodo abstracto: las subclases implementan su logica de turno.
func start_turn() -> void:
	pass

## Metodo abstracto: fin de turno.
func end_turn() -> void:
	pass

## Llamado por el TurnManager cuando se reanuda una partida desde un save
## y este controller es el que tenia el turno activo.
##
## Por defecto reanuda como un start_turn normal (caso conservador: si el
## controller no diferencia, simplemente volvera a empezar el turno).
## Las subclases que persisten estado intra-turno (mano, recursos ya
## calculados, etc.) deben sobreescribir este metodo para NO repetir
## la logica de inicio.
func resume_turn() -> void:
	start_turn()
