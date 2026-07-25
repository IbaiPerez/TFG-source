extends ThresholdCondition
class_name GoldThresholdCondition


func _value(context: EventContext) -> int:
	return context.total_gold
