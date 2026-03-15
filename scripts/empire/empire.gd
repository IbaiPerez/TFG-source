extends Resource
class_name Empire

@export var name:String
@export var color:Color
var controlled_tiles:Array[Tile] = []

func add_tile(tile:Tile):
	if tile not in controlled_tiles:
		controlled_tiles.append(tile)
		tile.set_controller(self)

func remove_tile(tile:Tile):
	if tile in controlled_tiles:
		controlled_tiles.erase(tile)
		tile.set_controller(null)

func reset_controlled_tiles() -> void:
	controlled_tiles = []
