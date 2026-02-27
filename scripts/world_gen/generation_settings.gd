extends Resource
class_name GenerationSettings

enum shape {HEXAGONAL, RECTANGULAR, DIAMOND, CIRCLE}

@export_category("Tiles")
@export var tiles : Array[TileMeshData]
@export var biome_weights : Array[float]
@export var tile_size : float = 1 #Scalar for different size tiles, leave at 1 if not using your own mesh
@export var debug = false

@export_category("Generation")
@export var map_seed : int
@export var map_shape : shape = shape.HEXAGONAL
@export_range(0, 99, 1) var radius: int = 8
@export var biome_noise : FastNoiseLite

@export_category("Hills")
@export var create_mountains = true
@export var mountain_tile:TileMeshData
@export_range(0.0, 1.0) var mountain_treshold = 0.6
@export var mountain_noise : FastNoiseLite

@export_category("Water/Ocean")
@export var create_water = true
@export var ocean_tile : TileMeshData
@export var outer_buffer:int = 1
@export var inner_buffer:int = 4
@export var ocean_noise:FastNoiseLite
@export_range(.0,1) var ocean_treshold = .6

@export_category("Empires")
@export var player_empire:Empire
@export var empires:Array[Empire] = []

@export_category("Natural Resources")
@export var natural_resources:Array[NaturalResource]
