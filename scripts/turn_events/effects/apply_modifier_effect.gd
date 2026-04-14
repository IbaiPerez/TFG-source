extends TurnEventEffect
class_name ApplyModifierEffect

var modifier:Modifier


func _init(p_modifier:Modifier):
	modifier = p_modifier


func execute(context:EventContext, _chosen_card:Card = null) -> void:
	context.modifier_manager.add_modifier(modifier.duplicate_modifier(), context.stats)
