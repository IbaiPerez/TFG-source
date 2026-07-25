extends Control
class_name EventCardSelectionPanel

## Panel de selección de carta para eventos de turno.
## Muestra las cartas candidatas y permite elegir una.
## Emite señales globales para comunicarse con TurnEventPanel.

@onready var title: Label = %Title
@onready var cards_container: GridContainer = %CardsContainer
@onready var back_button: Button = %BackButton
@onready var card_tooltip_popup: CardTooltipPopup = %CardTooltipPopup


func _ready() -> void:
	back_button.pressed.connect(_on_cancel)
	title.text = tr("EVTCARD_PROMPT")

	for card:Node in cards_container.get_children():
		card.queue_free()

	card_tooltip_popup.hide_tooltip()

	Events.request_card_selection.connect(_on_request)
	visibility_changed.connect(_on_visibility_changed)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("RightClick") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_cancel()


func _on_request(candidates:Array[Card]) -> void:
	UILayout.clear_children(cards_container)

	for card:Card in candidates:
		CardUIFactory.create(card, cards_container, _on_card_selected)

	show()


func _on_card_selected(card:Card) -> void:
	hide()
	Events.card_selection_made.emit(card)


func _on_cancel() -> void:
	hide()
	Events.card_selection_cancelled.emit()


func _on_visibility_changed() -> void:
	if not UIState:
		return
	if visible:
		UIState.register_menu()
	else:
		UIState.unregister_menu()
