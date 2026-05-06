extends GutTest

## Tests para el menú de tropas reclutadas: TroopPoolOpener,
## TroopMenuUi y TroopPoolView. Sigue el patrón de los menús de cartas.

const TROOP_POOL_OPENER = preload("res://scenes/UI/military/troop_pool_opener.tscn")
const TROOP_POOL_VIEW = preload("res://scenes/UI/military/troop_pool_view.tscn")
const TROOP_MENU_UI = preload("res://scenes/UI/military/troop_menu_ui.tscn")

var stats: Stats


func _create_troop(troop_name: String, atk: int = 3, def: int = 3,
		gold_cost: int = 20) -> Troop:
	var troop := Troop.new()
	troop.name = troop_name
	troop.attack = atk
	troop.defense = def
	troop.recruitment_cost_gold = gold_cost
	troop.maintenance_gold = 1
	troop.maintenance_food = 1
	return troop


func before_each() -> void:
	stats = Stats.new()
	stats.total_gold = 1000
	stats.food = 100
	stats.troop_pool = []


# --- Tests TroopPoolOpener ---

func test_opener_counter_shows_initial_pool_size() -> void:
	stats.troop_pool = [_create_troop("Milicia"), _create_troop("Milicia")]

	var opener: TroopPoolOpener = TROOP_POOL_OPENER.instantiate()
	add_child_autofree(opener)
	opener.stats = stats

	assert_eq(opener.counter.text, "2",
		"Al asignar stats con 2 tropas, el contador debe mostrar 2")


func test_opener_counter_updates_when_troop_recruited() -> void:
	var opener: TroopPoolOpener = TROOP_POOL_OPENER.instantiate()
	add_child_autofree(opener)
	opener.stats = stats

	assert_eq(opener.counter.text, "0", "Pool vacío → contador a 0")

	stats.recruit_troop(_create_troop("Milicia"))
	assert_eq(opener.counter.text, "1",
		"Tras reclutar, el contador debe pasar a 1")


func test_opener_counter_updates_when_troop_removed() -> void:
	var troop := _create_troop("Milicia")
	stats.troop_pool = [troop]

	var opener: TroopPoolOpener = TROOP_POOL_OPENER.instantiate()
	add_child_autofree(opener)
	opener.stats = stats

	assert_eq(opener.counter.text, "1")
	stats.remove_troop(troop)
	assert_eq(opener.counter.text, "0",
		"Tras retirar la tropa, el contador debe bajar a 0")


func test_opener_does_not_double_connect_signal() -> void:
	var opener: TroopPoolOpener = TROOP_POOL_OPENER.instantiate()
	add_child_autofree(opener)
	opener.stats = stats
	# Reasignar el mismo stats no debe duplicar conexiones
	opener.stats = stats

	stats.recruit_troop(_create_troop("Milicia"))
	# Si la conexión estuviera duplicada el contador habría parpadeado al
	# mismo valor; aquí verificamos solo que no rompe y sigue sincronizado.
	assert_eq(opener.counter.text, "1")


func test_opener_handles_null_stats_gracefully() -> void:
	var opener: TroopPoolOpener = TROOP_POOL_OPENER.instantiate()
	add_child_autofree(opener)
	# No debe romper si nunca se le pasa un Stats
	assert_eq(opener.counter.text, "0",
		"Sin stats asignado el contador mantiene su valor por defecto")


# --- Tests TroopMenuUi ---

func test_menu_ui_displays_troop_info() -> void:
	var slot: TroopMenuUi = TROOP_MENU_UI.instantiate()
	add_child_autofree(slot)
	slot.troop = _create_troop("Caballería", 5, 2)

	assert_eq(slot.name_label.text, "Caballería")
	assert_string_contains(slot.stats_label.text, "5", "Stats label debe incluir atk")
	assert_string_contains(slot.stats_label.text, "2", "Stats label debe incluir def")


func test_menu_ui_count_badge_hidden_when_one() -> void:
	var slot: TroopMenuUi = TROOP_MENU_UI.instantiate()
	add_child_autofree(slot)
	slot.troop = _create_troop("Milicia")
	slot.count = 1

	assert_false(slot.count_label.visible,
		"Con count=1 el badge debe estar oculto (no aporta info)")


func test_menu_ui_count_badge_visible_when_many() -> void:
	var slot: TroopMenuUi = TROOP_MENU_UI.instantiate()
	add_child_autofree(slot)
	slot.troop = _create_troop("Milicia")
	slot.count = 4

	assert_true(slot.count_label.visible,
		"Con count>1 el badge debe ser visible")
	assert_eq(slot.count_label.text, "x4",
		"El badge debe formatearse como xN")


# --- Tests TroopPoolView ---

func _make_view() -> TroopPoolView:
	var view: TroopPoolView = TROOP_POOL_VIEW.instantiate()
	add_child_autofree(view)
	view.stats = stats
	return view


func test_view_groups_troops_by_type() -> void:
	var milicia := _create_troop("Milicia")
	var caballeria := _create_troop("Caballería")
	# 3 milicias (mismo Resource) + 1 caballería = 2 entradas en el grid
	stats.troop_pool = [milicia, milicia, milicia, caballeria]

	var view := _make_view()
	view.show_current_view("Test")
	# show_current_view usa call_deferred para construir el grid
	await get_tree().process_frame

	assert_eq(view.troops_container.get_child_count(), 2,
		"Debe haber un slot por tipo de tropa, no uno por instancia")


func test_view_count_badge_reflects_quantity() -> void:
	var milicia := _create_troop("Milicia")
	stats.troop_pool = [milicia, milicia, milicia]

	var view := _make_view()
	view.show_current_view("Test")
	await get_tree().process_frame

	var slot := view.troops_container.get_child(0) as TroopMenuUi
	assert_not_null(slot, "El hijo debe ser un TroopMenuUi")
	assert_eq(slot.count, 3, "El slot debe tener count=3")
	assert_eq(slot.count_label.text, "x3")


func test_view_sets_title() -> void:
	var view := _make_view()
	view.show_current_view("Tropas reclutadas")
	await get_tree().process_frame

	assert_eq(view.title.text, "Tropas reclutadas")


func test_view_shows_empty_state() -> void:
	stats.troop_pool = []
	var view := _make_view()
	view.show_current_view("Test")
	await get_tree().process_frame

	assert_true(view.empty_label.visible,
		"Con el pool vacío debe verse el mensaje de 'sin tropas'")
	# El ScrollContainer (padre del grid) debe ocultarse
	var scroll := view.troops_container.get_parent() as Control
	assert_false(scroll.visible,
		"El ScrollContainer debe ocultarse cuando no hay tropas")


func test_view_hides_empty_state_with_troops() -> void:
	stats.troop_pool = [_create_troop("Milicia")]
	var view := _make_view()
	view.show_current_view("Test")
	await get_tree().process_frame

	assert_false(view.empty_label.visible,
		"Con tropas, el mensaje de vacío debe estar oculto")
	var scroll := view.troops_container.get_parent() as Control
	assert_true(scroll.visible,
		"El ScrollContainer debe verse cuando hay tropas")


func test_view_back_button_hides_view() -> void:
	var view := _make_view()
	view.show_current_view("Test")
	await get_tree().process_frame
	assert_true(view.visible, "Tras show_current_view la vista es visible")

	view.back_button.pressed.emit()
	assert_false(view.visible, "El botón Back debe ocultar la vista")


func test_view_show_clears_previous_slots() -> void:
	# Primera apertura con 2 tipos
	stats.troop_pool = [_create_troop("Milicia"), _create_troop("Caballería")]
	var view := _make_view()
	view.show_current_view("Test")
	await get_tree().process_frame
	assert_eq(view.troops_container.get_child_count(), 2)

	# Segunda apertura con 1 tipo distinto: la vista debe reflejar SOLO la nueva
	stats.troop_pool = [_create_troop("Élite")]
	view.show_current_view("Test")
	await get_tree().process_frame
	# Esperar también a que los queue_free de la primera ronda se procesen
	await get_tree().process_frame

	assert_eq(view.troops_container.get_child_count(), 1,
		"Reabrir la vista no debe acumular slots de aperturas previas")
