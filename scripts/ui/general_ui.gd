extends Control
class_name UI

@export var stats:Stats:set = _set_stats
## Stats del rival. Se asigna desde UILayer → map.gd después de crear la IA.
## No usa @export: no hay valor por defecto sensato en el inspector.
var rival_stats: Stats: set = _set_rival_stats

@onready var end_turn_button: Button = %EndTurnButton
@onready var stats_ui: StatsUI = $StatsUI as StatsUI
@onready var rival_dropdown: RivalStatsUI = %RivalDropdown as RivalStatsUI
@onready var tile_panel: TilePanel = $TilePanel
@onready var ai_action_log: AIActionLog = %AIActionLog
@onready var draw_pile_button: CardPileOpener = %DrawPileButton
@onready var discard_pile_button: CardPileOpener = %DiscardPileButton
@onready var played_pile_button: CardPileOpener = %PlayedPileButton
@onready var draw_pile_view: CardPileView = %DrawPileView
@onready var discard_pile_view: CardPileView = %DiscardPileView
@onready var played_pile_view: CardPileView = %PlayedPileView
@onready var troop_pool_view: TroopPoolView = %TroopPoolView
@onready var map_modes_buttons: VBoxContainer = %MapModesButtons

## Tween para las animaciones de posición del TilePanel.
var _tile_tween: Tween
## Tween exclusivo del AIActionLog (fade in/out). Nunca llama a hide()/show()
## para evitar condiciones de carrera con callbacks de tweens anteriores.
var _log_tween: Tween
## True si el TilePanel está abierto o abriéndose. Evita que tile_deselected
## lance la animación de cierre cuando no hay ninguna tile seleccionada.
var _tile_panel_is_open: bool = false

## Offsets del TilePanel cuando está completamente visible (izquierda de pantalla).
const _PANEL_LEFT_SHOWN  := 0.0
const _PANEL_RIGHT_SHOWN := 280.0

## Offsets del TilePanel cuando está completamente fuera de pantalla (hacia la izquierda).
const _PANEL_LEFT_HIDDEN  := -290.0
const _PANEL_RIGHT_HIDDEN := -10.0

const _ANIM_DURATION := 0.22


func _ready() -> void:
	Events.tile_selected.connect(_on_tile_selected)
	Events.tile_deselected.connect(_on_tile_deselected)
	Events.player_hand_drawn.connect(_on_player_hand_drawn)
	stats_ui.rival_info_button.pressed.connect(_on_rival_info_button_pressed)
	draw_pile_button.pressed.connect(draw_pile_view.show_current_view.bind("CARDPILE_DRAW_TITLE", true))
	discard_pile_button.pressed.connect(discard_pile_view.show_current_view.bind("CARDPILE_DISCARD_TITLE"))
	played_pile_button.pressed.connect(played_pile_view.show_current_view.bind("CARDPILE_PLAYED_TITLE"))
	stats_ui.troop_pool_button.pressed.connect(troop_pool_view.show_current_view.bind("TROOPPOOL_TITLE"))
	tile_panel.visible = false
	_setup_map_mode_buttons()
	_connect_modifier_manager.call_deferred()


func _connect_modifier_manager() -> void:
	var player_handler:PlayerHandler = get_tree().get_first_node_in_group("player_handler")
	if player_handler and player_handler.modifier_manager:
		stats_ui.set_modifier_manager(player_handler.modifier_manager)


func _setup_map_mode_buttons() -> void:
	var first_button:Button = map_modes_buttons.get_child(0) as Button
	if first_button and first_button.button_group:
		first_button.button_group.pressed.connect(_on_map_mode_button_pressed)

	var descriptions := {
		"PoliticalModeButton":         "MAPMODE_POLITICAL_TIP",
		"BiomesModeButton":            "MAPMODE_BIOMES_TIP",
		"NaturalResourcesBiomeButton": "MAPMODE_RESOURCES_TIP",
		"LocationTypeModeButton":      "MAPMODE_LOCATION_TIP",
	}

	# tooltip_text de Godot usa coordenadas físicas de pantalla, incompatibles
	# con canvas_items stretch mode (viewport virtual 1280x720). Se usa un panel
	# custom top_level=true que opera en coordenadas virtuales como el resto de la UI.
	var tooltip_panel := PanelContainer.new()
	tooltip_panel.visible = false
	tooltip_panel.top_level = true
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.z_index = 100
	tooltip_panel.custom_minimum_size = Vector2(200, 0)
	tooltip_panel.add_theme_stylebox_override("panel", UITheme.make_panel_style())
	var tooltip_margin := MarginContainer.new()
	tooltip_margin.add_theme_constant_override("margin_left", 10)
	tooltip_margin.add_theme_constant_override("margin_top", 8)
	tooltip_margin.add_theme_constant_override("margin_right", 10)
	tooltip_margin.add_theme_constant_override("margin_bottom", 8)
	tooltip_panel.add_child(tooltip_margin)
	var tooltip_label := Label.new()
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_label.add_theme_color_override("font_color", UITheme.TEXT_DARK)
	tooltip_label.add_theme_font_size_override("font_size", 13)
	tooltip_margin.add_child(tooltip_label)
	add_child(tooltip_panel)

	for button in map_modes_buttons.get_children():
		if not (button is Button) or not descriptions.has(button.name):
			continue
		var btn := button as Button
		var desc: String = descriptions[btn.name]
		btn.mouse_entered.connect(func() -> void:
			tooltip_label.text = tr(desc)
			tooltip_panel.show()
			await get_tree().process_frame
			var vp := get_viewport_rect().size
			var pos := btn.global_position
			var x := clampf(pos.x - tooltip_panel.size.x - 8, 0.0, vp.x - tooltip_panel.size.x)
			var y := clampf(pos.y, 0.0, vp.y - tooltip_panel.size.y)
			tooltip_panel.global_position = Vector2(x, y)
		)
		btn.mouse_exited.connect(func() -> void:
			tooltip_panel.hide()
		)


func initialize_card_pile_ui() -> void:
	draw_pile_button.card_pile = stats.draw_pile
	discard_pile_button.card_pile = stats.discard_pile
	played_pile_button.card_pile = stats.played_pile
	draw_pile_view.card_pile = stats.draw_pile
	discard_pile_view.card_pile = stats.discard_pile
	played_pile_view.card_pile = stats.played_pile
	stats_ui.troop_pool_button.stats = stats
	troop_pool_view.stats = stats
	tile_panel.stats = stats


func _set_stats(value:Stats) -> void:
	stats = value
	stats.stats_changed.connect(_on_stats_changed)


func _on_stats_changed() -> void:
	stats_ui.update_stats(stats)


func _set_rival_stats(value: Stats) -> void:
	if rival_stats != null and rival_stats.stats_changed.is_connected(_on_rival_stats_changed):
		rival_stats.stats_changed.disconnect(_on_rival_stats_changed)
	rival_stats = value
	if rival_stats == null:
		return
	rival_stats.stats_changed.connect(_on_rival_stats_changed)
	if is_node_ready():
		var empire_name := rival_stats.empire.name if rival_stats.empire else "GENERIC_RIVAL"
		stats_ui.show_rival_toggle(empire_name)
		rival_dropdown.update_stats(rival_stats)


func _on_rival_stats_changed() -> void:
	rival_dropdown.update_stats(rival_stats)


func _on_rival_info_button_pressed() -> void:
	if rival_dropdown.visible:
		var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t.tween_property(rival_dropdown, "modulate:a", 0.0, 0.15)
		t.tween_callback(func() -> void: rival_dropdown.visible = false)
		stats_ui.rival_info_button.text = tr(
			rival_stats.empire.name if rival_stats and rival_stats.empire else "GENERIC_RIVAL"
		) + " ▾"
	else:
		rival_dropdown.modulate.a = 0.0
		rival_dropdown.visible = true
		var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(rival_dropdown, "modulate:a", 1.0, 0.18)
		stats_ui.rival_info_button.text = tr(
			rival_stats.empire.name if rival_stats and rival_stats.empire else "GENERIC_RIVAL"
		) + " ▴"


func _on_tile_selected(tile:Tile) -> void:
	if get_tree().paused:
		return
	tile_panel.tile = tile
	_animate_tile_panel_open()


func _on_tile_deselected() -> void:
	if get_tree().paused:
		return
	# Evitar que el evento dispare el cierre si no hay ninguna tile abierta.
	if not _tile_panel_is_open:
		return
	_animate_tile_panel_close()


## Desliza el TilePanel desde fuera de pantalla (izquierda) hasta su posición
## normal. Desvanece el AIActionLog solo con modulate.a — nunca con hide()/show()
## para evitar condiciones de carrera con callbacks de tweens anteriores.
func _animate_tile_panel_open() -> void:
	_tile_panel_is_open = true
	if _tile_tween:
		_tile_tween.kill()
	if _log_tween:
		_log_tween.kill()

	tile_panel.offset_left  = _PANEL_LEFT_HIDDEN
	tile_panel.offset_right = _PANEL_RIGHT_HIDDEN
	tile_panel.visible = true

	_tile_tween = create_tween().set_parallel(true)
	_tile_tween.set_trans(Tween.TRANS_CUBIC)
	_tile_tween.tween_property(tile_panel, "offset_left",  _PANEL_LEFT_SHOWN,  _ANIM_DURATION).set_ease(Tween.EASE_OUT)
	_tile_tween.tween_property(tile_panel, "offset_right", _PANEL_RIGHT_SHOWN, _ANIM_DURATION).set_ease(Tween.EASE_OUT)

	_log_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_log_tween.tween_property(ai_action_log, "modulate:a", 0.0, _ANIM_DURATION * 0.65)


## Desliza el TilePanel hacia fuera de pantalla (izquierda) y devuelve el
## AIActionLog con un fundido de entrada simultáneo.
func _animate_tile_panel_close() -> void:
	_tile_panel_is_open = false
	if _tile_tween:
		_tile_tween.kill()
	if _log_tween:
		_log_tween.kill()

	_tile_tween = create_tween().set_parallel(true)
	_tile_tween.set_trans(Tween.TRANS_CUBIC)
	_tile_tween.tween_property(tile_panel, "offset_left",  _PANEL_LEFT_HIDDEN,  _ANIM_DURATION).set_ease(Tween.EASE_IN)
	_tile_tween.tween_property(tile_panel, "offset_right", _PANEL_RIGHT_HIDDEN, _ANIM_DURATION).set_ease(Tween.EASE_IN)
	_tile_tween.chain().tween_callback(func() -> void:
		tile_panel.visible = false
		tile_panel.offset_left  = _PANEL_LEFT_SHOWN
		tile_panel.offset_right = _PANEL_RIGHT_SHOWN
	)

	_log_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_log_tween.tween_property(ai_action_log, "modulate:a", 1.0, _ANIM_DURATION)


func _on_map_mode_button_pressed(button:BaseButton) -> void:
	match button.name:
		"PoliticalModeButton":
			Events.change_map_mode.emit(Events.map_mode.PoliticalMode)
		"BiomesModeButton":
			Events.change_map_mode.emit(Events.map_mode.BiomesMode)
		"NaturalResourcesBiomeButton":
			Events.change_map_mode.emit(Events.map_mode.NaturalResourcesMode)
		"LocationTypeModeButton":
			Events.change_map_mode.emit(Events.map_mode.LocationTypeMode)


func _on_player_hand_drawn() -> void:
	end_turn_button.disabled = false


func _on_end_turn_button_pressed() -> void:
	end_turn_button.disabled = true
	Events.player_turn_ended.emit()
