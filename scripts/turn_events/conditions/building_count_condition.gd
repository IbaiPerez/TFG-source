extends TurnEventCondition
class_name BuildingCountCondition

## Comprueba si el número total de edificios construidos en casillas
## controladas cumple la comparación dada.

var count:int
var op:Comparison.Type


func _init(p_count:int, p_op:Comparison.Type):
	count = p_count
	op = p_op


func is_met(context:EventContext) -> bool:
	var total := 0
	for tile in context.controlled_tiles:
		total += tile.buildings.size()
	return Comparison.evaluate(total, op, count)
