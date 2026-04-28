extends TurnEventCondition
class_name UrbanizedTilesCondition

## Comprueba si el número de casillas urbanizadas (Town o Megalopolis)
## cumple la comparación dada.

var count:int
var op:Comparison.Type


func _init(p_count:int, p_op:Comparison.Type):
	count = p_count
	op = p_op


func is_met(context:EventContext) -> bool:
	var matching := 0
	for tile in context.controlled_tiles:
		if tile.location.type >= Tile.location_type.Town:
			matching += 1
	return Comparison.evaluate(matching, op, count)
