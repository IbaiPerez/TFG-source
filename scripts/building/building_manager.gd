extends Node
class_name BuildingManager

@export var all_buildings: Array[Building] = []

func get_available_buildings(tile: Tile) -> Array[Building]:
	var available: Array[Building] = []
	for building in all_buildings:
		if tile.can_build(building):
			available.append(building)
	return available

func try_build(building: Building, tile: Tile, stats: Stats) -> void:
	tile.build(building, stats)

func try_demolish(building: Building, tile: Tile, stats: Stats) -> void:
	tile.demolish(building, stats)
