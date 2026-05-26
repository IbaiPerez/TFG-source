extends CardState

var confirmed:bool

func enter() -> void:
	confirmed = false
	var has_targets := not card_ui.targets.is_empty()
	var needs_confirm := card_ui.card.needs_confirmation

	if has_targets or needs_confirm:
		# Limpiamos cualquier referencia colgante a un menu previo antes
		# de pedir uno nuevo: si la carta se uso en un intento anterior y
		# CONFIRMING.exit liberó el panel, `card.menu` puede ser un
		# "previously freed" object, no `null`. Sin esta limpieza,
		# `is_instance_valid` y la conexion de señal pueden dar resultados
		# inconsistentes segun la rama.
		if card_ui.card.menu != null and not is_instance_valid(card_ui.card.menu):
			card_ui.card.menu = null

		card_ui.confirm()
		# Defensa: si `confirm()` no produjo menu (p.ej. UpgradeBuildingCard
		# se sale sin emitir señal cuando targets.size() != 1), no podemos
		# conectar a nada. Volvemos a BASE de forma diferida porque emitir
		# transition_requested aqui mismo no funciona: el state machine aun
		# no nos ha asignado como current_state cuando se ejecuta enter().
		if not is_instance_valid(card_ui.card.menu):
			card_ui.card.menu = null
			call_deferred("_request_back_to_base")
			return
		card_ui.card.menu.card_confirmed.connect(_on_card_confirmed)

func exit() -> void:
	# Liberar el panel y nulear la referencia para que un proximo
	# CONFIRMING no encuentre una referencia colgante (previously freed).
	if is_instance_valid(card_ui.card.menu):
		card_ui.card.menu.queue_free()
	card_ui.card.menu = null


func _request_back_to_base() -> void:
	transition_requested.emit(self, CardState.State.BASE)

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
