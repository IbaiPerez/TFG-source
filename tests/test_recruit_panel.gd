extends GutTest

## Tests para TroopSlot y RecruitPanel — el panel de selección de tropas
## que aparece al jugar la carta de reclutamiento.

# El coste mostrado compara contra texto en español ("oro"). Fijamos el
# locale para que no dependa del idioma guardado en user://settings.cfg o del SO.
var _prev_locale: String

var stats: Stats


func before_all() -> void:
	_prev_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("es")


func after_all() -> void:
	TranslationServer.set_locale(_prev_locale)


func _create_troop(troop_name: String, atk: int = 3, def: int = 3,
		gold_cost: int = 20, maint_gold: int = 1,
		maint_food: int = 1) -> Troop:
	var troop := Troop.new()
	troop.name = troop_name
	troop.attack = atk
	troop.defense = def
	troop.recruitment_cost_gold = gold_cost
	troop.maintenance_gold = maint_gold
	troop.maintenance_food = maint_food
	return troop


func before_each() -> void:
	stats = Stats.new()
	stats.total_gold = 1000
	# gpt y food positivos: el nuevo `can_afford_troop` (Opcion 3b)
	# bloquea recruit si gpt o food no cubren el mantenimiento de la
	# nueva tropa. Estos tests son de UI del panel, no del gating, asi
	# que damos margen amplio. Los tests que ESPECIFICAMENTE quieren
	# bloquear afford bajan estos valores localmente.
	stats.gold_per_turn = 100
	stats.food = 100
	stats.troop_pool = []


# --- Tests TroopSlot ---

func test_slot_displays_name() -> void:
	var slot := TroopSlot.new()
	add_child_autofree(slot)
	slot.troop = _create_troop("Caballería")

	assert_eq(slot.name_label.text, "Caballería")


func test_slot_displays_attack_and_defense() -> void:
	var slot := TroopSlot.new()
	add_child_autofree(slot)
	slot.troop = _create_troop("Élite", 7, 4)

	assert_string_contains(slot.stats_label.text, "7", "Stats label debe incluir atk")
	assert_string_contains(slot.stats_label.text, "4", "Stats label debe incluir def")


func test_slot_displays_recruitment_cost() -> void:
	var slot := TroopSlot.new()
	add_child_autofree(slot)
	slot.troop = _create_troop("Milicia", 3, 3, 25)

	assert_string_contains(slot.cost_label.text, "25",
		"El coste debe aparecer en cost_label")
	assert_string_contains(slot.cost_label.text, "oro",
		"El coste debe indicar la unidad")


func test_slot_displays_maintenance() -> void:
	var slot := TroopSlot.new()
	add_child_autofree(slot)
	slot.troop = _create_troop("Caballería", 5, 2, 30, 3, 2)

	assert_not_null(slot.maintenance_label,
		"TroopSlot debe tener un maintenance_label")
	assert_string_contains(slot.maintenance_label.text, "3",
		"El mantenimiento debe incluir el coste de oro (3)")
	assert_string_contains(slot.maintenance_label.text, "2",
		"El mantenimiento debe incluir el coste de comida (2)")


func test_slot_displays_zero_maintenance() -> void:
	var slot := TroopSlot.new()
	add_child_autofree(slot)
	slot.troop = _create_troop("Sin mantenimiento", 1, 1, 5, 0, 0)

	assert_string_contains(slot.maintenance_label.text, "0",
		"El mantenimiento debe mostrarse aunque sea 0 (consistencia)")


func test_slot_emits_troop_selected_on_click() -> void:
	var slot := TroopSlot.new()
	add_child_autofree(slot)
	var troop := _create_troop("Milicia")
	slot.troop = troop

	watch_signals(slot)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	slot._gui_input(click)

	assert_signal_emitted(slot, "troop_selected")
	# Debe emitir la tropa que se ha clickado.
	assert_signal_emitted_with_parameters(slot, "troop_selected", [troop])


func test_slot_does_not_emit_on_release() -> void:
	var slot := TroopSlot.new()
	add_child_autofree(slot)
	slot.troop = _create_troop("Milicia")

	watch_signals(slot)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	slot._gui_input(release)

	assert_signal_not_emitted(slot, "troop_selected",
		"Sólo el press debe disparar la selección, no el release")


# --- Tests RecruitPanel ---

func _make_panel() -> RecruitPanel:
	var panel := RecruitPanel.new()
	add_child_autofree(panel)
	panel.stats = stats
	return panel


func test_panel_populates_one_slot_per_troop() -> void:
	var panel := _make_panel()
	panel.available_troops = [
		_create_troop("Milicia"),
		_create_troop("Caballería"),
		_create_troop("Piquero"),
	]
	# set_available_troops puede esperar a ready, dar un frame por seguridad
	await get_tree().process_frame

	assert_eq(panel.troops_grid.get_child_count(), 3,
		"Debe haber un slot por tropa disponible")


func test_panel_emits_card_confirmed_on_selection() -> void:
	var panel := _make_panel()
	var milicia := _create_troop("Milicia")
	panel.available_troops = [milicia]
	await get_tree().process_frame

	watch_signals(panel)
	var slot := panel.troops_grid.get_child(0) as TroopSlot
	slot.troop_selected.emit(milicia)

	assert_signal_emitted(panel, "card_confirmed")
	# Debe propagar la tropa seleccionada en el card_confirmed.
	assert_signal_emitted_with_parameters(panel, "card_confirmed", [milicia])


func test_panel_marks_unaffordable_troops_in_red() -> void:
	stats.total_gold = 10
	var panel := _make_panel()
	var cheap := _create_troop("Milicia", 3, 3, 5)
	var expensive := _create_troop("Élite", 9, 9, 100)
	panel.available_troops = [cheap, expensive]
	await get_tree().process_frame

	var cheap_slot := panel.troops_grid.get_child(0) as TroopSlot
	var expensive_slot := panel.troops_grid.get_child(1) as TroopSlot

	# El override sólo se aplica al slot caro
	var expensive_color: Color = expensive_slot.cost_label.get_theme_color("font_color")
	assert_eq(expensive_color, Color.DARK_RED,
		"El coste de la tropa no asequible debe pintarse en rojo")

	# La tropa asequible no debe tener override (mantiene color por defecto)
	assert_false(cheap_slot.cost_label.has_theme_color_override("font_color"),
		"La tropa asequible no debe llevar override de color")


func test_panel_does_not_connect_unaffordable_troops() -> void:
	stats.total_gold = 0
	var panel := _make_panel()
	var expensive := _create_troop("Élite", 9, 9, 100)
	panel.available_troops = [expensive]
	await get_tree().process_frame

	var slot := panel.troops_grid.get_child(0) as TroopSlot
	watch_signals(panel)

	# Si se intentara seleccionar (vía señal interna del slot), el panel
	# no debe propagar card_confirmed porque no se ha conectado.
	slot.troop_selected.emit(expensive)
	assert_signal_not_emitted(panel, "card_confirmed",
		"El panel no debe permitir confirmar tropas no asequibles")


func test_panel_repopulates_when_troops_reassigned() -> void:
	var panel := _make_panel()
	panel.available_troops = [_create_troop("Milicia"), _create_troop("Caballería")]
	await get_tree().process_frame
	assert_eq(panel.troops_grid.get_child_count(), 2)

	panel.available_troops = [_create_troop("Élite")]
	await get_tree().process_frame
	# Esperar a que los queue_free de la primera ronda se procesen
	await get_tree().process_frame
	assert_eq(panel.troops_grid.get_child_count(), 1,
		"Reasignar available_troops debe limpiar los slots anteriores")
