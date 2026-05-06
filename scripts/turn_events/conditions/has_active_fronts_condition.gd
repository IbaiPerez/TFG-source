extends TurnEventCondition
class_name HasActiveFrontsCondition

## Comprueba si hay al menos un número determinado de frentes de batalla activos.

var min_count:int


func _init(p_min_count:int = 1):
	min_count = p_min_count


func is_met(context:EventContext) -> bool:
	return context.active_front_count >= min_count
