extends ThresholdCondition
class_name CardCountCondition

var card_id: String


func _init(p_card_id: String, p_count: int, p_op: Comparison.Type) -> void:
	super(p_count, p_op)
	card_id = p_card_id


func _value(context: EventContext) -> int:
	return int(context.card_count_by_id.get(card_id, 0))
