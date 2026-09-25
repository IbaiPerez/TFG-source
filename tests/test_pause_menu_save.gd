extends GutTest

## Guardar desde el menú de pausa: el botón abre el panel de ranuras en modo
## completo, visible por encima de la pausa, y cargar desde él suelta la pausa
## (el flujo de carga no la toca y la partida arrancaría congelada).

const PAUSE_MENU := preload("res://scenes/UI/menus/pause_menu.tscn")

var _menu: CanvasLayer


func before_each() -> void:
	_menu = PAUSE_MENU.instantiate()
	add_child_autofree(_menu)


func after_each() -> void:
	get_tree().paused = false


func _open_panel() -> SaveLoadPanel:
	(_menu.get_node("%SaveButton") as Button).pressed.emit()
	for child in _menu.get_children():
		if child is SaveLoadPanel:
			return child
	return null


func test_guardar_abre_el_panel_completo_por_encima_de_la_pausa() -> void:
	var panel := _open_panel()
	assert_not_null(panel, "el botón abre el panel de ranuras")
	if panel == null:
		return
	assert_eq(panel.mode, SaveLoadPanel.Mode.FULL, "con guardar, no solo cargar")
	assert_gt(panel.layer, _menu.layer, "se ve por encima del menú de pausa")


func test_cargar_desde_la_pausa_suelta_la_pausa() -> void:
	_menu._open()
	assert_true(get_tree().paused)
	# Instantánea vacía: SceneManager la ignora, así que no cambia de escena.
	GameSaveManager.load_requested.emit({})
	assert_false(get_tree().paused, "la partida cargada no puede arrancar congelada")
	assert_false(_menu.visible, "y el menú de pausa se cierra")


func test_la_carga_sin_pausa_abierta_no_toca_nada() -> void:
	GameSaveManager.load_requested.emit({})
	assert_false(_menu.visible, "no abre ni cierra nada si no estaba en pausa")


## Escape real por el viewport, como llega en el juego: lo reciben antes los hijos
## que el padre, así que el submenú que cuelga de la pausa lo ve primero.
func _press_escape() -> void:
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	get_viewport().push_input(ev)


func _child_of_type(type) -> Node:
	for child in _menu.get_children():
		if is_instance_of(child, type) and not child.is_queued_for_deletion():
			return child
	return null


func test_escape_cierra_antes_el_submenu_que_la_pausa() -> void:
	var submenus := [["%SaveButton", SaveLoadPanel], ["%TutorialButton", TutorialPanel],
		["%FeedbackButton", FeedbackPanel]]
	for s in submenus:
		_menu._open()
		(_menu.get_node(s[0]) as Button).pressed.emit()
		var panel := _child_of_type(s[1])
		assert_not_null(panel, "%s abre su panel" % s[0])
		_press_escape()
		assert_true(panel.is_queued_for_deletion(), "%s: el primer Escape cierra el submenú" % s[0])
		assert_true(_menu.visible, "%s: y la pausa sigue abierta" % s[0])
		# Entre dos pulsaciones reales pasa al menos un frame: el panel cerrado ya no
		# está en el árbol para quedarse también la segunda.
		await get_tree().process_frame
		_press_escape()
		assert_false(_menu.visible, "%s: el segundo Escape cierra la pausa" % s[0])
	# Avisos esperados al abrir los comentarios fuera de una partida: sin escena del
	# mapa no hay informe, y sin URL de encuesta configurada el botón se deshabilita.
	for e in get_errors():
		e.handled = true
