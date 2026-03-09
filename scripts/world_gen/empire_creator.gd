extends Node
class_name EmpireCreator

var settings : GenerationSettings
var possible_tiles : Array[Tile] = []

func init_creator(_in_settings:GenerationSettings):
	settings = _in_settings

func create_empires():
	for tile in WorldMap.map:
		if tile.pos_data.buffer and tile.biome != "Ocean" and tile.natural_resource.food_produced > 0:
			possible_tiles.append(tile)
	
	var player_initial_tile:Tile = possible_tiles.pick_random()
	Events.change_tile_controller.emit(player_initial_tile,settings.player_empire)
	
	var ia_tiles = []
	for tile in possible_tiles:
		var c_diff = abs(player_initial_tile.pos_data.grid_position.x - tile.pos_data.grid_position.x)
		var r_diff = abs(player_initial_tile.pos_data.grid_position.y - tile.pos_data.grid_position.y)
		var delta = abs((player_initial_tile.pos_data.grid_position.x + player_initial_tile.pos_data.grid_position.y) - (tile.pos_data.grid_position.x + tile.pos_data.grid_position.y))
		var ring_distance = max(c_diff, r_diff, delta)
		if ring_distance > settings.radius:
			ia_tiles.append(tile)
	
	var ia_initial_tile = ia_tiles.pick_random()
	Events.change_tile_controller.emit(ia_initial_tile,settings.empires.pick_random())
