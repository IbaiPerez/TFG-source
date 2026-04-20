extends TurnEventCost
class_name ScaledGoldCost

## Coste de oro escalado: base + turno * turn_factor + gold_per_turn * gpt_percent
## Se evalua dinamicamente al comprobar can_pay y al pagar.

var base_gold:float
var turn_factor:float
var gpt_percent:float


func _init(p_base:float, p_turn_factor:float = 0.0, p_gpt_percent:float = 0.0):
	base_gold = p_base
	turn_factor = p_turn_factor
	gpt_percent = p_gpt_percent


func _calculate(context:EventContext) -> int:
	return int(base_gold + context.turn_number * turn_factor + context.gold_per_turn * gpt_percent)


func can_pay(context:EventContext) -> bool:
	return context.total_gold >= _calculate(context)


func pay(context:EventContext, _chosen_card:Card = null) -> void:
	context.stats.total_gold -= _calculate(context)
