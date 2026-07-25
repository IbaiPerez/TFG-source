extends TurnEventEffect
class_name ScaledFoodEffect

## Efecto de comida escalado: base + turno * turn_factor + food * food_percent
## Valores negativos para penalizaciones.

var base:float
var turn_factor:float
var food_percent:float  ## porcentaje de food actual (0.0 a 1.0)


func _init(p_base:float, p_turn_factor:float = 0.0, p_food_percent:float = 0.0):
	base = p_base
	turn_factor = p_turn_factor
	food_percent = p_food_percent


func execute(context:EventContext, _chosen_card:Card = null) -> void:
	var amount := int(ScaledValue.evaluate(base, turn_factor, food_percent,
		context.turn_number, context.food))
	context.stats.food += amount
