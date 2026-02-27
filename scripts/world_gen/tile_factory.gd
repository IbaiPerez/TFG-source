extends Node
class_name TileFactory

const TILE_SCRIPT = preload("uid://dasqw0u0jgxcf")
const HEX_TILE_COLLIDER = preload("uid://4061dgx0wwr5")
const UNCOLONIZED = preload("uid://3sm1dn2lvvcf")


# Variables
var settings : GenerationSettings
var tile_parent : Node3D


func init_factory(in_settings : GenerationSettings, in_tile_parent : Node3D):
	settings = in_settings
	tile_parent = in_tile_parent

# Main function, instantiate the map and returns it
func create_map(map_data : MappingData) -> Array[Tile]:
	var new_map : Array[Tile] = []
	## Calculate weights for choosing tiles/biomes
	var weights = calculate_biome_weights()
	var total = 0.0
	for w in settings.biome_weights:
		total += w
	
	## Generate the tiles
	for pos in map_data.positions:
		var new_tile:Tile
		if pos.water:
			new_tile = instantiate_ocean_tile()
		elif pos.mountain:
			new_tile = instantiate_mountain_tile()
		else:
			var biome = select_biome(pos.noise, weights, total, map_data.noise_data)
			new_tile = instantiate_tile(biome)
		
		init_tile(new_tile, pos)
		new_map.append(new_tile)
		debug_tile(new_tile, pos)
	
	print("Tiles placed: " + str(new_map.size()))
	return new_map

## Function to select a biome based on weighted probabilities
func select_biome(local_noise: float, weights: Array[float], total: float, noisedata: Vector2) -> int:
	# Normalize the noise value to the total weight range
	var normalized_noise = ((local_noise - noisedata.x) / (noisedata.y - noisedata.x)) * total
	# Determine the selected biome
	var selected_biome = 0
	for i in range(weights.size()):
		if normalized_noise < weights[i]:
			selected_biome = i
			break
	return selected_biome


## Function to instantiate a tile based on the selected biome
func instantiate_tile(selected_biome: int) -> Tile:
	# Get the biome data from settings
	var data = settings.tiles[selected_biome]
	
	# Instantiate the biome mesh
	var biome = data.mesh
	var t = biome.instantiate()
	
	# Set up the tile
	t.set_script(TILE_SCRIPT)
	t.mesh_data = data
	return t as Tile

func instantiate_mountain_tile():
	var tile = settings.mountain_tile.mesh.instantiate()
	
	# Set up the tile
	tile.set_script(TILE_SCRIPT)
	tile.mesh_data = settings.mountain_tile
	
	return tile as Tile

func instantiate_ocean_tile():
	var tile = settings.ocean_tile.mesh.instantiate()
	
	# Set up the tile
	tile.set_script(TILE_SCRIPT)
	tile.mesh_data = settings.ocean_tile
	
	return tile as Tile

## Add tile script, add to group, position and parent
func init_tile(tile : Tile, position : PositionData):
	if not tile.is_in_group("tiles"):
		tile.add_to_group("tiles")

	#Add collider
	var col = HEX_TILE_COLLIDER.instantiate()
	tile.add_child(col)
	col.position = tile.position


	tile.position = position.world_position
	tile_parent.add_child(tile)
	tile.pos_data = position
	tile.biome = Tile.biome_type.find_key(tile.mesh_data.type)
	tile.location = UNCOLONIZED
	var treshold:float = randf()
	tile.natural_resource = settings.natural_resources.filter(func(natural_resource:NaturalResource)->bool: 
		return natural_resource.biomes[tile.mesh_data.type] <= treshold ).pick_random()
	tile.set_parameters()


func calculate_biome_weights() -> Array[float]:
	var sum = 0.0
	var cumulative_weights : Array[float]
	for weight in settings.biome_weights:
		sum += weight
		cumulative_weights.append(sum)
	return cumulative_weights

##Debug and test stuff. Add Labels to show coordinates
func debug_tile(tile : Tile, position : PositionData):
	if not settings.debug:
		return
	#Add a label
	var label = Label3D.new()
	tile.add_child(label)
	label.text = str(position.grid_position.x) + ", " + str(position.grid_position.y)
	label.text += "\n" + str(-position.grid_position.x - position.grid_position.y)
	label.text += "\n" + str(tile.pos_data.world_position) 
	label.text += "\n" + tile.natural_resource.name
	label.position.y += 0.4
	tile.debug_label = label
