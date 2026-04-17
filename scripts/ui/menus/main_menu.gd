extends Control

func _on_play_button_pressed() -> void:
	Events.navigate_to_empire_selection.emit()

func _on_exit_button_pressed() -> void:
	get_tree().quit()
