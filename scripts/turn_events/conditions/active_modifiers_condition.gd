extends ThresholdCondition
class_name ActiveModifiersCondition


func _value(context: EventContext) -> int:
	return context.active_modifier_count
