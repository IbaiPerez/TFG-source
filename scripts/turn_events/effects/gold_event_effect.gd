extends TurnEventEffect
class_name GoldEventEffect

var amount:int


func _init(p_amount:int):
	amount = p_amount


func execute(context:EventContext, _chosen_card:Card = null) -> void:
	context.stats.total_gold += amount
