extends VBoxContainer
class_name BuildingSlot

signal building_selected(building:Building)

@onready var building_card_ui: BuildingCardUI = $BuildingCardUI
@onready var price_label: Label = $HBoxContainer/PriceLabel

@export var building:Building:set = _set_building


func _set_building(value:Building):
	if not is_node_ready():
		await ready
	
	building = value
	building_card_ui.building = value
	price_label.text = str(value.construction_cost)


func _on_building_card_ui_gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		if event.is_action_pressed("Click"):
			building_selected.emit(building)
