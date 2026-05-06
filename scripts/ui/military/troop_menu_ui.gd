extends CenterContainer
class_name TroopMenuUi

## Slot visual de tropa para el TroopPoolView.
## Equivalente a CardMenuUi pero adaptado a Troop: muestra icono, nombre,
## stats atk/def y un contador con la cantidad agrupada de ese tipo.

const CARD_BASE_STYLE = preload("uid://di80gk8nibent")
const CARD_HOVER_STYLE = preload("uid://b52h7lujm1wex")

@export var troop:Troop:set = set_troop
@export var count:int = 1:set = set_count

@onready var panel: Panel = $Visuals/Panel
@onready var icon: TextureRect = $Visuals/Icon
@onready var name_label: Label = $Visuals/Info/Name
@onready var stats_label: Label = $Visuals/Info/Stats
@onready var count_label: Label = $Visuals/CountLabel


func set_troop(value:Troop) -> void:
	if not is_node_ready():
		await ready

	troop = value
	if troop == null:
		return
	icon.texture = troop.icon
	name_label.text = troop.name
	stats_label.text = "Atk %d   Def %d" % [troop.attack, troop.defense]


func set_count(value:int) -> void:
	count = value
	if not is_node_ready():
		await ready
	count_label.text = "x%d" % count
	count_label.visible = count > 1


func _on_visuals_mouse_entered() -> void:
	panel.set("theme_override_styles/panel", CARD_HOVER_STYLE)


func _on_visuals_mouse_exited() -> void:
	panel.set("theme_override_styles/panel", CARD_BASE_STYLE)
