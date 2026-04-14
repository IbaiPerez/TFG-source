extends TurnEventCondition
class_name DeckSizeCondition

var count:int
var op:Comparison.Type


func _init(p_count:int, p_op:Comparison.Type):
	count = p_count
	op = p_op


func is_met(context:EventContext) -> bool:
	return Comparison.evaluate(context.cards_in_deck.size(), op, count)
