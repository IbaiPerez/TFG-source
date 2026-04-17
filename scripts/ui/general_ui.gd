extends Control
class_name UI

@export var stats:Stats:set = _set_stats

@onready var end_turn_button: Button = %EndTurnButton
@onready var stats_ui: StatsUI = $StatsUI as StatsUI
@onready var tile_panel: TilePanel = $TilePanel
@onready var draw_pile_button: CardPileOpener = %DrawPileButton
@onready var discard_pile_button: CardPileOpener = %DiscardPileButton
@onready var draw_pile_view: CardPileView = %DrawPileView
@onready var discard_pile_view: CardPileView = %DiscardPileView
@onready var map_modes_buttons: VBoxContainer = %MapModesButtons


func _ready() -> void:
	Events.tile_selected.connect(_on_tile_selected)
	Events.tile_deselected.connect(_on_tile_deselected)
	Events.player_hand_drawn.connect(_on_player_hand_drawn)
	draw_pile_button.pressed.connect(draw_pile_view.show_current_view.bind("Draw Pile",true))
	discard_pile_button.pressed.connect(discard_pile_view.show_current_view.bind("Discard Pile"))
	tile_panel.visible = false
	_setup_map_mode_buttons()
	_connect_modifier_manager.call_deferred()


func _connect_modifier_manager() -> void:
	var player_handler:PlayerHandler = get_tree().get_first_node_in_group("player_handler")
	if player_handler and player_handler.modifier_manager:
		stats_ui.set_modifier_manager(player_handler.modifier_manager)

func _setup_map_mode_buttons() -> void:
	# Todos los botones del contenedor comparten el mismo ButtonGroup,
	# asi que basta con obtenerlo del primero y conectar su signal.
	var first_button:Button = map_modes_buttons.get_child(0) as Button
	if first_button and first_button.button_group:
		first_button.button_group.pressed.connect(_on_map_mode_button_pressed)

func initialize_card_pile_ui() -> void:
	draw_pile_button.card_pile = stats.draw_pile
	discard_pile_button.card_pile = stats.discard_pile
	draw_pile_view.card_pile = stats.draw_pile
	discard_pile_view.card_pile = stats.discard_pile

func _set_stats(value:Stats) -> void:
	stats = value
	stats.stats_changed.connect(_on_stats_changed)

func _on_stats_changed() -> void:
	stats_ui.update_stats(stats)

func _on_tile_selected(tile:Tile):
	tile_panel.tile = tile
	tile_panel.visible = true

func _on_tile_deselected():
	tile_panel.visible = false

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
