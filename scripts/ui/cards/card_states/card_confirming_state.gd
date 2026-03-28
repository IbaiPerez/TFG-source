extends CardState

var confirmed:bool

func enter() -> void:
	confirmed = false
	card_ui.confirm()
	card_ui.card.menu.card_confirmed.connect(_on_card_confirmed)

func exit() -> void:
	card_ui.card.menu.queue_free()

func _on_card_confirmed(chosen:Resource) -> void:
	confirmed = true
	card_ui.card.chosen = chosen
	transition_requested.emit(self,CardState.State.RELEASED)

func on_input(event:InputEvent) -> void:
	if confirmed:
		return
	if event.is_action_pressed("RightClick"):
		transition_requested.emit(self, CardState.State.BASE)
