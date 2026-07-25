extends ThresholdCondition
class_name ControlledTilesCondition

## Filtros opcionales
var required_resource: NaturalResource = null
## -1 = sin filtro, si no, un valor de Tile.biome_type
var required_biome_type: int = -1
## -1 = sin filtro, si no, un valor de Tile.location_type
var required_location_type: int = -1


func _init(p_count: int, p_op: Comparison.Type,
		p_resource: NaturalResource = null,
		p_biome: int = -1,
		p_location: int = -1) -> void:
	super(p_count, p_op)
	required_resource = p_resource
	required_biome_type = p_biome
	required_location_type = p_location


func _value(context: EventContext) -> int:
	var matching := 0
	for tile in context.controlled_tiles:
		if _tile_matches(tile):
			matching += 1
	return matching


func _tile_matches(tile: Tile) -> bool:
	if required_resource != null and tile.natural_resource != required_resource:
		return false
	if required_biome_type != -1 and tile.mesh_data.type != required_biome_type:
		return false
	if required_location_type != -1 and tile.location.type != required_location_type:
		return false
	return true
