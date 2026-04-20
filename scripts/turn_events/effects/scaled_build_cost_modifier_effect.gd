extends TurnEventEffect
class_name ScaledBuildCostModifierEffect

## Aplica un BuildCostModifier cuyo percent se calcula dinamicamente:
## final_percent = base_percent + turno * turn_factor
## Positivo = descuento, negativo = encarecimiento.

var modifier_id:String
var modifier_name:String
var base_percent:float
var turn_factor:float
var duration:int


func _init(p_id:String, p_name:String, p_base:float, p_turn_factor:float, p_duration:int):
	modifier_id = p_id
	modifier_name = p_name
	base_percent = p_base
	turn_factor = p_turn_factor
	duration = p_duration


func execute(context:EventContext, _chosen_card:Card = null) -> void:
	var final_percent := base_percent + context.turn_number * turn_factor
	var mod := BuildCostModifier.new(
		modifier_id, modifier_name, final_percent, duration
	)
	context.modifier_manager.add_modifier(mod, context.stats)
