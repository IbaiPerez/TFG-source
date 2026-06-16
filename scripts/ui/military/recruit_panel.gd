extends PanelContainer
class_name RecruitPanel

## Panel de selección de tropas para la carta de reclutamiento.
## Similar a BuildingPanel: muestra las tropas disponibles y permite seleccionar una.

signal card_confirmed(troop: Troop)

var stats: Stats
var available_troops: Array[Troop] = []: set = set_available_troops
var _slots: Array[TroopSlot] = []

var troops_grid: GridContainer


func _ready() -> void:
	if UIState:
		UIState.register_menu()
	# Tamaño y estilo visual (consistente con BuildingPanel)
	custom_minimum_size = Vector2(460, 380)
	mouse_filter = Control.MOUSE_FILTER_STOP

	add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.BORDER_BROWN, 5, 24))

	_build_ui()

	# Centrar en pantalla tras construir la UI (deferred para que el tamaño sea correcto)
	call_deferred("_center_on_screen")


func _center_on_screen() -> void:
	var viewport_size := get_viewport_rect().size
	size = custom_minimum_size
	position = (viewport_size - size) / 2.0


func set_available_troops(value: Array[Troop]) -> void:
	if not is_node_ready():
		await ready
	available_troops = value
	_populate_grid()


func _build_ui() -> void:
	# Estructura: MarginContainer > VBoxContainer > Label + ScrollContainer > GridContainer
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	var title := Label.new()
	title.text = tr("RECRUIT_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color.BLACK)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440, 230)
	vbox.add_child(scroll)

	troops_grid = GridContainer.new()
	troops_grid.columns = 4
	scroll.add_child(troops_grid)

	_populate_grid()


func _populate_grid() -> void:
	if troops_grid == null:
		return

	# Limpiar
	for child in troops_grid.get_children():
		child.queue_free()
	_slots.clear()

	for troop in available_troops:
		var slot := TroopSlot.new()
		slot.troop = troop
		troops_grid.add_child(slot)

		if stats and not stats.can_afford_troop(troop):
			slot.cost_label.add_theme_color_override("font_color", Color.DARK_RED)
		else:
			slot.troop_selected.connect(_on_troop_selected)

		_slots.append(slot)


func _on_troop_selected(troop: Troop) -> void:
	card_confirmed.emit(troop)


func _exit_tree() -> void:
	if UIState:
		UIState.unregister_menu()
