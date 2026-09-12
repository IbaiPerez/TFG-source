extends RefCounted
class_name TurnEventCost

var gold:int = 0


func can_pay(context:EventContext) -> bool:
	return context.total_gold >= gold


func pay(context:EventContext) -> void:
	context.stats.total_gold -= gold
