extends TurnEventEffect
class_name ScaledGoldEffect

## Efecto de oro escalado: base + turno * turn_factor + gold_per_turn * gpt_percent
## Valores negativos para penalizaciones.

var base:float
var turn_factor:float
var gpt_percent:float  ## porcentaje de gold_per_turn (0.0 a 1.0)


func _init(p_base:float, p_turn_factor:float = 0.0, p_gpt_percent:float = 0.0):
	base = p_base
	turn_factor = p_turn_factor
	gpt_percent = p_gpt_percent


func execute(context:EventContext, _chosen_card:Card = null) -> void:
	var amount := int(ScaledValue.evaluate(base, turn_factor, gpt_percent,
		context.turn_number, context.gold_per_turn))
	context.stats.total_gold += amount
