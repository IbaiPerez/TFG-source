extends Resource
class_name TileMeshData

@export var mesh : PackedScene
@export var color : Color
@export var type : Tile.biome_type
## Opcional: textura de detalle (media gris 0.5, se tiñe con `color`) y su normal
## map. Sin ella, la casilla usa el patrón procedural del shader.
@export var detail_texture : Texture2D
@export var normal_texture : Texture2D
