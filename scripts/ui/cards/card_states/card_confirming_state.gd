extends CardState

var confirmed:bool

func enter() -> void:
	confirmed = false
	var has_targets := not card_ui.targets.is_empty()
	var needs_confirm := card_ui.card.needs_confirmation

	if has_targets or needs_confirm:
		card_ui.confirm()
		card_ui.card.menu.card_confirmed.connect(_on_card_confirmed)

func exit() -> void:
	if card_ui.card.menu:
		card_ui.card.menu.queue_free()

func _on_card_confirmed(chosen:Variant) -> void:
	# Si chosen es null, el jugador ha cancelado desde el panel
	if chosen == null:
		transition_requested.emit(self, CardState.State.BASE)
		return
	confirmed = true
	card_ui.card.chosen = chosen
	# Para cartas sin target, forzar un target ficticio para que RELEASED ejecute play()
	if card_ui.targets.is_empty():
		card_ui.targets.append(card_ui)
	transition_requested.emit(self,CardState.State.RELEASED)

func on_input(event:InputEvent) -> void:
	if confirmed:
		return
	if event.is_action_pressed("RightClick"):
		transition_requested.emit(self, CardState.State.BASE)
