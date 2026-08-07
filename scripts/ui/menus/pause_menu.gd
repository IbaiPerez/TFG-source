extends CanvasLayer

@onready var _continue_button:  Button = %ContinueButton
@onready var _tutorial_button:  Button = %TutorialButton
@onready var _feedback_button:  Button = %FeedbackButton
@onready var _main_menu_button: Button = %MainMenuButton


func _ready() -> void:
	visible = false
	var buttons: Array[Button] = [_continue_button, _tutorial_button,
			_feedback_button, _main_menu_button]
	for i in buttons.size():
		var prev := buttons[(i - 1 + buttons.size()) % buttons.size()]
		var next := buttons[(i + 1) % buttons.size()]
		buttons[i].focus_neighbor_top    = buttons[i].get_path_to(prev)
		buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(next)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if visible:
		_resume()
		get_viewport().set_input_as_handled()
	elif _can_open():
		_open()
		get_viewport().set_input_as_handled()


## Solo abrimos el menu de pausa si no hay ya otra cosa modal en marcha:
## - El arbol ya pausado (un evento de turno o tienda tiene su propio panel).
## - Algun menu registrado en UIState (building, recruit, frente de batalla,
##   recover, etc.). Asi ESC no abre la pausa "encima" de otro panel.
func _can_open() -> bool:
	if get_tree().paused:
		return false
	if UIState and UIState.is_any_menu_open():
		return false
	return true


func _open() -> void:
	visible = true
	get_tree().paused = true
	_continue_button.grab_focus()


func _resume() -> void:
	visible = false
	get_tree().paused = false


func _on_continue_button_pressed() -> void:
	_resume()


func _on_tutorial_button_pressed() -> void:
	var panel := TutorialPanel.new()
	add_child(panel)
	# TutorialPanel._ready() fuerza layer=10; al ser menor que el menu de pausa
	# (layer=20) quedaria detras del overlay. Lo elevamos DESPUES de add_child
	# (cuando _ready ya corrio) para que se vea por encima. Hereda el
	# process_mode ALWAYS del menu de pausa, asi funciona con el arbol pausado.
	panel.layer = 25


## Feedback desde la pausa. Es la entrada que de verdad importa: quien abre este
## menú a mitad de partida suele estar a punto de dejarla, y ese jugador nunca
## llega a una encuesta enlazada solo desde la página de itch.io. Por eso el
## informe se marca como ABANDONED aunque todavía no haya salido.
func _on_feedback_button_pressed() -> void:
	var panel := FeedbackPanel.new()
	panel.report = _capture_report()
	# Hereda el process_mode ALWAYS del menú de pausa y se pone en un layer por
	# encima (30 > 20) en su propio _ready, así que no hay que tocar nada más.
	add_child(panel)


## El informe lo arma la escena Map, que es quien tiene la semilla, el imperio y
## el turno. Se llega a ella por `owner` porque este menú es una instancia
## colocada dentro de map.tscn. Si no estuviera (un test que instancia la pausa
## suelta), el panel se abre igual con el informe vacío.
func _capture_report() -> PlayReport:
	if owner == null or not owner.has_method("capture_play_report"):
		push_warning("[PauseMenu] Sin escena Map en `owner`: informe de partida vacío.")
		return null
	return owner.capture_play_report(PlayReport.Outcome.ABANDONED)


func _on_main_menu_button_pressed() -> void:
	GameSaveManager.save_current_game("autosave")
	get_tree().paused = false
	Events.navigate_to_main_menu.emit()
