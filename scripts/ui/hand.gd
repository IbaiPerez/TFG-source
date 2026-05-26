extends HBoxContainer
class_name Hand

@export var stats:Stats
@onready var card_ui = preload("uid://cf5a8tg1tqyy7")

var cards_played_this_turn := 0

## Mientras es false, las cartas de la mano ignoran clicks y hovers. Lo
## activa/desactiva el PlayerHandler durante la animacion de robo (asi el
## jugador no puede agarrar cartas a medio reparto, lo que provocaba que
## se reparase mal el conteo de cartas en mano).
var _interactive:bool = true

func _ready() -> void:
	Events.card_played.connect(_on_card_played)

func add_card(card:Card) -> void:
	var new_card_ui := card_ui.instantiate()
	add_child(new_card_ui)
	new_card_ui.reparent_requested.connect(_on_card_ui_reparent_requested)
	new_card_ui.card = card
	new_card_ui.parent = self
	new_card_ui.stats = stats
	# Cualquier carta añadida durante una fase no interactiva (p.ej. en
	# medio de la animacion de robo) hereda el estado de la mano. Asi el
	# jugador no puede hacer click sobre una carta recien repartida hasta
	# que termina la animacion.
	_apply_interactive(new_card_ui)

func discard_card(card:CardUI) -> void:
	card.queue_free()

## Activa o desactiva las interacciones de raton sobre todas las cartas
## de la mano (clicks, hovers, drag). Las animaciones (movimiento, tween)
## siguen funcionando porque solo tocamos `mouse_filter`, no `process_mode`.
##
## El flujo de arrastrar una carta comienza en `CardBaseState.on_gui_input`
## al detectar el press de Click; con `MOUSE_FILTER_IGNORE` el `gui_input`
## ni siquiera se entrega al CardUI, asi que el state machine no transita
## a CLICKED y la carta no puede salir de la mano.
func set_interactive(enabled:bool) -> void:
	_interactive = enabled
	for child in get_children():
		if child is CardUI:
			_apply_interactive(child)


func _apply_interactive(cui:CardUI) -> void:
	cui.mouse_filter = Control.MOUSE_FILTER_STOP if _interactive else Control.MOUSE_FILTER_IGNORE

func _on_card_played(_card:Card, owner_stats:Stats) -> void:
	# Solo contar cartas del jugador (la mano UI no representa a la IA).
	if owner_stats != stats:
		return
	cards_played_this_turn += 1

func _on_card_ui_reparent_requested(child:CardUI) -> void:
	child.reparent(self)
