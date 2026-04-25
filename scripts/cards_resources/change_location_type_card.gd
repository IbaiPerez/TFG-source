extends Card
class_name ChangeLocationTypeCard

@export var location_type:LocationType


func _build_tooltip() -> String:
	var type_name:String = Tile.location_type.keys()[location_type.type] if location_type else "?"
	return "[center][b][color=#5B7A3A]Urbaniza[/color][/b] una casilla a [color=#4A6A8A]%s[/color][/center]" % type_name


func apply_effects(targets:Array[Node],stats:Stats) -> void:
	var effect := ChangeLocationTypeEffect.new()
	effect.location_type = location_type
	effect.stats = stats
	effect.execute(targets)

func get_valid_targets(stats:Stats) -> Array[Node]:
	var condition := ChangeLocationTypeCondition.new()
	condition.location_type = location_type
	condition.stats = stats
	return condition.valid_targets()

func is_valid_target(node:Node,stats:Stats) -> bool:
	var condition := ChangeLocationTypeCondition.new()
	condition.location_type = location_type
	condition.stats = stats
	return condition.is_valid_target(node)
