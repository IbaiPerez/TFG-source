extends EmpireController
class_name PlayerHandler

const HAND_DRAW_INTERVAL := 0.25
const HAND_DISCARD_INTERVAL := 0.25

@export var hand:Hand

var _awaiting_event_resolution := false

func _ready() -> void:
	add_to_group("player_handler")
	Events.card_played.connect(_on_card_played)
	Events.card_returned_to_hand.connect(_on_card_returned_to_hand)
	Events.turn_event_resolved.connect(_on_turn_event_resolved)
	Events.shop_event_resolved.connect(_on_turn_event_resolved)
	_init_managers()

func start_game(new_stats:Stats) -> void:
	super.start_game(new_stats)
	# El TurnManager se encarga de llamar a start_turn()

func start_turn() -> void:
	_process_turn_start()
	var effective_cards := _get_effective_cards_per_turn()
	draw_cards_animated(effective_cards)

func end_turn() -> void:
	if hand.get_children().size() == 0:
		Events.player_hand_discarded.emit()
	else:
		_discard_cards_animated()

## Se conecta a Events.player_hand_discarded desde map.gd
## Evalua si debe ocurrir un evento de turno antes de empezar el siguiente
func evaluate_end_of_turn() -> void:
	var has_event := _evaluate_end_of_turn()
	if has_event:
		_awaiting_event_resolution = true
	else:
		turn_finished.emit(self)

func _on_turn_event_resolved() -> void:
	if not _awaiting_event_resolution:
		return
	_awaiting_event_resolution = false
	turn_finished.emit(self)

func _on_card_played(card:Card) -> void:
	_handle_card_played(card)

func _on_card_returned_to_hand(card:Card) -> void:
	hand.add_card(card)

## --- Animaciones de mano (exclusivas del jugador) ---

func draw_cards_animated(amount:int) -> void:
	var tween := create_tween()
	for i in range(amount):
		tween.tween_callback(_draw_card_to_hand)
		tween.tween_interval(HAND_DRAW_INTERVAL)

	tween.finished.connect(
		func(): Events.player_hand_drawn.emit()
	)

func _draw_card_to_hand() -> void:
	var card := _draw_single_card()
	hand.add_card(card)

func _discard_cards_animated() -> void:
	var tween := create_tween()
	for card_ui in hand.get_children():
		tween.tween_callback(stats.discard_pile.add_card.bind(card_ui.card))
		tween.tween_callback(hand.discard_card.bind(card_ui))
		tween.tween_interval(HAND_DISCARD_INTERVAL)

	tween.finished.connect(
		func(): Events.player_hand_discarded.emit()
	)
