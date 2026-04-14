extends Modifier
class_name StatModifier

enum StatType {
	FLAT_GOLD,
	PERCENT_GOLD,
	FLAT_FOOD,
	PERCENT_FOOD,
	TILE_RESOURCE_GOLD,
	TILE_RESOURCE_FOOD,
	CARDS_PER_TURN,
}

var type:StatType
var value:float
var target_resource:NaturalResource  ## solo para TILE_RESOURCE_*


func _init(p_id:String, p_name:String, p_type:StatType, p_value:float,
		p_duration:int, p_icon:Texture2D = null, p_target_resource:NaturalResource = null):
	super(p_id, p_name, p_duration, p_icon)
	type = p_type
	value = p_value
	target_resource = p_target_resource


func duplicate_modifier() -> Modifier:
	return StatModifier.new(id, name, type, value, duration, icon, target_resource)
