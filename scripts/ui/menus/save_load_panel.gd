extends Control
class_name SaveLoadPanel

## Panel sencillo de gestión de saves. Pensado como herramienta de testing
## (objetivo principal del sistema de saves en Source: cargar estados de
## partida sin tener que jugarlas enteras).
##
## Se puede invocar tanto desde el menú principal (modo "load only") como
## en partida (modo completo: save + load + delete).

signal closed

enum Mode { LOAD_ONLY, FULL }

@export var mode:Mode = Mode.LOAD_ONLY

var _slot_list:ItemList
var _slot_input:LineEdit
var _save_button:Button
var _load_button:Button
var _delete_button:Button
var _close_button:Button


func _ready() -> void:
	_build_ui()
	_refresh_slots()


func _build_ui() -> void:
	anchors_preset = Control.PRESET_FULL_RECT

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 380)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Cargar partida" if mode == Mode.LOAD_ONLY else "Guardar / Cargar"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	_slot_list = ItemList.new()
	_slot_list.custom_minimum_size = Vector2(380, 200)
	_slot_list.item_selected.connect(_on_slot_selected)
	_slot_list.item_activated.connect(_on_slot_activated)
	vbox.add_child(_slot_list)

	if mode == Mode.FULL:
		var input_row := HBoxContainer.new()
		vbox.add_child(input_row)
		var label := Label.new()
		label.text = "Slot:"
		input_row.add_child(label)
		_slot_input = LineEdit.new()
		_slot_input.placeholder_text = "nombre del slot"
		_slot_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		input_row.add_child(_slot_input)

	var buttons_row := HBoxContainer.new()
	buttons_row.add_theme_constant_override("separation", 8)
	vbox.add_child(buttons_row)

	if mode == Mode.FULL:
		_save_button = Button.new()
		_save_button.text = "Guardar"
		_save_button.pressed.connect(_on_save_pressed)
		buttons_row.add_child(_save_button)

	_load_button = Button.new()
	_load_button.text = "Cargar"
	_load_button.pressed.connect(_on_load_pressed)
	buttons_row.add_child(_load_button)

	_delete_button = Button.new()
	_delete_button.text = "Borrar"
	_delete_button.pressed.connect(_on_delete_pressed)
	buttons_row.add_child(_delete_button)

	_close_button = Button.new()
	_close_button.text = "Cerrar"
	_close_button.pressed.connect(_on_close_pressed)
	buttons_row.add_child(_close_button)


func _refresh_slots() -> void:
	_slot_list.clear()
	for slot in GameSaveManager.list_slots():
		_slot_list.add_item(slot)


func _selected_slot_name() -> String:
	var sel := _slot_list.get_selected_items()
	if sel.is_empty():
		return ""
	return _slot_list.get_item_text(sel[0])


func _on_slot_selected(idx:int) -> void:
	if mode == Mode.FULL and _slot_input != null:
		_slot_input.text = _slot_list.get_item_text(idx)


func _on_slot_activated(_idx:int) -> void:
	# Doble click sobre un slot = cargar.
	_on_load_pressed()


func _on_save_pressed() -> void:
	if _slot_input == null:
		return
	var slot_name := _slot_input.text.strip_edges()
	if slot_name.is_empty():
		GameLogger.warn("[SaveLoadPanel] Nombre de slot vacío")
		return
	if GameSaveManager.save_current_game(slot_name):
		_refresh_slots()


func _on_load_pressed() -> void:
	var slot_name := _selected_slot_name()
	if slot_name.is_empty():
		GameLogger.warn("[SaveLoadPanel] Ningún slot seleccionado")
		return
	if GameSaveManager.load_game(slot_name):
		queue_free()


func _on_delete_pressed() -> void:
	var slot_name := _selected_slot_name()
	if slot_name.is_empty():
		return
	GameSaveManager.delete_slot(slot_name)
	_refresh_slots()


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()
