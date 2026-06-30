extends CardState


func enter() -> void:
	card_ui.drop_point_detector.monitoring = true
	card_ui.tooltip.hide_tooltip()


func on_input(event:InputEvent) -> void:
	# ESC cancela el clic en curso (vuelve la carta a la mano) y consume el
	# input para que el menu de pausa no se abra mientras se manipula una carta.
	if event.is_action_pressed("ui_cancel"):
		card_ui.get_viewport().set_input_as_handled()
		transition_requested.emit(self, CardState.State.BASE)
		return

	if event is InputEventMouseMotion:
		transition_requested.emit(self,CardState.State.DRAGGING)
