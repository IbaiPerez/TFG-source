extends Resource
class_name Empire

@export var name:String
@export var color:Color
var controlled_tiles:Array[Tile] = []

signal tile_conquered(tile:Tile)
signal tile_lost(tile:Tile)

func add_tile(tile:Tile):
	if tile not in controlled_tiles:
		controlled_tiles.append(tile)
		tile.set_controller(self)
		tile_conquered.emit(tile)

func remove_tile(tile:Tile):
	if tile in controlled_tiles:
		controlled_tiles.erase(tile)
		tile.set_controller(null)
		tile_lost.emit(tile)

func reset_controlled_tiles() -> void:
	controlled_tiles = []

func create_instance() -> Empire:
	var empire:Empire = self.duplicate()
	empire.name = name
	empire.color = color
	empire.controlled_tiles = []
	return empire
