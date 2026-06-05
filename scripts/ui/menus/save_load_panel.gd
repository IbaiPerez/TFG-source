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
	var bg := ColorRect.new()
	bg.color = UITheme.OVERLAY_DARK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 440)
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_style())
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Cargar partida" if mode == Mode.LOAD_ONLY else "Guardar / Cargar"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UITheme.BORDER_BROWN)
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	_slot_list = ItemList.new()
	_slot_list.custom_minimum_size = Vector2(420, 240)
	_apply_item_list_theme(_slot_list)
	_slot_list.item_selected.connect(_on_slot_selected)
	_slot_list.item_activated.connect(_on_slot_activated)
	vbox.add_child(_slot_list)

	if mode == Mode.FULL:
		var input_row := HBoxContainer.new()
		input_row.add_theme_constant_override("separation", 8)
		vbox.add_child(input_row)
		var lbl := Label.new()
		lbl.text = "Slot:"
		lbl.add_theme_color_override("font_color", UITheme.TEXT_DARK)
		input_row.add_child(lbl)
		_slot_input = LineEdit.new()
		_slot_input.placeholder_text = "nombre del slot"
		_slot_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		input_row.add_child(_slot_input)

	var buttons_row := HBoxContainer.new()
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_row.add_theme_constant_override("separation", 8)
	vbox.add_child(buttons_row)

	if mode == Mode.FULL:
		_save_button = _make_button("Guardar", _on_save_pressed)
		buttons_row.add_child(_save_button)

	_load_button = _make_button("Cargar", _on_load_pressed)
	buttons_row.add_child(_load_button)

	_delete_button = _make_button("Borrar", _on_delete_pressed)
	buttons_row.add_child(_delete_button)

	_close_button = _make_button("Cerrar", _on_close_pressed)
	buttons_row.add_child(_close_button)


## Aplica el tema de pergamino al ItemList, incluyendo los estados
## de selección para que el texto sea siempre legible.
func _apply_item_list_theme(list: ItemList) -> void:
	# Fondo general de la lista
	list.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.BORDER_BROWN, 2, 6))

	# Fondo del item seleccionado (sin foco y con foco)
	var sel_style := StyleBoxFlat.new()
	sel_style.bg_color = Color(UITheme.BORDER_BROWN.r, UITheme.BORDER_BROWN.g,
			UITheme.BORDER_BROWN.b, 0.22)
	sel_style.corner_radius_top_left     = 4
	sel_style.corner_radius_top_right    = 4
	sel_style.corner_radius_bottom_right = 4
	sel_style.corner_radius_bottom_left  = 4
	sel_style.content_margin_left   = 6
	sel_style.content_margin_top    = 3
	sel_style.content_margin_right  = 6
	sel_style.content_margin_bottom = 3
	list.add_theme_stylebox_override("selected", sel_style)
	list.add_theme_stylebox_override("selected_focus", sel_style)

	# Sin borde de cursor por defecto (evita el rectángulo blanco de foco)
	var empty := StyleBoxEmpty.new()
	list.add_theme_stylebox_override("cursor", empty)
	list.add_theme_stylebox_override("cursor_unfocused", empty)

	# Colores de texto: siempre oscuros, tanto en normal como en seleccionado
	list.add_theme_color_override("font_color", UITheme.TEXT_DARK)
	list.add_theme_color_override("font_selected_color", UITheme.BORDER_BROWN)
	list.add_theme_color_override("font_hovered_color", UITheme.BORDER_BROWN)

	# Tamaño de fuente consistente con el panel
	list.add_theme_font_size_override("font_size", 16)


func _make_button(label_text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(100, 38)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", UITheme.TEXT_DARK)
	btn.add_theme_color_override("font_hover_color", UITheme.BORDER_BROWN)
	btn.add_theme_color_override("font_pressed_color", UITheme.BORDER_BROWN)
	btn.add_theme_stylebox_override("normal", UITheme.make_panel_style(UITheme.BORDER_BROWN, 2, 8))
	btn.add_theme_stylebox_override("hover", UITheme.make_panel_hover_style(UITheme.BORDER_BROWN, 2, 8))
	btn.add_theme_stylebox_override("pressed", UITheme.make_panel_style(UITheme.BORDER_BROWN, 3, 8))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pressed.connect(callback)
	return btn


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
