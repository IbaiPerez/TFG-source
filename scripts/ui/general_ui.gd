extends Control
class_name UI

@export var stats:Stats:set = _set_stats

@onready var tile_info: HBoxContainer = %TileInfo
@onready var biome: Label = %Biome
@onready var natural_resource: Label = %NaturalResource
@onready var controller: Label = %Controller
@onready var location_type: Label = %LocationType
@onready var end_turn_button: Button = %EndTurnButton
@onready var stats_ui: StatsUI = $StatsUI as StatsUI


func _ready() -> void:
	Events.tile_selected.connect(_on_tile_selected)
	Events.tile_deselected.connect(_on_tile_deselected)
	Events.player_hand_drawn.connect(_on_player_hand_drawn)
	tile_info.visible = false
	await get_tree().create_timer(4).timeout
	stats.set_gold_per_turn(12)

func _set_stats(value:Stats) -> void:
	stats = value
	stats.stats_changed.connect(_on_stats_changed)

func _on_stats_changed() -> void:
	stats_ui.update_stats(stats)

func _on_tile_selected(tile:Tile):
	biome.text = tile.biome
	natural_resource.text = tile.natural_resource.name
	controller.text = tile.controller.name if tile.controller else "No controller"
	location_type.text = Tile.location_type.find_key(tile.location.type)
	tile_info.visible = true

func _on_tile_deselected():
	tile_info.visible = false


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
	end_turn_button.disabled = false
	Events.player_turn_ended.emit()
