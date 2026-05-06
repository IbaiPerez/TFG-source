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
@onready var demolish_confirm_dialog: ConfirmationDialog = $DemolishConfirmDialog

## Necesario para llamar a Tile.demolish y para comprobar que la
## casilla pertenece al imperio del jugador antes de mostrar el botón.
var stats:Stats

## Edificio pendiente de confirmación en el ConfirmationDialog.
var _building_to_demolish:Building = null

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
		food_produced.text = str(tile.food_production)
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
	var can_demolish:bool = _player_controls_tile()

	for i in range(slots):
		var card:BuildingCardUI = BUILDING_CARD_UI.instantiate()
		building_grid.add_child(card)
		var building:Building = tile.buildings.get(i) if i < tile.buildings.size() else null
		card.allow_demolish = can_demolish
		card.building = building
		card.demolish_requested.connect(_on_demolish_requested)


func _player_controls_tile() -> bool:
	if tile == null or stats == null:
		return false
	return tile.controller != null and tile.controller == stats.empire


func _on_demolish_requested(building:Building) -> void:
	if not _player_controls_tile():
		return
	if building == null:
		return
	_building_to_demolish = building
	if demolish_confirm_dialog == null:
		# Sin diálogo (test/escena alternativa): demoler directamente
		_perform_demolish()
		return
	demolish_confirm_dialog.dialog_text = "¿Demoler %s? Esta acción no se puede deshacer." % building.name
	demolish_confirm_dialog.popup_centered()


func _on_demolish_confirmed() -> void:
	_perform_demolish()


func _on_demolish_canceled() -> void:
	_building_to_demolish = null


func _perform_demolish() -> void:
	if _building_to_demolish == null:
		return
	if tile == null or stats == null:
		_building_to_demolish = null
		return
	tile.demolish(_building_to_demolish, stats)
	_building_to_demolish = null
	# Refrescar la UI tras la demolición (recalcula labels y libera el slot)
	setup(tile)
