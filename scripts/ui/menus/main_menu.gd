extends Control

const SAVE_LOAD_PANEL_SCRIPT := preload("res://scripts/ui/menus/save_load_panel.gd")

@onready var _play_button:    Button = $CenterContainer/VBoxContainer/ButtonContainer/PlayButton
@onready var _load_button:    Button = $CenterContainer/VBoxContainer/ButtonContainer/LoadButton
@onready var _options_button: Button = $CenterContainer/VBoxContainer/ButtonContainer/OptionsButton
@onready var _exit_button:    Button = $CenterContainer/VBoxContainer/ButtonContainer/ExitButton


func _ready() -> void:
	var buttons: Array[Button] = [_play_button, _load_button, _options_button, _exit_button]
	for i in range(buttons.size()):
		var prev := buttons[(i - 1 + buttons.size()) % buttons.size()]
		var next := buttons[(i + 1) % buttons.size()]
		buttons[i].focus_neighbor_top    = buttons[i].get_path_to(prev)
		buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(next)
	_play_button.grab_focus()


func _on_play_button_pressed() -> void:
	Events.navigate_to_empire_selection.emit()


func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _on_load_button_pressed() -> void:
	var panel := SaveLoadPanel.new()
	panel.mode = SaveLoadPanel.Mode.LOAD_ONLY
	# SaveLoadPanel extiende CanvasLayer, así que se renderiza sobre todo
	# el menú independientemente de dónde esté en el árbol.
	add_child(panel)


func _on_options_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/UI/menus/options_menu.tscn")
