extends ThresholdCondition
class_name GoldGenerationCondition


func _value(context: EventContext) -> int:
	return context.gold_per_turn
