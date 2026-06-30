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
	# ESC cancela el arrastre (vuelve la carta a la mano) y consume el input
	# para que el menu de pausa no se abra mientras se manipula una carta.
	if event.is_action_pressed("ui_cancel"):
		card_ui.get_viewport().set_input_as_handled()
		transition_requested.emit(self, CardState.State.BASE)
		return

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
		# Si la carta requiere target (tile o frente) pero no se solto
		# sobre ninguno valido, no tiene sentido entrar a CONFIRMING:
		# `card.confirm()` rechazaria por targets invalidos y dejaria
		# `card.menu` sin crear, lo que provocaria un crash al intentar
		# conectar la señal en CardConfirmingState.enter (o, si la carta
		# se uso antes, accederiamos a un menu previously freed).
		var requires_target := single_targeted
		var has_targets := card_ui.targets.size() > 0
		if requires_target and not has_targets:
			transition_requested.emit(self, CardState.State.BASE)
			return
		if card_ui.card.needs_confirmation:
			transition_requested.emit(self,CardState.State.CONFIRMING)
		else:
			transition_requested.emit(self,CardState.State.RELEASED)
