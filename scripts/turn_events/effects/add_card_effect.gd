extends TurnEventEffect
class_name AddCardEffect

var card:Card


func _init(p_card:Card):
	card = p_card


func execute(context:EventContext, _chosen_card:Card = null) -> void:
	var instance := card.duplicate()
	context.stats.sync_card_buildings(instance)
	context.stats.discard_pile.add_card(instance)
