extends ThresholdCondition
class_name CardTypeCountCondition

var card_type: Card.Type


func _init(p_type: Card.Type, p_count: int, p_op: Comparison.Type) -> void:
	super(p_count, p_op)
	card_type = p_type


func _value(context: EventContext) -> int:
	return int(context.card_count_by_type.get(card_type, 0))
