extends TurnEventEffect
class_name ScaledStatModifierEffect

## Aplica un StatModifier cuyo value se calcula dinamicamente:
## final_value = base_value + turno * turn_factor + stat_reference * stat_percent
##
## stat_reference depende del tipo:
##   FLAT_GOLD / PERCENT_GOLD -> usa gold_per_turn
##   FLAT_FOOD / PERCENT_FOOD -> usa food
##   CARDS_PER_TURN -> no escala por stat (solo turno)

var modifier_id:String
var modifier_name:String
var stat_type:StatModifier.StatType
var base_value:float
var turn_factor:float
var stat_percent:float  ## porcentaje de la stat relevante (0.0 a 1.0)
var duration:int


func _init(p_id:String, p_name:String, p_type:StatModifier.StatType,
		p_base:float, p_turn_factor:float, p_stat_percent:float, p_duration:int):
	modifier_id = p_id
	modifier_name = p_name
	stat_type = p_type
	base_value = p_base
	turn_factor = p_turn_factor
	stat_percent = p_stat_percent
	duration = p_duration


func execute(context:EventContext, _chosen_card:Card = null) -> void:
	var stat_ref := _get_stat_reference(context)
	var final_value := base_value + context.turn_number * turn_factor + stat_ref * stat_percent

	var mod := StatModifier.new(
		modifier_id, modifier_name, stat_type, final_value, duration
	)
	context.modifier_manager.add_modifier(mod, context.stats)


func _get_stat_reference(context:EventContext) -> float:
	match stat_type:
		StatModifier.StatType.FLAT_GOLD, StatModifier.StatType.PERCENT_GOLD:
			return float(context.gold_per_turn)
		StatModifier.StatType.FLAT_FOOD, StatModifier.StatType.PERCENT_FOOD:
			return float(context.food)
		_:
			return 0.0
