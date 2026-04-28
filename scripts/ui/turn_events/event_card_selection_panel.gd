extends Control
class_name EventCardSelectionPanel

## Panel de selección de carta para eventos de turno.
## Muestra las cartas candidatas y permite elegir una.
## Emite señales globales para comunicarse con TurnEventPanel.

const CARD_MENU_UI = preload("uid://bt76i1liwhags")

@onready var title: Label = %Title
@onready var cards_container: GridContainer = %CardsContainer
@onready var back_button: Button = %BackButton
@onready var card_tooltip_popup: CardTooltipPopup = %CardTooltipPopup


func _ready() -> void:
	back_button.pressed.connect(_on_cancel)
	title.text = "Elige una carta para eliminar"

	for card:Node in cards_container.get_children():
		card.queue_free()

	card_tooltip_popup.hide_tooltip()

	Events.request_card_selection.connect(_on_request)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("RightClick") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_cancel()


func _on_request(candidates:Array[Card]) -> void:
	for child in cards_container.get_children():
		child.queue_free()

	for card:Card in candidates:
		var card_ui := CARD_MENU_UI.instantiate() as CardMenuUi
		cards_container.add_child(card_ui)
		card_ui.card = card
		card_ui.tooltip_requested.connect(_on_card_selected)

	show()


func _on_card_selected(card:Card) -> void:
	hide()
	Events.card_selection_made.emit(card)


func _on_cancel() -> void:
	hide()
	Events.card_selection_cancelled.emit()
