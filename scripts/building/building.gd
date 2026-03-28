extends Resource
class_name Building


@export var name:String
@export var required_natural_resource:NaturalResource
@export var allowed_location_type:Array[LocationType]
@export var allowed_biomes:Array[Tile.biome_type]
@export var image:Texture2D
@export var construction_cost:int
@export var gold_produced:int
@export var food_produced:int
@export var effects:Array[BuildingEffect]
