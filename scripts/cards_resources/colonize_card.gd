extends Card
class_name ColonizeCard


func _build_tooltip() -> String:
	return "[center][b][color=green]Coloniza[/color][/b] una [color=blue]casilla[/color] [shake rate=20 level=5][color=red]adyacente[/color][/shake] a una controlada por tu [b][color=green]imperio[/color][/b][/center]"


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
