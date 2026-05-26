extends Control

const SAVE_LOAD_PANEL_SCRIPT := preload("res://scripts/ui/menus/save_load_panel.gd")


func _on_play_button_pressed() -> void:
	Events.navigate_to_empire_selection.emit()


func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _on_load_button_pressed() -> void:
	var panel := SaveLoadPanel.new()
	panel.mode = SaveLoadPanel.Mode.LOAD_ONLY
	add_child(panel)
