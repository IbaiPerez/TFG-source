extends PanelContainer
class_name TilePanel

## Panel INFORMATIVO de una casilla: se muestra junto al mapa sin bloquear nada.
##
## Por eso, a diferencia del resto de paneles, NO se registra en [UIState]: ese
## contador solo cuenta menús modales, y son los que bloquean el clic en el mapa
## (interaction.gd) y el zoom de cámara (camera_3d.gd). Con el panel de casilla
## abierto el jugador debe poder seguir seleccionando casillas y moviendo la
## cámara, así que registrarlo rompería la interacción normal. La ausencia de
## `register_menu` aquí es deliberada, no un olvido.

const BUILDING_CARD_UI = preload("uid://bxjlofssmvuwu")

@onready var province_name_label: Label = $MarginContainer/VBoxContainer/ProvinceNameLabel
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


func _ready() -> void:
	pass


func setup(value:Tile) -> void:
	tile = value
	province_name_label.text = tile.province_name
	# mesh_data es la fuente del bioma (`tile.biome` es su nombre de enum ya resuelto);
	# se guarda el null porque otras rutas del código lo tratan como opcional.
	biome_label.text = tr(Tile.biome_key(tile.mesh_data.type)) if tile.mesh_data else ""
	
	if tile.natural_resource:
		resource_color_rect.color = tile.natural_resource.color
		resource_image.texture = tile.natural_resource.image
		resource_name_label.text = tile.natural_resource.name
	else:
		resource_color_rect.color = Color.TRANSPARENT
		resource_image.texture = null
		resource_name_label.text = tr("TILE_NO_RESOURCE")
	
	if tile.controller:
		controller_color_rect.color = tile.controller.color
		controller_label.text = tile.controller.name
	else:
		controller_color_rect.color = Color.TRANSPARENT
		controller_label.text = tr("TILE_NO_CONTROLLER")
	
	UITheme.apply_signed(gold_produced, tile.gold_production, true)
	UITheme.apply_signed(food_produced, tile.food_production, true)
	
	location_label.text = tr(Tile.location_key(tile.location.type))
	
	_setup_buildings()


func _setup_buildings() -> void:

	UILayout.clear_children(building_grid)

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
	demolish_confirm_dialog.dialog_text = tr("TILE_DEMOLISH_CONFIRM_NAMED") % tr(building.name)
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
