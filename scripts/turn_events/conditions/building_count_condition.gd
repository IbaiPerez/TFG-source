extends ThresholdCondition
class_name BuildingCountCondition

## Cuenta el total de edificios construidos en casillas controladas y lo compara
## con el umbral.


func _value(context: EventContext) -> int:
	var total := 0
	for tile in context.controlled_tiles:
		total += tile.buildings.size()
	return total
