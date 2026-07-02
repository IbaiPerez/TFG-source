extends Control

## Pantalla de seleccion de imperio (maestro-detalle).
## Izquierda: lista de imperios (nombre + borde de su color, en un ButtonGroup).
## Derecha: RichTextLabel con el desglose de modificadores coloreado, generado
## a partir de los modifiers reales de la habilidad (ver EmpireModifierFormatter).

const BABYLONIAN = preload("uid://dlljlcjgbqsv5")
const MONGOL = preload("uid://b4mhfidkmt6ag")
const MEDICI = preload("uid://ba6dn1gfrs32d")

@onready var _empire_list: VBoxContainer = %EmpireList
@onready var _detail_text: RichTextLabel = %DetailText
@onready var _select_button: Button = %SelectButton
@onready var _back_button: Button = $Margin/Root/Header/BackButton

var empires: Array[Empire] = []
var _item_buttons: Array[Button] = []
var _selected_empire: Empire = null


func _ready() -> void:
	empires = [MONGOL, MEDICI, BABYLONIAN]
	_build_list()
	if not empires.is_empty():
		_select(0)


func _build_list() -> void:
	var group := ButtonGroup.new()
	_item_buttons.clear()
	for i in empires.size():
		var btn := _make_list_item(empires[i], group)
		_empire_list.add_child(btn)
		_item_buttons.append(btn)
		btn.pressed.connect(_select.bind(i))
	_setup_focus_chain()


func _make_list_item(empire: Empire, group: ButtonGroup) -> Button:
	var btn := Button.new()
	btn.text = empire.name  # clave de localizacion (auto-traducida por el nodo)
	btn.toggle_mode = true
	btn.button_group = group
	btn.custom_minimum_size = Vector2(0, 56)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_stylebox_override("normal", _make_item_style(empire.color, false))
	btn.add_theme_stylebox_override("hover", _make_item_style(empire.color, false, true))
	btn.add_theme_stylebox_override("pressed", _make_item_style(empire.color, true))
	btn.add_theme_stylebox_override("focus", _make_item_style(empire.color, true))
	return btn


func _make_item_style(empire_color: Color, selected: bool, hover: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	if selected:
		s.bg_color = Color(empire_color.r, empire_color.g, empire_color.b, 0.22)
	elif hover:
		s.bg_color = UITheme.PARCHMENT_HOVER
	else:
		s.bg_color = UITheme.PARCHMENT
	s.border_color = empire_color
	# Borde grueso a la izquierda (acento de color) y fino en el resto.
	s.border_width_left = 6
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.corner_radius_top_left = 8
	s.corner_radius_top_right = 8
	s.corner_radius_bottom_right = 8
	s.corner_radius_bottom_left = 8
	s.content_margin_left = 14.0
	s.content_margin_right = 14.0
	s.content_margin_top = 8.0
	s.content_margin_bottom = 8.0
	return s


## Selecciona el imperio en `index`: marca su boton, actualiza el panel de
## detalle y recuerda la eleccion para el boton "Seleccionar".
func _select(index: int) -> void:
	if index < 0 or index >= empires.size():
		return
	_selected_empire = empires[index]
	if not _item_buttons[index].button_pressed:
		_item_buttons[index].button_pressed = true
	_detail_text.text = _build_detail_bbcode(_selected_empire)
	_detail_text.scroll_to_line(0)


func _build_detail_bbcode(empire: Empire) -> String:
	var accent := _hex(empire.color.darkened(0.25))
	var parts: Array[String] = []

	parts.append("[center][font_size=30][color=%s][b]%s[/b][/color][/font_size][/center]"
		% [accent, tr(empire.name)])

	if empire.ability:
		parts.append("[center][font_size=20][color=%s]%s[/color][/font_size][/center]"
			% [accent, tr(empire.ability.ability_name)])

		var mod_lines := EmpireModifierFormatter.describe_ability(empire.ability)
		if not mod_lines.is_empty():
			var bullets := ""
			for line in mod_lines:
				bullets += "[color=%s]•[/color]  %s\n" % [accent, line]
			parts.append("[font_size=16]%s[/font_size]" % bullets)

		if not empire.ability.description.is_empty():
			parts.append("[color=%s][i]%s[/i][/color]"
				% [_hex(UITheme.TEXT_MUTED), tr(empire.ability.description)])

	return "\n\n".join(parts)


func _setup_focus_chain() -> void:
	if _item_buttons.is_empty():
		return
	for i in _item_buttons.size():
		var b := _item_buttons[i]
		if i > 0:
			b.focus_neighbor_top = b.get_path_to(_item_buttons[i - 1])
		else:
			b.focus_neighbor_top = b.get_path_to(_back_button)
		if i < _item_buttons.size() - 1:
			b.focus_neighbor_bottom = b.get_path_to(_item_buttons[i + 1])
		else:
			b.focus_neighbor_bottom = b.get_path_to(_select_button)
		b.focus_neighbor_right = b.get_path_to(_select_button)
	_back_button.focus_neighbor_bottom = _back_button.get_path_to(_item_buttons[0])
	_select_button.focus_neighbor_left = _select_button.get_path_to(_item_buttons[0])
	_item_buttons[0].grab_focus()


func _hex(c: Color) -> String:
	return "#" + c.to_html(false)


func _on_select_button_pressed() -> void:
	if _selected_empire:
		Events.navigate_to_generation.emit(_selected_empire)


func _on_back_button_pressed() -> void:
	Events.navigate_to_main_menu.emit()
