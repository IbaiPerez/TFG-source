extends PanelContainer
class_name AssignTroopsPanel

## Panel para asignar tropas del pool global a un frente de batalla.
## Muestra las tropas disponibles en el pool y permite seleccionarlas una a una.

signal troop_assigned(troop: Troop)
signal panel_closed

var battle_front: BattleFront
var stats: Stats
var side: StringName  ## &"attacker" o &"defender"

var troops_grid: GridContainer
var pool_label: Label
var front_troops_label: Label
var close_button: Button


func setup(front: BattleFront, p_stats: Stats) -> void:
	battle_front = front
	stats = p_stats

	# Determinar qué bando es el jugador en este frente
	if front.attacker_empire == stats.empire:
		side = &"attacker"
	elif front.defender_empire == stats.empire:
		side = &"defender"
	else:
		# El jugador no participa en este frente
		queue_free()
		return


func _ready() -> void:
	if battle_front == null or stats == null:
		queue_free()
		return

	if UIState:
		UIState.register_menu()
	custom_minimum_size = Vector2(450, 300)
	anchors_preset = PRESET_CENTER
	_build_ui()
	_populate_pool()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Título
	var title := Label.new()
	title.text = "Asignar Tropas al Frente"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Info del frente
	front_troops_label = Label.new()
	front_troops_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(front_troops_label)

	vbox.add_child(HSeparator.new())

	# Info del pool
	pool_label = Label.new()
	pool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(pool_label)

	# Grid de tropas disponibles
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 180)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	troops_grid = GridContainer.new()
	troops_grid.columns = 4
	scroll.add_child(troops_grid)

	# Botón cerrar
	close_button = Button.new()
	close_button.text = "Cerrar"
	close_button.pressed.connect(_on_close_pressed)
	vbox.add_child(close_button)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _populate_pool() -> void:
	if troops_grid == null:
		return

	# Limpiar
	for child in troops_grid.get_children():
		child.queue_free()

	# Mostrar info
	var troops_in_front: int
	if side == &"attacker":
		troops_in_front = battle_front.attacker_troops.size()
	else:
		troops_in_front = battle_front.defender_troops.size()

	front_troops_label.text = "Tropas en el frente: %d" % troops_in_front
	pool_label.text = "Tropas en reserva: %d" % stats.troop_pool.size()

	if stats.troop_pool.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No hay tropas disponibles en la reserva"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", UITheme.EMPTY_MUTED)
		troops_grid.add_child(empty_label)
		return

	# Mostrar cada tropa del pool como un slot clickeable
	for troop in stats.troop_pool:
		var slot := _create_troop_slot(troop)
		troops_grid.add_child(slot)


func _create_troop_slot(troop: Troop) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(95, 120)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	# Icono
	if troop.icon:
		var icon := TextureRect.new()
		icon.texture = troop.icon
		icon.custom_minimum_size = Vector2(40, 40)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(icon)

	# Nombre
	var name_label := Label.new()
	name_label.text = troop.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# Tipo de tropa (relevante para la efectividad piedra-papel-tijera)
	var type_label := Label.new()
	type_label.text = "[%s]" % troop.get_type_label()
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_color_override("font_color", UITheme.TROOP_TYPE)
	type_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(type_label)

	# Stats
	var stats_label := Label.new()
	stats_label.text = "ATK:%d DEF:%d" % [troop.attack, troop.defense]
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_label)

	# Botón asignar
	var btn := Button.new()
	btn.text = "Asignar"
	btn.pressed.connect(func(): _on_troop_slot_pressed(troop))
	vbox.add_child(btn)

	return panel


func _on_troop_slot_pressed(troop: Troop) -> void:
	if battle_front.is_resolved:
		return

	# El BattleFrontManager se encarga de sacar del pool y añadir al frente
	troop_assigned.emit(troop)

	# Refrescar la UI
	_populate_pool()


func _on_close_pressed() -> void:
	panel_closed.emit()
	queue_free()


func _exit_tree() -> void:
	if UIState:
		UIState.unregister_menu()
