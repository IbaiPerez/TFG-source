extends TurnEventCondition
class_name HasTroopsCondition

## Comprueba si el jugador tiene al menos un número determinado de tropas reclutadas.

var min_count:int


func _init(p_min_count:int = 1):
	min_count = p_min_count


func is_met(context:EventContext) -> bool:
	return context.troop_pool_size >= min_count
