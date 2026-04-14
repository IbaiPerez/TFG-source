extends TurnEventCondition
class_name CardTypeCountCondition

var card_type:Card.Type
var count:int
var op:Comparison.Type


func _init(p_type:Card.Type, p_count:int, p_op:Comparison.Type):
	card_type = p_type
	count = p_count
	op = p_op


func is_met(context:EventContext) -> bool:
	var actual = context.card_count_by_type.get(card_type, 0)
	return Comparison.evaluate(actual, op, count)
