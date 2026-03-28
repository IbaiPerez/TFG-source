extends Card
class_name BuildCard

@export var buildings:Array[Building] = []
@export var confirm_menu:PackedScene

var menu
var chosen:Building

func apply_effects(targets:Array[Node],stats:Stats) -> void:
	var effect := BuildEffect.new()
	effect.stats = stats
	effect.building = chosen
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

func confirm(targets:Array[Node], stats:Stats) -> void:
	if targets.size() != 1:
		return
	for t in targets:
		if not t is Tile:
			return
		menu = confirm_menu.instantiate()
		menu.tile = t
		menu.stats = stats
		menu.buildings = buildings
