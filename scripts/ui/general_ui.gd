extends Control
class_name UI

@export var stats:Stats:set = _set_stats

@onready var end_turn_button: Button = %EndTurnButton
@onready var stats_ui: StatsUI = $StatsUI as StatsUI
@onready var tile_panel: TilePanel = $TilePanel
@onready var building_panel: BuildingPanel = $BuildingPanel


func _ready() -> void:
	Events.tile_selected.connect(_on_tile_selected)
	Events.tile_deselected.connect(_on_tile_deselected)
	Events.player_hand_drawn.connect(_on_player_hand_drawn)
	Events.try_to_build.connect(_on_try_to_build)
	tile_panel.visible = false
	building_panel.visible = false

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

func _on_political_mode_button_pressed() -> void:
	Events.change_map_mode.emit(Events.map_mode.PoliticalMode)

func _on_biomes_mode_button_pressed() -> void:
	Events.change_map_mode.emit(Events.map_mode.BiomesMode)


func _on_natural_resources_biome_button_pressed() -> void:
	Events.change_map_mode.emit(Events.map_mode.NaturalResourcesMode)


func _on_location_type_mode_button_pressed() -> void:
	Events.change_map_mode.emit(Events.map_mode.LocationTypeMode)

func _on_player_hand_drawn() -> void:
	end_turn_button.disabled = false

func _on_end_turn_button_pressed() -> void:
	end_turn_button.disabled = true
	Events.player_turn_ended.emit()

func _on_try_to_build(tile:Tile,buildings:Array[Building]) -> void:
	building_panel.stats = stats
	building_panel.tile = tile
	building_panel.buildings = buildings
	
	building_panel.visible = true
