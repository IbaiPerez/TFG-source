extends Control

const BABYLONIAN = preload("uid://dlljlcjgbqsv5")
const MONGOL = preload("uid://b4mhfidkmt6ag")
const MEDICI = preload("uid://ba6dn1gfrs32d")


@onready var empire_grid: GridContainer = %EmpireGrid
@onready var _back_button: Button = $VBoxContainer/Header/BackButton

var empires: Array[Empire] = []
var _select_buttons: Array[Button] = []


func _ready() -> void:
	empires = [MONGOL, MEDICI, BABYLONIAN]
	_build_empire_cards()


func _build_empire_cards() -> void:
	_select_buttons.clear()
	for empire in empires:
		var card := _create_empire_card(empire)
		empire_grid.add_child(card)
	_setup_focus_chain()


func _setup_focus_chain() -> void:
	if _select_buttons.is_empty():
		return
	for i in range(_select_buttons.size()):
		var prev := _select_buttons[(i - 1 + _select_buttons.size()) % _select_buttons.size()]
		var next := _select_buttons[(i + 1) % _select_buttons.size()]
		_select_buttons[i].focus_neighbor_left  = _select_buttons[i].get_path_to(prev)
		_select_buttons[i].focus_neighbor_right = _select_buttons[i].get_path_to(next)
		_select_buttons[i].focus_neighbor_top   = _select_buttons[i].get_path_to(_back_button)
	_back_button.focus_neighbor_bottom = _back_button.get_path_to(_select_buttons[0])
	_select_buttons[0].grab_focus()


func _create_empire_card(empire: Empire) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 400)

	var style := UITheme.make_panel_style(empire.color)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Shield placeholder - colored rect with empire color
	var shield_container := CenterContainer.new()
	vbox.add_child(shield_container)

	var shield := ColorRect.new()
	shield.custom_minimum_size = Vector2(80, 100)
	shield.color = empire.color
	shield_container.add_child(shield)

	# Empire name
	var name_label := Label.new()
	name_label.text = empire.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(name_label)

	# Empire ability info
	if empire.ability:
		var separator := HSeparator.new()
		vbox.add_child(separator)

		var ability_name_label := Label.new()
		ability_name_label.text = empire.ability.ability_name
		ability_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ability_name_label.add_theme_font_size_override("font_size", 14)
		ability_name_label.add_theme_color_override("font_color", empire.color.darkened(0.2))
		vbox.add_child(ability_name_label)

		var ability_desc := Label.new()
		ability_desc.text = empire.ability.description
		ability_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ability_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ability_desc.add_theme_font_size_override("font_size", 11)
		ability_desc.add_theme_color_override("font_color", UITheme.TEXT_SECONDARY)
		vbox.add_child(ability_desc)

	# Select button
	var select_btn := Button.new()
	select_btn.text = "UI_SELECT"
	select_btn.pressed.connect(_on_empire_selected.bind(empire))
	vbox.add_child(select_btn)
	_select_buttons.append(select_btn)

	var card_tween: Tween
	panel.mouse_entered.connect(func():
		if card_tween:
			card_tween.kill()
		card_tween = panel.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		card_tween.tween_property(style, "bg_color", UITheme.PARCHMENT_HOVER, 0.12)
	)
	panel.mouse_exited.connect(func():
		if card_tween:
			card_tween.kill()
		card_tween = panel.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		card_tween.tween_property(style, "bg_color", UITheme.PARCHMENT, 0.12)
	)

	return panel


func _on_empire_selected(empire: Empire) -> void:
	Events.navigate_to_generation.emit(empire)


func _on_back_button_pressed() -> void:
	Events.navigate_to_main_menu.emit()
