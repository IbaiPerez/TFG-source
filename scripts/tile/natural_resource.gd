extends Resource
class_name NaturalResource

@export var name:String
@export var image:Texture2D
@export var color:Color
@export var biomes:Dictionary[Tile.biome_type,float] = {Tile.biome_type.Grassland:1,
														Tile.biome_type.Forest:1,
														Tile.biome_type.Desert:1,
														Tile.biome_type.Swamp:1,
														Tile.biome_type.Tundra:1,
														Tile.biome_type.Ocean:1,
														Tile.biome_type.Mountain:1}
