extends TurnEventEffect
class_name ColonizeAdjacentEffect

## Coloniza automáticamente una casilla adyacente no controlada.
## Prioriza casillas del bioma indicado. Si no hay, coloniza cualquier adyacente.
## -1 = sin preferencia de bioma.

var preferred_biome:int = -1


func _init(p_biome:int = -1):
	preferred_biome = p_biome


func execute(context:EventContext, _chosen_card:Card = null) -> void:
	var target := _find_target(context)
	if target:
		Events.change_tile_controller.emit(target, context.stats.empire)


func _find_target(context:EventContext) -> Tile:
	var candidates:Array[Tile] = []
	var preferred:Array[Tile] = []

	for tile in context.controlled_tiles:
		for neighbor in tile.neighbors:
			if neighbor is Tile and neighbor.controller == null:
				if neighbor not in candidates:
					candidates.append(neighbor)
					if preferred_biome != -1 and neighbor.mesh_data.type == preferred_biome:
						preferred.append(neighbor)

	if not preferred.is_empty():
		return preferred.pick_random()
	if not candidates.is_empty():
		return candidates.pick_random()
	return null
