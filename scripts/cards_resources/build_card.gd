extends Card
class_name BuildCard

@export var buildings:Array[Building] = []

var menu:BuildingPanel
var chosen:Building


func _build_tooltip() -> String:
	return "[center][b][color=#5B7A3A]Construye[/color][/b] un [color=#4A6A8A]edificio[/color] en una casilla controlada[/center]"


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
	Events.build_card_confirm_started.emit(self,targets,stats)
