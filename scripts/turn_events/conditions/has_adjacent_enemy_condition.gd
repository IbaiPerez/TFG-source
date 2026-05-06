extends TurnEventCondition
class_name HasAdjacentEnemyCondition

## Comprueba si el imperio controla al menos una casilla
## adyacente a una casilla de otro imperio.


func is_met(context:EventContext) -> bool:
	return context.has_adjacent_enemy
