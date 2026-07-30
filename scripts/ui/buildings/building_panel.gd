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


func _ready() -> void:
	if UIState:
		UIState.register_menu()


func set_buildings(value:Array[Building]) -> void:
	if not is_node_ready():
		await ready
	
	_clear_grid()
	# Las tres ramas solo difieren en QUÉ lista se muestra y con qué widget:
	# BUILD y UPGRADE ponen slots con precio (seleccionables si se pueden pagar),
	# SHOW pone tarjetas de lo ya construido (seleccionables si tienen mejora).
	match action:
		possible_action.BUILD:
			buildings = tile.get_valid_buildings(value)
			_populate_priced_slots()
		possible_action.SHOW:
			buildings = tile.buildings
			_populate_built_cards()
		possible_action.UPGRADE:
			buildings = value
			_populate_priced_slots()


## Slots con precio. La asequibilidad la decide el dominio (Building.is_affordable
## usa el coste EFECTIVO: Banca Florentina, eventos de descuento); el panel solo
## elige si conecta la señal y de qué color pinta el precio.
func _populate_priced_slots() -> void:
	for building in buildings:
		var slot:BuildingSlot = BUILDING_SLOT.instantiate()
		slot.stats = stats
		slot.building = building
		buildings_grid.add_child(slot)
		if building.is_affordable(stats):
			slot.building_selected.connect(_on_building_to_build_selected)
		else:
			_mark_slot_unaffordable(slot)
		_slots.append(slot)


func _populate_built_cards() -> void:
	for building in buildings:
		var slot:BuildingCardUI = BUILDING_CARD_UI.instantiate()
		# stats antes que building para que el setter de building
		# muestre el coste efectivo desde la primera asignacion.
		slot.stats = stats
		slot.building = building
		buildings_grid.add_child(slot)
		if not building.upgrades_to.is_empty():
			slot.building_selected.connect(_on_building_to_upgrade_selected)
		_slots.append(slot)


func _clear_grid() -> void:
	UILayout.clear_children(buildings_grid)
	_slots.clear()


## Marca visualmente un BuildingSlot como no construible: el precio se
## pinta en rojo oscuro y no se conecta su señal building_selected.
##
## El PriceLabel de la scene BuildingSlot usa `theme_override_colors`,
## no un `LabelSettings`, asi que `price_label.label_settings` es null.
## Modificar el override mediante `add_theme_color_override` es la API
## correcta y evita el crash "null instance" al asignar font_color.
func _mark_slot_unaffordable(slot:BuildingSlot) -> void:
	if slot.price_label == null:
		return
	UITheme.mark_unaffordable(slot.price_label)

func _on_building_to_build_selected(building: Building) -> void:
	card_confirmed.emit(building)

func _on_building_to_upgrade_selected(building:Building) -> void:
	building_to_upgrade_selected.emit(building)
	action = possible_action.UPGRADE
	buildings = tile.get_valid_upgrades(building)


func _exit_tree() -> void:
	if UIState:
		UIState.unregister_menu()
