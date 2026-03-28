extends Card
class_name BuildCard

@export var buildings:Array[Building] = []

func apply_effects(targets:Array[Node],stats:Stats) -> void:
	var effect := BuildEffect.new()
	effect.stats = stats
	effect.buildings = buildings
	effect.execute(targets)

func is_valid_target(node:Node,stats:Stats) -> bool:
	var condition := BuildCondition.new()
	condition.buildings = buildings
	condition.stats = stats
	return condition.is_valid_target(node)

func get_valid_targets(stats:Stats) -> Array[Node]:
	var condition := BuildCondition.new()
	condition.buildings = buildings
	condition.stats = stats
	return condition.valid_targets()
