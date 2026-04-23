extends Control
class_name RecoverCardPanel

## Panel de seleccion para la carta Recover.
## Muestra las cartas de la played_pile y permite elegir una para
## devolverla a la mano. Emite card_confirmed con la carta elegida.

const CARD_MENU_UI = preload("uid://bt76i1liwhags")

signal card_confirmed(card:Card)

@export var card_pile:CardPile

@onready var title: Label = %Title
@onready var cards_container: GridContainer = %CardsContainer
@onready var back_button: Button = %BackButton
@onready var card_tooltip_popup: CardTooltipPopup = %CardTooltipPopup


func _ready() -> void:
	back_button.pressed.connect(_on_cancel)
	title.text = "Select a card to recover"

	for card:Node in cards_container.get_children():
		card.queue_free()

	card_tooltip_popup.hide_tooltip()
	_populate.call_deferred()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("RightClick") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_cancel()


func _populate() -> void:
	if not card_pile:
		return
	for card:Card in card_pile.cards:
		var card_ui := CARD_MENU_UI.instantiate() as CardMenuUi
		cards_container.add_child(card_ui)
		card_ui.card = card
		card_ui.tooltip_requested.connect(_on_card_selected)

	show()


func _on_card_selected(card:Card) -> void:
	card_confirmed.emit(card)


func _on_cancel() -> void:
	card_confirmed.emit(null)
