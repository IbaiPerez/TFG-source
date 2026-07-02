extends PanelContainer
class_name BattleFrontPanel

## Panel que muestra el estado de un frente de batalla activo.
## Visualización del tira y afloja, tropas, stats y turnos restantes.
## La estructura visual está definida en scenes/UI/military/battle_front_panel.tscn.

signal assign_troop_requested(front: BattleFront)
signal panel_closed

## Referencias al modelo de datos
var battle_front: BattleFront
var player_empire: Empire  ## Para saber qué bando es el jugador

## Nodos de la escena (asignados via unique_name_in_owner)
@onready var title_label: Label = %TitleLabel
@onready var tug_container: Control = %TugContainer
@onready var tug_bar_defender: ColorRect = %TugBarDefender
@onready var tug_bar_attacker: ColorRect = %TugBarAttacker
@onready var tug_indicator: ColorRect = %TugIndicator
@onready var marker_label: Label = %MarkerLabel
@onready var turns_label: Label = %TurnsLabel
@onready var attacker_label: Label = %AttackerLabel
@onready var attacker_stats_label: RichTextLabel = %AttackerStats
@onready var attacker_troops_container: VBoxContainer = %AttackerTroopsContainer
@onready var defender_label: Label = %DefenderLabel
@onready var defender_stats_label: RichTextLabel = %DefenderStats
@onready var defender_troops_container: VBoxContainer = %DefenderTroopsContainer
@onready var assign_button: Button = %AssignButton
@onready var close_button: Button = %CloseButton

## Colores derivados de los imperios involucrados
var attacker_color: Color
var defender_color: Color


func setup(front: BattleFront, empire: Empire) -> void:
	battle_front = front
	player_empire = empire


func _ready() -> void:
	if battle_front == null:
		queue_free()
		return

	if UIState:
		UIState.register_menu()

	attacker_color = battle_front.attacker_empire.color if battle_front.attacker_empire else Color.RED
	defender_color = battle_front.defender_empire.color if battle_front.defender_empire else Color.BLUE

	# Aplicar color del imperio a los headers de cada bando
	attacker_label.add_theme_color_override("font_color", attacker_color)
	defender_label.add_theme_color_override("font_color", defender_color)

	# Conectar botones
	assign_button.pressed.connect(_on_assign_pressed)
	close_button.pressed.connect(_on_close_pressed)

	# Conectar señales globales para refresco en tiempo real
	Events.battle_front_marker_changed.connect(_on_marker_changed)
	Events.troop_assigned_to_front.connect(_on_troop_assigned)
	Events.battle_front_resolved.connect(_on_front_resolved)
	Events.battle_front_bonus_applied.connect(_on_bonus_applied)

	_update_display()


func _update_display() -> void:
	if battle_front == null:
		return

	# Título
	var atk_name: String = battle_front.attacker_empire.name if battle_front.attacker_empire else "?"
	var def_name: String = battle_front.defender_empire.name if battle_front.defender_empire else "?"
	title_label.text = "%s vs %s" % [tr(atk_name), tr(def_name)]

	# Marcador y turnos
	var marker_sign := "+" if battle_front.marker >= 0 else ""
	var effective_threshold := battle_front.get_current_threshold()
	marker_label.text = tr("BATTLE_MARKER") % [marker_sign, battle_front.marker, effective_threshold]

	var turns_remaining := maxi(battle_front.min_duration - battle_front.turns_elapsed, 0)
	turns_label.text = tr("BATTLE_TURNS") % [battle_front.turns_elapsed, turns_remaining]

	# Actualizar barra de tira y afloja
	_update_tug_bar()

	# Stats por bando
	_update_side_stats(BattleFront.Side.ATTACKER, attacker_stats_label)
	_update_side_stats(BattleFront.Side.DEFENDER, defender_stats_label)

	# Tropas
	_update_troops_display(battle_front.attacker_troops, attacker_troops_container, attacker_color)
	_update_troops_display(battle_front.defender_troops, defender_troops_container, defender_color)

	# Botón de asignar solo si el jugador participa y hay tropas en pool
	_update_assign_button()


func _update_tug_bar() -> void:
	if tug_bar_defender == null or tug_bar_attacker == null or tug_indicator == null:
		return

	# Normalizar posición del marcador al rango [0, 1]
	# marker = -threshold → t=0 (extremo defensor)
	# marker = +threshold → t=1 (extremo atacante)
	var t: float = 0.5
	var effective_threshold_bar := battle_front.get_current_threshold()
	if effective_threshold_bar > 0.0:
		t = clampf((battle_front.marker / effective_threshold_bar + 1.0) / 2.0, 0.0, 1.0)

	# Colorear cada barra con su color de imperio
	tug_bar_defender.color = defender_color.darkened(0.2)
	tug_bar_attacker.color = attacker_color.darkened(0.2)

	# Posicionar barras según el marcador (necesita esperar al layout)
	await get_tree().process_frame
	if not is_instance_valid(tug_container):
		return
	var bar_width: float = tug_container.size.x
	if bar_width > 0:
		# Defensor: de 0 a t
		tug_bar_defender.position.x = 2.0
		tug_bar_defender.size.x = t * (bar_width - 4.0)

		# Atacante: de t a 1
		tug_bar_attacker.position.x = 2.0 + t * (bar_width - 4.0)
		tug_bar_attacker.size.x = (1.0 - t) * (bar_width - 4.0)

		# Indicador en la división
		tug_indicator.position.x = 2.0 + t * (bar_width - 4.0) - tug_indicator.size.x / 2.0


func _update_side_stats(side: BattleFront.Side, label: RichTextLabel) -> void:
	var atk := battle_front.get_total_attack(side)
	var def := battle_front.get_total_defense(side)
	var pressure := battle_front.get_pressure(side)
	var troops_atk := battle_front.get_assigned_troops_attack(side)
	var troops_def := battle_front.get_assigned_troops_defense(side)
	var maint: Dictionary = battle_front.get_front_maintenance(side)

	# Multiplicador medio efectivo contra la composición enemiga.
	# Sirve para mostrar al jugador si su lineup está siendo super/no efectivo.
	var own_troops: Array[Troop] = battle_front.attacker_troops if side == BattleFront.Side.ATTACKER else battle_front.defender_troops
	var enemy_troops: Array[Troop] = battle_front.defender_troops if side == BattleFront.Side.ATTACKER else battle_front.attacker_troops
	var effective_troops_atk: float = TroopEffectiveness.get_effective_attack(own_troops, enemy_troops)
	var effectiveness_mult: float = 1.0
	if troops_atk > 0:
		effectiveness_mult = effective_troops_atk / float(troops_atk)

	label.text = ""
	label.append_text("[center]")
	# Totales (incluyen bioma, edificios y bonuses)
	label.append_text("[color=#cc3333]ATK: %.1f[/color]  [color=#3366cc]DEF: %.1f[/color]\n" % [atk, def])
	# Aporte sólo de las tropas asignadas, para que el jugador vea cuánto ha comprometido
	label.append_text("[color=#5a4838]%s[/color]\n" % (tr("BATTLE_TROOPS_LINE") % [troops_atk, troops_def]))
	# Indicador de efectividad por tipo (sólo si hay tropas que comparen)
	if troops_atk > 0 and not enemy_troops.is_empty():
		var color_hex: String = _effectiveness_color_hex(effectiveness_mult)
		label.append_text("[color=%s]%s[/color]\n" % [color_hex, tr("BATTLE_EFFECTIVENESS_LINE") % [effectiveness_mult, effective_troops_atk]])
	# Presión resultante (atk / (1 + def_enemiga))
	label.append_text("[color=#cccc33]%s[/color]\n" % (tr("BATTLE_PRESSURE_LINE") % pressure))
	# Coste de mantenimiento extra que el frente está consumiendo este turno
	label.append_text("[color=#7a4f2c]%s[/color]" % (tr("BATTLE_MAINTENANCE_LINE") % [maint.get("gold", 0), maint.get("food", 0)]))

	# Tácticas activas en este lado (cartas tácticas con tactic_name).
	var tactic_lines := _render_active_tactics(side)
	if not tactic_lines.is_empty():
		label.append_text("\n\n[color=#4A6A8A][b]%s[/b][/color]\n" % tr("BATTLE_ACTIVE_TACTICS"))
		for line in tactic_lines:
			label.append_text("%s\n" % line)

	label.append_text("[/center]")


## Construye una lista textual de las tácticas activas en el bando indicado.
## Cada línea muestra el nombre, los tipos afectados y los bonus efectivos
## (% y/o plano), incluyendo ya el modificador de bioma capturado.
func _render_active_tactics(side: BattleFront.Side) -> Array[String]:
	var bonuses: Array = battle_front.attacker_bonuses if side == BattleFront.Side.ATTACKER else battle_front.defender_bonuses
	var lines: Array[String] = []
	for bonus in bonuses:
		if bonus.tactic_name == "":
			continue  # No es una táctica con nombre — la ignoramos en este listado.
		var parts: Array[String] = []
		# Bonus efectivos (porcentaje × modificador de bioma capturado).
		if bonus.attack_percent_per_type != 0.0:
			parts.append("[color=#cc3333]+%.0f%% ATK (×%.2f)[/color]" % [bonus.attack_percent_per_type * bonus.attack_biome_modifier, bonus.attack_biome_modifier])
		if bonus.defense_percent_per_type != 0.0:
			parts.append("[color=#3366cc]+%.0f%% DEF (×%.2f)[/color]" % [bonus.defense_percent_per_type * bonus.defense_biome_modifier, bonus.defense_biome_modifier])
		# Bonus planos (raros) — también escalados.
		if bonus.attack_per_troop != 0.0:
			parts.append("[color=#cc3333]+%.1f ATK/tropa[/color]" % (bonus.attack_per_troop * bonus.attack_biome_modifier))
		if bonus.defense_per_troop != 0.0:
			parts.append("[color=#3366cc]+%.1f DEF/tropa[/color]" % (bonus.defense_per_troop * bonus.defense_biome_modifier))
		var detail: String = " · ".join(parts) if not parts.is_empty() else tr("BATTLE_NO_EFFECT")
		lines.append("• %s — %s" % [tr(bonus.tactic_name), detail])
	return lines


## Devuelve un código hex para colorear el multiplicador efectivo.
##  >1.05 → verde (super efectivo)
##  <0.95 → rojo  (no efectivo)
##   resto → gris  (neutro)
func _effectiveness_color_hex(mult: float) -> String:
	if mult > 1.05:
		return "#2e8b3e"
	if mult < 0.95:
		return "#a83030"
	return "#666666"


func _update_troops_display(troops: Array[Troop], container: VBoxContainer, color: Color) -> void:
	# Limpiar
	for child in container.get_children():
		child.queue_free()

	if troops.is_empty():
		var empty_label := Label.new()
		empty_label.text = tr("BATTLE_NO_TROOPS")
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", UITheme.DISABLED_MUTED)
		container.add_child(empty_label)
		return

	# Agrupar tropas por tipo
	var troop_counts: Dictionary = {}
	for troop in troops:
		if troop_counts.has(troop.name):
			troop_counts[troop.name]["count"] += 1
		else:
			troop_counts[troop.name] = { "troop": troop, "count": 1 }

	for entry in troop_counts.values():
		var troop: Troop = entry["troop"]
		var count: int = entry["count"]

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 4)
		container.add_child(hbox)

		if troop.icon:
			var icon := TextureRect.new()
			icon.texture = troop.icon
			icon.custom_minimum_size = Vector2(20, 20)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hbox.add_child(icon)

		var text := Label.new()
		text.text = "%s x%d (ATK:%d DEF:%d)" % [tr(troop.name), count, troop.attack, troop.defense]
		text.add_theme_color_override("font_color", color.darkened(0.3))
		hbox.add_child(text)


func _update_assign_button() -> void:
	if player_empire == null:
		assign_button.visible = false
		return

	var is_participant := (battle_front.attacker_empire == player_empire or \
		battle_front.defender_empire == player_empire)
	assign_button.visible = is_participant
	assign_button.disabled = battle_front.is_resolved


# --- Callbacks ---

func _on_marker_changed(front: BattleFront, _new_value: float) -> void:
	if front == battle_front:
		_update_display()


func _on_troop_assigned(front: BattleFront, _troop: Troop, _side: BattleFront.Side) -> void:
	if front == battle_front:
		_update_display()


func _on_bonus_applied(front: BattleFront, _side: BattleFront.Side) -> void:
	if front == battle_front:
		_update_display()


func _on_front_resolved(front: BattleFront, _attacker_won: bool) -> void:
	if front == battle_front:
		_update_display()
		assign_button.disabled = true


func _on_assign_pressed() -> void:
	assign_troop_requested.emit(battle_front)


func _on_close_pressed() -> void:
	panel_closed.emit()
	queue_free()


func _exit_tree() -> void:
	if UIState:
		UIState.unregister_menu()
	if Events.battle_front_marker_changed.is_connected(_on_marker_changed):
		Events.battle_front_marker_changed.disconnect(_on_marker_changed)
	if Events.troop_assigned_to_front.is_connected(_on_troop_assigned):
		Events.troop_assigned_to_front.disconnect(_on_troop_assigned)
	if Events.battle_front_resolved.is_connected(_on_front_resolved):
		Events.battle_front_resolved.disconnect(_on_front_resolved)
	if Events.battle_front_bonus_applied.is_connected(_on_bonus_applied):
		Events.battle_front_bonus_applied.disconnect(_on_bonus_applied)
