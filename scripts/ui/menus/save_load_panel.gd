extends CanvasLayer
class_name SaveLoadPanel

## Panel de gestión de saves. Extiende CanvasLayer para garantizar
## que se renderice sobre todo el contenido del juego y aparezca centrado
## independientemente de la jerarquía de la escena padre.

signal closed

enum Mode { LOAD_ONLY, FULL }

@export var mode: Mode = Mode.LOAD_ONLY

var _slot_list: ItemList
var _slot_input: LineEdit
var _save_button: Button
var _load_button: Button
var _delete_button: Button
var _close_button: Button


func _ready() -> void:
	layer = 10  # Por encima del menú principal
	_build_ui()
	_refresh_slots()


func _build_ui() -> void:
	UIDialog.add_dim_background(self)
	var vbox := UIDialog.add_centered_panel(self, Vector2(480, 440), 14)

	vbox.add_child(UIDialog.make_title(
		tr("SAVE_TITLE_LOAD") if mode == Mode.LOAD_ONLY else tr("SAVE_TITLE_FULL")))
	vbox.add_child(HSeparator.new())
	vbox.add_child(_make_slot_list())
	# El nombre de la ranura solo se escribe cuando además se puede guardar.
	if mode == Mode.FULL:
		vbox.add_child(_make_slot_name_row())
	vbox.add_child(_make_buttons_row())


func _make_slot_list() -> ItemList:
	_slot_list = ItemList.new()
	_slot_list.custom_minimum_size = Vector2(420, 240)
	UIDialog.apply_item_list_theme(_slot_list, 16)
	_slot_list.item_selected.connect(_on_slot_selected)
	_slot_list.item_activated.connect(_on_slot_activated)
	return _slot_list


func _make_slot_name_row() -> HBoxContainer:
	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 8)

	var lbl := Label.new()
	lbl.text = tr("SAVE_SLOT_LABEL")
	lbl.add_theme_color_override("font_color", UITheme.TEXT_DARK)
	input_row.add_child(lbl)

	_slot_input = LineEdit.new()
	_slot_input.placeholder_text = tr("SAVE_SLOT_PLACEHOLDER")
	_slot_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_row.add_child(_slot_input)
	return input_row


func _make_buttons_row() -> HBoxContainer:
	var buttons_row := HBoxContainer.new()
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_row.add_theme_constant_override("separation", 8)

	if mode == Mode.FULL:
		_save_button = UIDialog.make_button(tr("UI_SAVE"), _on_save_pressed, 100)
		buttons_row.add_child(_save_button)

	_load_button = UIDialog.make_button(tr("UI_LOAD"), _on_load_pressed, 100)
	buttons_row.add_child(_load_button)

	_delete_button = UIDialog.make_button(tr("UI_DELETE"), _on_delete_pressed, 100)
	buttons_row.add_child(_delete_button)

	_close_button = UIDialog.make_button(tr("UI_CLOSE"), _on_close_pressed, 100)
	buttons_row.add_child(_close_button)
	return buttons_row


func _refresh_slots() -> void:
	_slot_list.clear()
	for slot in GameSaveManager.list_slots():
		_slot_list.add_item(slot)


func _selected_slot_name() -> String:
	var sel := _slot_list.get_selected_items()
	if sel.is_empty():
		return ""
	return _slot_list.get_item_text(sel[0])


func _on_slot_selected(idx: int) -> void:
	if mode == Mode.FULL and _slot_input != null:
		_slot_input.text = _slot_list.get_item_text(idx)


func _on_slot_activated(_idx: int) -> void:
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
