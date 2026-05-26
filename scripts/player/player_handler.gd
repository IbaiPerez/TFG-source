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

## Reanuda el turno del jugador despues de cargar un save.
##
## El snapshot ya restauro:
##   - La mano (CardUIs creadas en `_restore_player_hand`).
##   - Las stats con `turn_number`, `gold_per_turn`, `food`, `total_gold`
##     resultado del `_process_turn_start` del turno guardado.
##   - El contador `cards_played_this_turn` de la mano.
##
## Por tanto, NO debemos volver a llamar a `_process_turn_start`
## (incrementaria `turn_number` y duplicaria la produccion) ni a
## `draw_cards_animated` (intentaria robar de un draw_pile que ya pudo
## quedarse vacio tras el robo previo, lo que provocaria null cards).
##
## Solo hace falta reactivar el input del jugador, igual que hace la
## animacion de robo al terminar.
func resume_turn() -> void:
	Events.player_hand_drawn.emit()

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

func _on_card_played(card:Card, owner_stats:Stats) -> void:
	# Solo reaccionar a cartas jugadas por nosotros (filtrar IA).
	if owner_stats != stats:
		return
	_handle_card_played(card)

func _on_card_returned_to_hand(card:Card, owner_stats:Stats) -> void:
	# Solo añadir a la mano del jugador si la carta es nuestra.
	if owner_stats != stats:
		return
	hand.add_card(card)

## --- Animaciones de mano (exclusivas del jugador) ---

func draw_cards_animated(amount:int) -> void:
	# Bloqueamos interaccion con la mano hasta que termine la animacion.
	# Bug previo: si el jugador agarraba una carta mientras aun se estaban
	# repartiendo, el conteo "cartas en mano vs. objetivo" se descuadraba
	# (la carta arrastrada sale temporalmente del HBoxContainer y se
	# repartia una de mas para "compensar"). Con la mano no-interactiva
	# durante el reparto no se puede iniciar el arrastre.
	hand.set_interactive(false)
	var tween := create_tween()
	for i in range(amount):
		tween.tween_callback(_draw_card_to_hand)
		tween.tween_interval(HAND_DRAW_INTERVAL)

	tween.finished.connect(
		func():
			hand.set_interactive(true)
			Events.player_hand_drawn.emit()
	)

func _draw_card_to_hand() -> void:
	var card := _draw_single_card()
	if card == null:
		# Las dos pilas (draw + discard) estan agotadas. Saltamos sin
		# intentar instanciar CardUI con carta null (eso reventaria al
		# acceder a `card.icon` en `CardUI._set_card`).
		return
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
