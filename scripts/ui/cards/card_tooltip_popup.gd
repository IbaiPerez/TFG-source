extends Control
class_name CardTooltipPopup

const CARD_MENU_UI = preload("uid://bt76i1liwhags")
@onready var tooltip_card: CenterContainer = %TooltipCard
@onready var card_description: RichTextLabel = %CardDescription

func _ready() -> void:
	for card:CardMenuUi in tooltip_card.get_children():
		card.queue_free()
	

func show_tooltip(card:Card) -> void:
	var new_card = CARD_MENU_UI.instantiate() as CardMenuUi
	tooltip_card.add_child(new_card)
	new_card.card = card
	new_card.tooltip_requested.connect(hide_tooltip.unbind(1))
	card_description.text = card.get_tooltip()
	show()

func hide_tooltip() -> void:
	if not visible:
		return
	
	for card:CardMenuUi in tooltip_card.get_children():
		card.queue_free()
	
	hide()

func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(
		"Click") or event.is_action_pressed("RightClick"):
		hide_tooltip()
