extends TurnEventCondition
class_name TurnNumberCondition

var threshold:int
var op:Comparison.Type


func _init(p_threshold:int, p_op:Comparison.Type):
	threshold = p_threshold
	op = p_op


func is_met(context:EventContext) -> bool:
	return Comparison.evaluate(context.turn_number, op, threshold)
