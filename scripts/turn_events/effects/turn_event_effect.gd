extends RefCounted
class_name TurnEventEffect


func needs_player_input() -> bool:
	return false


func needs_tile_input() -> bool:
	return false


func execute(_context:EventContext, _chosen_card:Card = null) -> void:
	pass
