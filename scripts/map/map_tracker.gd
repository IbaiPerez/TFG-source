extends Node
class_name MapTracker

@export var tile_parent : Node3D

var current_mode:Events.map_mode = Events.map_mode.BiomesMode

func _ready() -> void:
	Events.change_map_mode.connect(_on_change_map_mode)
	Events.tile_controller_changed.connect(_on_tile_controller_changed)
	Events.tile_location_type_changed.connect(_on_tile_location_type_changed)

func _on_change_map_mode(mode: Events.map_mode) -> void:
	if current_mode == mode:
		return
	match mode:
		Events.map_mode.PoliticalMode:
			for child:Tile in WorldMap.map:
				child.set_empire_material()
			current_mode = Events.map_mode.PoliticalMode
		Events.map_mode.BiomesMode:
			for child:Tile in WorldMap.map:
				child.set_biome_material()
			current_mode = Events.map_mode.BiomesMode
		Events.map_mode.NaturalResourcesMode:
			for child:Tile in WorldMap.map:
				child.set_natural_resource_material()
			current_mode = Events.map_mode.NaturalResourcesMode
		Events.map_mode.LocationTypeMode:
			for child:Tile in WorldMap.map:
				child.set_location_type_material()
			current_mode = Events.map_mode.LocationTypeMode


func _on_tile_controller_changed(tile: Tile) -> void:
	if current_mode == Events.map_mode.PoliticalMode:
		tile.set_empire_material()


func _on_tile_location_type_changed(tile: Tile) -> void:
	if current_mode == Events.map_mode.LocationTypeMode:
		tile.set_location_type_material()
