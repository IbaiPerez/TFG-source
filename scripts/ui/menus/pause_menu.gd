extends CanvasLayer

@onready var _continue_button:  Button = %ContinueButton
@onready var _tutorial_button:  Button = %TutorialButton
@onready var _main_menu_button: Button = %MainMenuButton


func _ready() -> void:
	visible = false
	var buttons: Array[Button] = [_continue_button, _tutorial_button, _main_menu_button]
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


func _on_main_menu_button_pressed() -> void:
	GameSaveManager.save_current_game("autosave")
	get_tree().paused = false
	Events.navigate_to_main_menu.emit()
