extends Node

const MEGALOPOLIS = preload("uid://cd0fssryl0wg2")
const TOWN = preload("uid://ds43pvf8s117e")
const UNCOLONIZED = preload("uid://3sm1dn2lvvcf")
const VILLAGE = preload("uid://dg0go8h0lbyaw")

func _ready() -> void:
	Events.change_tile_controller.connect(_on_change_tile_controller)
	Events.change_tile_location_type.connect(_on_change_location_type)

func update_all_borders() -> void:
	for tile in WorldMap.map:
		tile.update_borders()

func _on_change_tile_controller(tile: Tile, new_controller: Empire) -> void:
	if tile.controller:
		tile.controller.remove_tile(tile)
	
	if new_controller:
		new_controller.add_tile(tile)
	
	if tile.location.type == Tile.location_type.Uncolonized:
		_on_change_location_type(tile,VILLAGE)
	
	tile.update_borders()
	for neighbor in tile.neighbors:
		if neighbor:
			neighbor.update_borders()
	Events.tile_controller_changed.emit(tile)

func _on_change_location_type(tile: Tile, new_location_type:LocationType):
	if new_location_type:
		tile.set_location_type(new_location_type)
	Events.tile_location_type_changed.emit(tile)
