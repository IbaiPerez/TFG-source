extends TurnEventEffect
class_name UnlockBuildingEffect

## Desbloquea un edificio añadiéndolo a la lista de edificios construibles.

var building:Building


func _init(p_building:Building):
	building = p_building


func execute(context:EventContext, _chosen_card:Card = null) -> void:
	context.stats.add_possible_building(building)
