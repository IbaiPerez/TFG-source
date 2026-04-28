extends TurnEventCondition
class_name MinGoldCondition

## Comprueba que el jugador tenga al menos una cantidad mínima de oro.

var amount: int


func _init(p_amount: int):
	amount = p_amount


func is_met(context: EventContext) -> bool:
	return context.total_gold >= amount
