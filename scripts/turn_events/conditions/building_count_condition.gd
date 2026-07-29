extends ThresholdCondition
class_name BuildingCountCondition

## Cuenta el total de edificios construidos en casillas controladas y lo compara
## con el umbral. Lee los agregados de EventContext (C6 §1.6.2), no la escena, para
## poder evaluarse igual sobre el snapshot del MCTS.


func _value(context: EventContext) -> int:
	var total := 0
	for tf in context.tile_facts:
		total += tf.building_count
	return total
