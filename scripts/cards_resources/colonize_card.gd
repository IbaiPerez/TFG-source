extends Card
class_name ColonizeCard


func apply_effects(targets:Array[Node],stats:Stats) -> void:
	var effect := ColonizeEffect.new()
	effect.controller = stats.empire
	effect.execute(targets)
	
func get_valid_targets(stats:Stats) -> Array[Node]:
	var condition := AdjacentCondition.new()
	condition.empire = stats.empire
	return condition.valid_targets()

func is_target_valid(node:Node,stats:Stats) -> bool:
	var condition :=AdjacentCondition.new()
	condition.empire = stats.empire
	return condition.is_valid_target(node)
