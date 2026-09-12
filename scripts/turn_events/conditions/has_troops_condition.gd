extends ThresholdCondition
class_name HasTroopsCondition

## Al menos `threshold` tropas reclutadas en el pool.


func _init(p_min_count:int = 1) -> void:
	super(p_min_count)


func _value(context: EventContext) -> int:
	return context.troop_pool_size
