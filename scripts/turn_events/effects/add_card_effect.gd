extends TurnEventEffect
class_name AddCardEffect

var card:Card


func _init(p_card:Card):
	card = p_card


func execute(context:EventContext, _chosen_card:Card = null) -> void:
	context.stats.discard_pile.add_card(card.duplicate())
