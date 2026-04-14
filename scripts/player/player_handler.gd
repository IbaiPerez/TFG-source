extends Node
class_name PlayerHandler

const HAND_DRAW_INTERVAL := 0.25
const HAND_DISCARD_INTERVAL := 0.25

@export var hand:Hand

var stats:Stats
var modifier_manager:ModifierManager
var turn_event_manager:TurnEventManager

func _ready() -> void:
	add_to_group("player_handler")
	Events.card_played.connect(_on_card_played)
	Events.turn_event_resolved.connect(_on_turn_event_resolved)

	modifier_manager = ModifierManager.new()
	add_child(modifier_manager)

	turn_event_manager = TurnEventManager.new()
	add_child(turn_event_manager)

func start_game(new_stats:Stats) -> void:
	stats = new_stats
	stats.draw_pile = stats.deck.duplicate(true)
	stats.draw_pile.shuffle()
	stats.discard_pile = CardPile.new()
	stats.empire.tile_conquered.connect(_on_tile_conquered)
	stats.empire.tile_lost.connect(_on_tile_lost)
	turn_event_manager.stats = stats
	start_turn()

func start_turn() -> void:
	stats.turn_number += 1

	# Tick de modificadores (expira los caducados, resetea contadores)
	modifier_manager.tick()

	# Calcular produccion con modificadores
	var base_gold := 0
	var base_food := 0
	for t in stats.empire.controlled_tiles:
		base_gold += t.gold_production + modifier_manager.get_tile_gold_bonus(t)
		base_food += t.food_production + modifier_manager.get_tile_food_bonus(t)
		t.building_completed.connect(_on_building_completed)
		t.building_demolished.connect(_on_building_demolished)

	# Aplicar modificadores planos
	base_gold += modifier_manager.get_flat_gold()
	base_food += modifier_manager.get_flat_food()

	# Aplicar modificadores porcentuales
	var final_gold := int(base_gold * (1.0 + modifier_manager.get_percent_gold() / 100.0))
	var final_food := int(base_food * (1.0 + modifier_manager.get_percent_food() / 100.0))

	stats.gold_per_turn = final_gold
	stats.food = final_food
	stats.total_gold += stats.gold_per_turn

	# Cartas por turno con bonus de modificadores
	var effective_cards := stats.cards_per_turn + modifier_manager.get_cards_per_turn_bonus()
	effective_cards = clampi(effective_cards, 1, 20)
	draw_cards(effective_cards)

func end_turn() -> void:
	if hand.get_children().size() == 0:
		Events.player_hand_discarded.emit()
	else:
		discard_cards()

## Se conecta a Events.player_hand_discarded desde map.gd
## Evalua si debe ocurrir un evento de turno antes de empezar el siguiente
func evaluate_end_of_turn() -> void:
	var context = EventContext.build(stats, modifier_manager, stats.turn_number)
	var event = turn_event_manager.evaluate(context)

	if event != null:
		Events.turn_event_triggered.emit(event, context)
		# La UI mostrara el evento y emitira turn_event_resolved al resolverse
	else:
		Events.turn_event_resolved.emit()

func _on_turn_event_resolved() -> void:
	start_turn()

func draw_card() -> void:
	reshuffle_deck_from_discard()
	hand.add_card(stats.draw_pile.draw_card())
	reshuffle_deck_from_discard()


func draw_cards(amount:int) -> void:
	var tween := create_tween()
	for i in range(amount):
		tween.tween_callback(draw_card)
		tween.tween_interval(HAND_DRAW_INTERVAL)

	tween.finished.connect(
		func(): Events.player_hand_drawn.emit()
	)

func discard_cards() -> void:
	var tween := create_tween()
	for card_ui in hand.get_children():
		tween.tween_callback(stats.discard_pile.add_card.bind(card_ui.card))
		tween.tween_callback(hand.discard_card.bind(card_ui))
		tween.tween_interval(HAND_DISCARD_INTERVAL)

	tween.finished.connect(
		func(): Events.player_hand_discarded.emit()
	)

func reshuffle_deck_from_discard() -> void:
	if not stats.draw_pile.empty():
		return

	while not stats.discard_pile.empty():
		stats.draw_pile.add_card(stats.discard_pile.draw_card())
	stats.draw_pile.shuffle()

func _on_card_played(card:Card) -> void:
	# Comprobar si algun modificador devuelve la carta a la mano en vez de descartarla
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
