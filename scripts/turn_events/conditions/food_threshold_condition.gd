extends ThresholdCondition
class_name FoodThresholdCondition


func _value(context: EventContext) -> int:
	return context.food
