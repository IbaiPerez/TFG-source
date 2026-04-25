extends Card
class_name ColonizeCard


func _build_tooltip() -> String:
	return "[center][b][color=#5B7A3A]Coloniza[/color][/b] una [color=#4A6A8A]casilla[/color] [shake rate=20 level=5][color=#8B3A2A]adyacente[/color][/shake] a una controlada por tu [b][color=#5B7A3A]imperio[/color][/b][/center]"


func apply_effects(targets:Array[Node],stats:Stats) -> void:
	var effect := ColonizeEffect.new()
	effect.controller = stats.empire
	effect.execute(targets)
	
func get_valid_targets(stats:Stats) -> Array[Node]:
	var condition := AdjacentCondition.new()
	condition.empire = stats.empire
	return condition.valid_targets()

func is_valid_target(node:Node,stats:Stats) -> bool:
	var condition :=AdjacentCondition.new()
	condition.empire = stats.empire
	return condition.is_valid_target(node)
