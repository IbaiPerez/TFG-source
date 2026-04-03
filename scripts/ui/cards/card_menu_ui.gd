extends CenterContainer
class_name CardMenuUi

const CARD_BASE_STYLE = preload("uid://di80gk8nibent")
const CARD_HOVER_STYLE = preload("uid://b52h7lujm1wex")

signal tooltip_requested(card:Card)

@export var card:Card:set = set_card

@onready var panel: Panel = $Visuals/Panel
@onready var icon: TextureRect = $Visuals/Icon

func set_card(value:Card) -> void:
	if not is_node_ready():
		await ready
	
	card = value
	icon.texture = value.icon

func _on_visuals_mouse_entered() -> void:
	panel.set("theme_override_styles/panel", CARD_HOVER_STYLE)

func _on_visuals_mouse_exited() -> void:
	panel.set("theme_override_styles/panel", CARD_BASE_STYLE)

func _on_visuals_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("Click"):
		tooltip_requested.emit(card)
