extends VBoxContainer
class_name TroopSlot

## Slot visual para mostrar una tropa en el panel de reclutamiento.

signal troop_selected(troop: Troop)

var troop: Troop: set = _set_troop

var icon_rect: TextureRect
var name_label: Label
var type_label: Label
var stats_label: Label
var cost_label: Label
var maintenance_label: Label


func _ready() -> void:
	_build_ui()


func _set_troop(value: Troop) -> void:
	troop = value
	if not is_node_ready():
		await ready
	_update_display()


func _build_ui() -> void:
	custom_minimum_size = Vector2(100, 165)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Icono
	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(64, 64)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(icon_rect)

	# Nombre
	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_label)

	# Tipo (efectividad)
	type_label = Label.new()
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_color_override("font_color", UITheme.TROOP_TYPE)
	type_label.add_theme_font_size_override("font_size", 11)
	add_child(type_label)

	# Stats atk/def
	stats_label = Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(stats_label)

	# Coste de reclutamiento
	cost_label = Label.new()
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(cost_label)

	# Mantenimiento por turno (oro / comida)
	maintenance_label = Label.new()
	maintenance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	maintenance_label.add_theme_color_override("font_color", UITheme.TROOP_MAINTENANCE)
	maintenance_label.add_theme_font_size_override("font_size", 11)
	add_child(maintenance_label)

	_update_display()


func _update_display() -> void:
	if troop == null:
		return
	if icon_rect:
		icon_rect.texture = troop.icon
	if name_label:
		name_label.text = tr(troop.name)
	if type_label:
		type_label.text = "[%s]" % troop.get_type_label()
		type_label.tooltip_text = _build_matchup_tooltip()
	if stats_label:
		stats_label.text = "Atk: %d  Def: %d" % [troop.attack, troop.defense]
	if cost_label:
		cost_label.text = tr("FMT_GOLD") % troop.recruitment_cost_gold
	if maintenance_label:
		maintenance_label.text = tr("FMT_MAINTENANCE") % [
			troop.maintenance_gold, troop.maintenance_food
		]


## Construye un tooltip de texto plano con los matchups fuertes/débiles
## de este tipo de tropa. Lo expone el type_label.
func _build_matchup_tooltip() -> String:
	if troop == null:
		return ""
	var strong: Array[String] = []
	var weak: Array[String] = []
	for other in Troop.TroopType.values():
		if other == troop.type:
			continue
		var mult: float = TroopEffectiveness.get_multiplier(troop.type, other)
		if mult > TroopEffectiveness.MULTIPLIER_NEUTRAL:
			strong.append(Troop.type_label_for(other))
		elif mult < TroopEffectiveness.MULTIPLIER_NEUTRAL:
			weak.append(Troop.type_label_for(other))
	var lines: Array[String] = []
	if not strong.is_empty():
		lines.append(tr("MATCHUP_STRONG") % ", ".join(strong))
	if not weak.is_empty():
		lines.append(tr("MATCHUP_WEAK") % ", ".join(weak))
	return "\n".join(lines)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			troop_selected.emit(troop)
