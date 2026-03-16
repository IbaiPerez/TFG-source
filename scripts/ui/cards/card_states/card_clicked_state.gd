extends CardState


func enter() -> void:
	card_ui.drop_point_detector.monitoring = true
	card_ui.tooltip.hide_tooltip()


func on_input(event:InputEvent) -> void:
	if event is InputEventMouseMotion:
		transition_requested.emit(self,CardState.State.DRAGGING)
