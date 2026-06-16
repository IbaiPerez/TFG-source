extends Card
class_name ChangeLocationTypeCard

@export var location_type:LocationType


func _build_tooltip() -> String:
	var type_name:String = tr("LOC_" + Tile.location_type.keys()[location_type.type].to_upper()) if location_type else "?"
	return tr("CARD_URBANIZE_TOOLTIP") % type_name


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
