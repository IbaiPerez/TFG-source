extends Node
class_name EmpireController

## Clase base para cualquier controlador de imperio (jugador o IA).
## Contiene la logica compartida de turno: stats, modificadores, eventos,
## produccion, gestion de mazo, y ability del imperio.

signal turn_finished(controller:EmpireController)

var stats:Stats
var modifier_manager:ModifierManager
var turn_event_manager:TurnEventManager

func _init_managers() -> void:
	modifier_manager = ModifierManager.new()
	add_child(modifier_manager)

	turn_event_manager = TurnEventManager.new()
	add_child(turn_event_manager)

	Events.request_add_modifier.connect(_on_request_add_modifier)
	Events.request_remove_modifier.connect(_on_request_remove_modifier)

func start_game(new_stats:Stats) -> void:
	stats = new_stats
	stats.draw_pile = stats.deck.duplicate(true)
	stats.draw_pile.shuffle()
	stats.discard_pile = CardPile.new()
	stats.played_pile = CardPile.new()
	stats.empire.tile_conquered.connect(_on_tile_conquered)
	stats.empire.tile_lost.connect(_on_tile_lost)
	turn_event_manager.stats = stats
	_apply_empire_ability()

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
func _process_turn_start() -> void:
	stats.turn_number += 1
	modifier_manager.tick()

	var base_gold := 0
	var base_food := 0
	for t in stats.empire.controlled_tiles:
		base_gold += t.gold_production + modifier_manager.get_tile_gold_bonus(t)
		base_food += t.food_production + modifier_manager.get_tile_food_bonus(t)
		# Asegurar que las señales de building estan conectadas
		if not t.building_completed.is_connected(_on_building_completed):
			t.building_completed.connect(_on_building_completed)
		if not t.building_demolished.is_connected(_on_building_demolished):
			t.building_demolished.connect(_on_building_demolished)

	base_gold += modifier_manager.get_flat_gold()
	base_food += modifier_manager.get_flat_food()

	var final_gold := int(base_gold * (1.0 + modifier_manager.get_percent_gold() / 100.0))
	var final_food := int(base_food * (1.0 + modifier_manager.get_percent_food() / 100.0))

	stats.gold_per_turn = final_gold
	stats.food = final_food
	stats.total_gold += stats.gold_per_turn

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
	var context = EventContext.build(stats, modifier_manager, stats.turn_number)
	var event = turn_event_manager.evaluate(context)

	if event != null:
		Events.turn_event_triggered.emit(event, context)
		return true
	return false

## Procesa una carta jugada (descarte, devolucion a mano, o uso unico).
func _handle_card_played(card:Card) -> void:
	if modifier_manager.should_return_to_hand(card):
		stats.discard_pile.add_card(card)
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
	stats.gold_per_turn += tile.natural_resource.gold_produced
	stats.food -= tile.natural_resource.food_produced
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

## Metodo abstracto: las subclases implementan su logica de turno.
func start_turn() -> void:
	pass

## Metodo abstracto: fin de turno.
func end_turn() -> void:
	pass
