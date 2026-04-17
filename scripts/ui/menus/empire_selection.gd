extends Control

const BABYLONIAN = preload("uid://dlljlcjgbqsv5")
const MEDICI = preload("uid://dcm8kss34cngp")
const MONGOL = preload("uid://b4mhfidkmt6ag")

@onready var empire_grid: GridContainer = %EmpireGrid

var empires: Array[Empire] = []


func _ready() -> void:
	empires = [MONGOL, MEDICI, BABYLONIAN]
	_build_empire_cards()


func _build_empire_cards() -> void:
	for empire in empires:
		var card := _create_empire_card(empire)
		empire_grid.add_child(card)


func _create_empire_card(empire: Empire) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 260)

	# Style: pergamino bg with empire color border
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.949, 0.886, 0.729, 1.0)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = empire.color
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.content_margin_left = 16.0
	style.content_margin_top = 16.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 16.0
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

	# Select button
	var select_btn := Button.new()
	select_btn.text = "Select"
	select_btn.pressed.connect(_on_empire_selected.bind(empire))
	vbox.add_child(select_btn)

	# Hover style
	var hover_style := style.duplicate()
	hover_style.bg_color = Color(0.92, 0.85, 0.68, 1.0)
	panel.mouse_entered.connect(func(): panel.add_theme_stylebox_override("panel", hover_style))
	panel.mouse_exited.connect(func(): panel.add_theme_stylebox_override("panel", style))

	return panel


func _on_empire_selected(empire: Empire) -> void:
	Events.navigate_to_generation.emit(empire)


func _on_back_button_pressed() -> void:
	Events.navigate_to_main_menu.emit()
