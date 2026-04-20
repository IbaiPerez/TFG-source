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

## Iconos precargados por tipo/signo
const ICONS := {
	"gold_flat_positive": preload("res://assets/modifiers/gold_flat_positive.svg"),
	"gold_flat_negative": preload("res://assets/modifiers/gold_flat_negative.svg"),
	"gold_percent_positive": preload("res://assets/modifiers/gold_percent_positive.svg"),
	"gold_percent_negative": preload("res://assets/modifiers/gold_percent_negative.svg"),
	"food_flat_positive": preload("res://assets/modifiers/food_flat_positive.svg"),
	"food_flat_negative": preload("res://assets/modifiers/food_flat_negative.svg"),
	"food_percent_positive": preload("res://assets/modifiers/food_percent_positive.svg"),
	"food_percent_negative": preload("res://assets/modifiers/food_percent_negative.svg"),
	"cards_flat_positive": preload("res://assets/modifiers/cards_flat_positive.svg"),
	"cards_flat_negative": preload("res://assets/modifiers/cards_flat_negative.svg"),
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

	# Asignar icono y descripcion automaticamente
	if icon == null:
		icon = _resolve_icon()
	if description.is_empty():
		description = _build_description()


func duplicate_modifier() -> Modifier:
	return StatModifier.new(id, name, type, value, duration, icon, target_resource)


func _resolve_icon() -> Texture2D:
	var key := _build_icon_key()
	return ICONS.get(key)


func _build_icon_key() -> String:
	var resource_name:String
	var modifier_type:String
	var signo := "positive" if value >= 0.0 else "negative"

	match type:
		StatType.FLAT_GOLD, StatType.TILE_RESOURCE_GOLD:
			resource_name = "gold"
			modifier_type = "flat"
		StatType.PERCENT_GOLD:
			resource_name = "gold"
			modifier_type = "percent"
		StatType.FLAT_FOOD, StatType.TILE_RESOURCE_FOOD:
			resource_name = "food"
			modifier_type = "flat"
		StatType.PERCENT_FOOD:
			resource_name = "food"
			modifier_type = "percent"
		StatType.CARDS_PER_TURN:
			resource_name = "cards"
			modifier_type = "flat"
		_:
			return ""

	return resource_name + "_" + modifier_type + "_" + signo


func _build_description() -> String:
	var sign := "+" if value >= 0.0 else ""
	var val_str:String

	match type:
		StatType.FLAT_GOLD:
			val_str = "%s%d gold per turn" % [sign, int(value)]
		StatType.PERCENT_GOLD:
			val_str = "%s%d%% gold per turn" % [sign, int(value)]
		StatType.FLAT_FOOD:
			val_str = "%s%d food per turn" % [sign, int(value)]
		StatType.PERCENT_FOOD:
			val_str = "%s%d%% food per turn" % [sign, int(value)]
		StatType.TILE_RESOURCE_GOLD:
			var res_name := target_resource.name if target_resource else "resource"
			val_str = "%s%d gold from %s" % [sign, int(value), res_name]
		StatType.TILE_RESOURCE_FOOD:
			var res_name := target_resource.name if target_resource else "resource"
			val_str = "%s%d food from %s" % [sign, int(value), res_name]
		StatType.CARDS_PER_TURN:
			val_str = "%s%d card%s per turn" % [sign, int(value), "" if absi(int(value)) == 1 else "s"]
		_:
			val_str = "%s%d" % [sign, int(value)]

	return val_str