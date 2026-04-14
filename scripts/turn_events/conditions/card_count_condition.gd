extends TurnEventCondition
class_name CardCountCondition

var card_id:String
var count:int
var op:Comparison.Type


func _init(p_card_id:String, p_count:int, p_op:Comparison.Type):
	card_id = p_card_id
	count = p_count
	op = p_op


func is_met(context:EventContext) -> bool:
	var actual = context.card_count_by_id.get(card_id, 0)
	return Comparison.evaluate(actual, op, count)
