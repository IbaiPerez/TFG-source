extends PanelContainer
class_name BuildingPanel

const BUILDING_SLOT = preload("uid://bwtpiltujdlf7")

@onready var buildings_grid: GridContainer = $MarginContainer/VBoxContainer/ScrollContainer/BuildingsGrid

var tile:Tile
var stats:Stats
var buildings:Array[Building]:set = set_buildings
var _slots: Array = []


func set_buildings(value:Array[Building]) -> void:
	buildings = value
	
	_clear_grid()
	for building in buildings:
		var slot:BuildingSlot = BUILDING_SLOT.instantiate()
		slot.building = building
		buildings_grid.add_child(slot)
		if stats.total_gold < building.construction_cost:
			slot.price_label.label_settings.font_color = Color.DARK_RED
		else:
			slot.building_selected.connect(_on_building_selected)
		_slots.append(slot)

func _clear_grid() -> void:
	for child in buildings_grid.get_children():
		child.queue_free()
	_slots.clear()

func _on_building_selected(building: Building) -> void:
	tile.build(building,stats)
	self.visible = false
