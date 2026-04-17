extends MarginContainer
class_name BuildingCardUI

@onready var building_image: TextureRect = $PanelContainer/BuildingImage
@onready var building_tooltip: PanelContainer = $BuildingTooltip
@onready var name_label: Label = $BuildingTooltip/MarginContainer/VBoxContainer/NameLabel
@onready var cost_value_label: Label = $BuildingTooltip/MarginContainer/VBoxContainer/GridContainer/CostValueLabel
@onready var gold_production_label: Label = $BuildingTooltip/MarginContainer/VBoxContainer/GridContainer/GoldProductionLabel
@onready var food_production_label: Label = $BuildingTooltip/MarginContainer/VBoxContainer/GridContainer/FoodProductionLabel
@onready var label_6: Label = $BuildingTooltip/MarginContainer/VBoxContainer/GridContainer/Label6
@onready var allowed_locations_label: Label = $BuildingTooltip/MarginContainer/VBoxContainer/GridContainer/AllowedLocationsLabel
@onready var label_7: Label = $BuildingTooltip/MarginContainer/VBoxContainer/GridContainer/Label7
@onready var allowed_biomes_label: Label = $BuildingTooltip/MarginContainer/VBoxContainer/GridContainer/AllowedBiomesLabel
@onready var effects_separator: HSeparator = $BuildingTooltip/MarginContainer/VBoxContainer/EffectsSeparator
@onready var effects_container: VBoxContainer = $BuildingTooltip/MarginContainer/VBoxContainer/EffectsContainer

@export var building:Building:set = _set_building

signal building_selected(building:Building)

func _set_building(value:Building) -> void:
	if not is_node_ready():
		await ready
	
	building = value

	if not building:
		return
	
	building_image.texture = value.image
	name_label.text = value.name
	cost_value_label.text = str(value.construction_cost)
	gold_production_label.text = str(value.gold_produced)
	food_production_label.text = str(value.food_produced)
	if not building.allowed_location_type.is_empty():
		label_6.visible = true
		allowed_locations_label.visible = true
		for location in building.allowed_location_type:
			allowed_locations_label.text = ", ".join(
		building.allowed_location_type.map(func(l): return Tile.location_type.keys()[l.type]))
	else:
		label_6.visible = false
		allowed_locations_label.visible = false
	if not building.allowed_biomes.is_empty():
		label_7.visible = true
		allowed_biomes_label.visible = true
		for location in building.allowed_biomes:
			allowed_biomes_label.text = ", ".join(
		building.allowed_biomes.map(func(b): return Tile.biome_type.keys()[b]))
	else:
		label_7.visible = false
		allowed_biomes_label.visible = false
	
	_populate_effects(value.effects)

func _populate_effects(effects:Array[BuildingEffect]) -> void:
	for child in effects_container.get_children():
		child.queue_free()
	
	if effects.is_empty():
		effects_separator.visible = false
		return
	
	effects_separator.visible = true
	for effect in effects:
		var rtl := RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.scroll_active = false
		rtl.custom_minimum_size = Vector2(200, 0)
		rtl.text = effect.tooltipe_text
		effects_container.add_child(rtl)


func _on_mouse_entered() -> void:
	if not building:
		return
	building_tooltip.visible = true
	_update_tooltip_position()


func _on_mouse_exited() -> void:
	if not building:
		return
	building_tooltip.visible = false

func _update_tooltip_position() -> void:
	var vp_size := get_viewport_rect().size
	var tooltip_size := building_tooltip.size
	var global := global_position
	var card_size := size

	var x := global.x + card_size.x + 6
	if x + tooltip_size.x > vp_size.x:
		x = global.x - tooltip_size.x - 6

	var y := global.y
	if y + tooltip_size.y > vp_size.y:
		y = vp_size.y - tooltip_size.y

	building_tooltip.global_position = Vector2(x, y)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		if event.is_action_pressed("Click"):
			building_selected.emit(building)
