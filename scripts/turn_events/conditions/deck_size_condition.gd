extends ThresholdCondition
class_name DeckSizeCondition


func _value(context: EventContext) -> int:
	return context.cards_in_deck.size()
