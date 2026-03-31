extends PanelContainer
class_name TilePanel

const BUILDING_CARD_UI = preload("uid://bxjlofssmvuwu")

@onready var biome_label: Label = $MarginContainer/VBoxContainer/BiomeLabel
@onready var resource_color_rect: ColorRect = $MarginContainer/VBoxContainer/NaturalResourceContainer/ResourceColorRect
@onready var resource_image: TextureRect = $MarginContainer/VBoxContainer/NaturalResourceContainer/ResourceImage
@onready var resource_name_label: Label = $MarginContainer/VBoxContainer/NaturalResourceContainer/ResourceNameLabel
@onready var controller_color_rect: ColorRect = $MarginContainer/VBoxContainer/ControllerContainer/ControllerColorRect
@onready var controller_label: Label = $MarginContainer/VBoxContainer/ControllerContainer/ControllerLabel
@onready var location_label: Label = $MarginContainer/VBoxContainer/LocationLabel
@onready var building_grid: GridContainer = $MarginContainer/VBoxContainer/BuildingGrid
@onready var gold_produced: Label = $MarginContainer/VBoxContainer/ProductionContainer/GridContainer/GoldProduced
@onready var food_produced: Label = $MarginContainer/VBoxContainer/ProductionContainer/GridContainer/FoodProduced

var tile:Tile:set = setup

func setup(value:Tile) -> void:
	tile = value
	biome_label.text = tile.biome
	
	if tile.natural_resource:
		resource_color_rect.color = tile.natural_resource.color
		resource_image.texture = tile.natural_resource.image
		resource_name_label.text = tile.natural_resource.name
	else:
		resource_color_rect.color = Color.TRANSPARENT
		resource_image.texture = null
		resource_name_label.text = "Sin recurso"
	
	if tile.controller:
		controller_color_rect.color = tile.controller.color
		controller_label.text = tile.controller.name
	else:
		controller_color_rect.color = Color.TRANSPARENT
		controller_label.text = "No controller"
	
	if tile.gold_production < 0:
		gold_produced.label_settings.font_color = Color.DARK_RED
		gold_produced.text = "-" + str(tile.gold_production)
	elif tile.gold_production == 0:
		gold_produced.label_settings.font_color = Color.BLACK
		gold_produced.text = str(tile.gold_production)
	else:
		gold_produced.label_settings.font_color = Color.DARK_GREEN
		gold_produced.text = "+" + str(tile.gold_production)
	
	if tile.food_production < 0:
		food_produced.label_settings.font_color = Color.DARK_RED
		food_produced.text = "-" + str(tile.food_production)
	elif tile.food_production == 0:
		food_produced.label_settings.font_color = Color.BLACK
		food_produced.text = str(tile.food_production)
	else:
		food_produced.label_settings.font_color = Color.DARK_GREEN
		food_produced.text = "+" + str(tile.food_production)
	
	location_label.text = Tile.location_type.find_key(tile.location.type)
	
	_setup_buildings()


func _setup_buildings() -> void:
	
	for child in building_grid.get_children():
		child.queue_free()
	
	var slots:int = tile.max_buildings
	
	for i in range(slots):
		var card:BuildingCardUI = BUILDING_CARD_UI.instantiate()
		building_grid.add_child(card)
		var building:Building = tile.buildings.get(i) if i < tile.buildings.size() else null
		card.building = building
