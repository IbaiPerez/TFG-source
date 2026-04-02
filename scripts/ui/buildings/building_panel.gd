extends PanelContainer
class_name BuildingPanel

const BUILDING_SLOT = preload("uid://bwtpiltujdlf7")
const BUILDING_CARD_UI = preload("uid://bxjlofssmvuwu")

@onready var buildings_grid: GridContainer = $MarginContainer/VBoxContainer/ScrollContainer/BuildingsGrid

var tile:Tile
var stats:Stats
var buildings:Array[Building]:set = set_buildings
var _slots: Array = []
enum possible_action{BUILD,UPGRADE,SHOW}
var action:possible_action = possible_action.SHOW

signal card_confirmed(building:Building)
signal building_to_upgrade_selected(building:Building)


func set_buildings(value:Array[Building]) -> void:
	if not is_node_ready():
		await ready
	
	_clear_grid()
	match action:
		possible_action.BUILD:
			buildings = tile.get_valid_buildings(value)
			
			for building in buildings:
				var slot:BuildingSlot = BUILDING_SLOT.instantiate()
				slot.building = building
				buildings_grid.add_child(slot)
				if stats.total_gold < building.construction_cost:
					slot.price_label.label_settings.font_color = Color.DARK_RED
				else:
					slot.building_selected.connect(_on_building_to_build_selected)
				_slots.append(slot)
		possible_action.SHOW:
			buildings = tile.buildings
			
			for building in buildings:
				var slot:BuildingCardUI = BUILDING_CARD_UI.instantiate()
				slot.building = building
				buildings_grid.add_child(slot)
				if not building.upgrades_to.is_empty():
					slot.building_selected.connect(_on_building_to_upgrade_selected)
				_slots.append(slot)
		possible_action.UPGRADE:
			buildings = value
			
			for building in buildings:
				var slot:BuildingSlot = BUILDING_SLOT.instantiate()
				slot.building = building
				buildings_grid.add_child(slot)
				if stats.total_gold < building.construction_cost:
					slot.price_label.label_settings.font_color = Color.DARK_RED
				else:
					slot.building_selected.connect(_on_building_to_build_selected)
				_slots.append(slot)


func _clear_grid() -> void:
	for child in buildings_grid.get_children():
		child.queue_free()
	_slots.clear()

func _on_building_to_build_selected(building: Building) -> void:
	card_confirmed.emit(building)

func _on_building_to_upgrade_selected(building:Building) -> void:
	building_to_upgrade_selected.emit(building)
	action = possible_action.UPGRADE
	buildings = tile.get_valid_upgrades(building)
