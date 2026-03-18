extends CardState

const DRAG_MINIMUM_THRESHOLD := 0.05

var minimum_drag_time_elapsed := false

func enter() -> void:
	var ui_layer := get_tree().get_first_node_in_group("ui_layer")
	if ui_layer:
		card_ui.reparent(ui_layer)
	
	minimum_drag_time_elapsed = false
	var threshold_timer := get_tree().create_timer(DRAG_MINIMUM_THRESHOLD,false)
	threshold_timer.timeout.connect(func():minimum_drag_time_elapsed=true)
	card_ui.panel.set("theme_override_styles/panel",card_ui.CARD_DRAGGING_STYLE)

func on_input(event:InputEvent) -> void:
	var single_targeted := card_ui.card.is_tile_targeted() or card_ui.card.is_batle_front_targeted() 
	var mouse_motion := event is InputEventMouseMotion
	var cancel = event.is_action_pressed("RightClick")
	var confirm = event.is_action_released("Click") or event.is_action_pressed("Click")
	
	if single_targeted and mouse_motion and card_ui.targets.size() > 0:
		transition_requested.emit(self, CardState.State.AIMING)
		return
	
	if mouse_motion:
		card_ui.global_position = card_ui.get_global_mouse_position() - card_ui.pivot_offset
	
	if cancel:
		transition_requested.emit(self,CardState.State.BASE)
	elif minimum_drag_time_elapsed and confirm:
		get_viewport().set_input_as_handled()
		transition_requested.emit(self,CardState.State.RELEASED)
