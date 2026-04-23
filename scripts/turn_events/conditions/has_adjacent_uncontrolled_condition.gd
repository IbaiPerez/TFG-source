extends TurnEventCondition
class_name HasAdjacentUncontrolledCondition

## Comprueba si existe al menos una casilla adyacente no controlada
## por el imperio. Filtro opcional por bioma.
## -1 = sin filtro de bioma.

var required_biome_type:int = -1


func _init(p_biome:int = -1):
	required_biome_type = p_biome


func is_met(context:EventContext) -> bool:
	for tile in context.controlled_tiles:
		for neighbor in tile.neighbors:
			if neighbor is Tile and neighbor.controller == null:
				if required_biome_type == -1 or neighbor.mesh_data.type == required_biome_type:
					return true
	return false
