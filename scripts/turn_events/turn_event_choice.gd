extends Resource
class_name TurnEventChoice

@export var label:String
@export_multiline var description:String

var effects:Array[TurnEventEffect] = []
var cost:TurnEventCost = null


func is_affordable(context:EventContext) -> bool:
	return cost == null or cost.can_pay(context)


func needs_player_input() -> bool:
	if cost != null and cost.needs_player_input():
		return true
	for effect in effects:
		if effect.needs_player_input():
			return true
	return false


func execute(context:EventContext, chosen_cards:Dictionary = {}) -> void:
	if cost:
		cost.pay(context, chosen_cards.get("cost"))

	for i in effects.size():
		effects[i].execute(context, chosen_cards.get(i))
