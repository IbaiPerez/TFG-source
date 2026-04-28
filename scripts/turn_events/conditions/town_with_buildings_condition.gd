extends TurnEventCondition
class_name TownWithBuildingsCondition

## Comprueba que exista al menos una Town con un mínimo de edificios construidos.

var min_buildings: int
var op: Comparison.Type


func _init(p_min_buildings: int, p_op: Comparison.Type):
	min_buildings = p_min_buildings
	op = p_op


func is_met(context: EventContext) -> bool:
	for tile in context.controlled_tiles:
		if tile.location.type == Tile.location_type.Town:
			if Comparison.evaluate(tile.buildings.size(), op, min_buildings):
				return true
	return false
