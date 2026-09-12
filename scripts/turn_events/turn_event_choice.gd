extends Resource
class_name TurnEventChoice

@export var label:String
@export_multiline var description:String

var effects:Array[TurnEventEffect] = []
var cost:TurnEventCost = null


func is_affordable(context:EventContext) -> bool:
	return cost == null or cost.can_pay(context)


func needs_player_input() -> bool:
	for effect in effects:
		if effect.needs_player_input():
			return true
	return false


func needs_tile_input() -> bool:
	for effect in effects:
		if effect.needs_tile_input():
			return true
	return false


func get_tile_effect() -> TurnEventEffect:
	for effect in effects:
		if effect.needs_tile_input():
			return effect
	return null


func execute(context:EventContext) -> void:
	if cost:
		cost.pay(context)
	for effect in effects:
		effect.execute(context)
