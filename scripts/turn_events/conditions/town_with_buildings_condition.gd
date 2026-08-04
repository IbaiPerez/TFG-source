extends TurnEventCondition
class_name TownWithBuildingsCondition

## Comprueba que exista al menos una Town con un minimo de edificios construidos.
## Lee los agregados de EventContext.

var min_buildings: int
var op: Comparison.Type


func _init(p_min_buildings: int, p_op: Comparison.Type):
	min_buildings = p_min_buildings
	op = p_op


func is_met(context: EventContext) -> bool:
	for tf in context.tile_facts:
		if tf.location_type == Tile.location_type.Town:
			if Comparison.evaluate(tf.building_count, op, min_buildings):
				return true
	return false
