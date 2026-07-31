extends CanvasLayer
class_name TutorialPanel

## Navegador del manual del juego: lista de entradas agrupadas por categoría a la
## izquierda y el cuerpo de la seleccionada a la derecha.
##
## El CONTENIDO vive en [TutorialContent]; aquí solo queda la presentación.

var _entries: Array[TutorialEntry] = []
## Índice de la lista visible → índice en `_entries`. No es la identidad: la lista
## intercala cabeceras de categoría, que no son seleccionables y no tienen entrada.
var _index_map: Dictionary = {}
var _entry_list: ItemList
var _content_title: Label
var _content_body: Label


func _ready() -> void:
	layer = 10
	_entries = TutorialContent.new().build()
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()


# ─────────────────────────────────────────────────────────────────────────────
# UI construction
# ─────────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	UIDialog.add_dim_background(self)

	var vbox := UIDialog.add_centered_panel(self, Vector2(820, 540), 10)
	vbox.add_child(UIDialog.make_title(tr("MENU_TUTORIAL")))
	vbox.add_child(HSeparator.new())
	vbox.add_child(_make_browser())
	vbox.add_child(HSeparator.new())
	vbox.add_child(_make_footer())

	_populate_list()
	_select_first_entry()


## Cuerpo del panel: lista de entradas | separador | columna de contenido.
func _make_browser() -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 10)

	_entry_list = ItemList.new()
	_entry_list.custom_minimum_size = Vector2(230, 0)
	_entry_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UIDialog.apply_item_list_theme(_entry_list, 15)
	_entry_list.item_selected.connect(_on_entry_selected)
	hbox.add_child(_entry_list)

	hbox.add_child(VSeparator.new())
	hbox.add_child(_make_content_column())
	return hbox


func _make_content_column() -> VBoxContainer:
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(450, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)

	_content_title = Label.new()
	_content_title.add_theme_font_size_override("font_size", 20)
	_content_title.add_theme_color_override("font_color", UITheme.BORDER_BROWN)
	right.add_child(_content_title)

	right.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)

	_content_body = Label.new()
	_content_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_body.add_theme_font_size_override("font_size", 16)
	_content_body.add_theme_color_override("font_color", UITheme.TEXT_DARK)
	scroll.add_child(_content_body)
	return right


func _make_footer() -> HBoxContainer:
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_child(UIDialog.make_button(tr("UI_CLOSE"), _on_close_pressed, 120))
	return footer


func _populate_list() -> void:
	var current_category := ""
	var entry_idx := 0
	for entry in _entries:
		if entry.category != current_category:
			current_category = entry.category
			_entry_list.add_item("— " + current_category + " —")
			var header_idx := _entry_list.get_item_count() - 1
			_entry_list.set_item_selectable(header_idx, false)
			_entry_list.set_item_custom_fg_color(header_idx, UITheme.BORDER_BROWN)
		_entry_list.add_item("  " + entry.title)
		_index_map[_entry_list.get_item_count() - 1] = entry_idx
		entry_idx += 1


func _select_first_entry() -> void:
	for i: int in range(_entry_list.get_item_count()):
		if _index_map.has(i):
			_entry_list.select(i)
			_on_entry_selected(i)
			return


func _on_entry_selected(list_idx: int) -> void:
	if not _index_map.has(list_idx):
		return
	var entry: TutorialEntry = _entries[_index_map[list_idx]]
	_content_title.text = entry.title
	_content_body.text = entry.body


func _on_close_pressed() -> void:
	queue_free()
