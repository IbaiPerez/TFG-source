extends ThresholdCondition
class_name TurnNumberCondition


func _value(context: EventContext) -> int:
	return context.turn_number
