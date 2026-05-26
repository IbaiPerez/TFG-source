extends VBoxContainer
class_name BuildingSlot

signal building_selected(building:Building)

@onready var building_card_ui: BuildingCardUI = $BuildingCardUI
@onready var price_label: Label = $HBoxContainer/PriceLabel

## Stats del imperio que ve este slot. Lo asigna el BuildingPanel padre
## antes de asignar `building`. Si es null (instancias huerfanas en tests
## o slots sin contexto), `price_label` muestra el coste raw del .tres.
@export var stats:Stats:set = _set_stats

@export var building:Building:set = _set_building


func _set_stats(value:Stats) -> void:
	stats = value
	# Propagar a la card hija para que su tooltip tambien muestre el coste
	# efectivo. Si building aun no esta asignado, no hacemos nada — el
	# refresh ocurrira en _set_building.
	if is_node_ready() and building_card_ui != null:
		building_card_ui.stats = stats
	if is_node_ready() and building != null:
		_refresh_price_label()


func _set_building(value:Building):
	if not is_node_ready():
		await ready

	building = value
	building_card_ui.stats = stats
	building_card_ui.building = value
	_refresh_price_label()


func _refresh_price_label() -> void:
	if building == null:
		price_label.text = ""
		return
	# Si tenemos stats con modifier_manager, mostramos el coste efectivo;
	# si no, el coste raw del .tres. Asi el slot se mantiene usable como
	# preview sin un contexto de partida.
	price_label.text = str(building.get_effective_construction_cost(stats))


func _on_building_card_ui_gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		if event.is_action_pressed("Click"):
			building_selected.emit(building)
