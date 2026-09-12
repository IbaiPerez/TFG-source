extends RefCounted
class_name TurnEventCost

## Coste de oro de un choice de evento, escalado por turno y por producción:
##   base + turno · turn_factor + gold_per_turn · gpt_percent
## Se evalúa al comprobar can_pay y al pagar. Con los factores a 0 es un coste fijo.

var base_gold:float
var turn_factor:float
var gpt_percent:float


func _init(p_base:float = 0.0, p_turn_factor:float = 0.0, p_gpt_percent:float = 0.0):
	base_gold = p_base
	turn_factor = p_turn_factor
	gpt_percent = p_gpt_percent


func gold(context:EventContext) -> int:
	return int(ScaledValue.evaluate(base_gold, turn_factor, gpt_percent,
		context.turn_number, context.gold_per_turn))


func can_pay(context:EventContext) -> bool:
	return context.total_gold >= gold(context)


func pay(context:EventContext) -> void:
	context.stats.total_gold -= gold(context)
