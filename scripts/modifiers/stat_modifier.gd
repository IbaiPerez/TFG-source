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
	CARD_DRAW_BONUS,
	## Suma plana al numero de tropas reclutadas por play de RecruitCard.
	## El total efectivo es `card.base_troops_per_play + sum(este modifier)`.
	## Si `troop_type_filter >= 0`, solo se aplica cuando la tropa elegida
	## coincide con ese Troop.TroopType; si es -1, afecta a todas las tropas.
	TROOPS_PER_RECRUIT,
	## Descuento porcentual al mantenimiento BASE de tropas (oro y comida).
	## Si `troop_type_filter >= 0`, solo se aplica al mantenimiento de las
	## tropas de ese Troop.TroopType; si es -1, afecta a todas las tropas.
	## Se clampa a [-80, 0] para evitar que el mantenimiento llegue a 0.
	## NO afecta al recargo de frentes (coste plano sin descuento).
	TROOP_MAINTENANCE_PERCENT,
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
	"troops_flat_positive": preload("res://assets/modifiers/troops_flat_positive.svg"),
	"troops_flat_negative": preload("res://assets/modifiers/troops_flat_negative.svg"),
	"troop_maintenance_percent_positive": preload("res://assets/modifiers/troop_maintenance_percent_positive.svg"),
	"troop_maintenance_percent_negative": preload("res://assets/modifiers/troop_maintenance_percent_negative.svg"),
}

var type: StatType
var value: float
var target_resource: NaturalResource  ## solo para TILE_RESOURCE_*
## Troop.TroopType al que se limita este modifier, o -1 para todas las tropas.
## Solo relevante para TROOPS_PER_RECRUIT y TROOP_MAINTENANCE_PERCENT.
var troop_type_filter: int = -1


func _init(p_id: String, p_name: String, p_type: StatType, p_value: float,
		p_duration: int, p_icon: Texture2D = null,
		p_target_resource: NaturalResource = null, p_troop_type_filter: int = -1):
	super(p_id, p_name, p_duration, p_icon)
	type = p_type
	value = p_value
	target_resource = p_target_resource
	troop_type_filter = p_troop_type_filter

	# Asignar icono y descripcion automaticamente
	if icon == null:
		icon = _resolve_icon()
	if description.is_empty():
		description = _build_description()


func duplicate_modifier() -> Modifier:
	return StatModifier.new(id, name, type, value, duration, icon, target_resource, troop_type_filter)


## Devuelve true si este modifier aplica a la tropa dada (o a todas si filter == -1).
func applies_to_troop(troop: Troop) -> bool:
	return troop_type_filter < 0 or (troop != null and troop.type == troop_type_filter)


func _resolve_icon() -> Texture2D:
	var key := _build_icon_key()
	return ICONS.get(key)


func _build_icon_key() -> String:
	var resource_name: String
	var modifier_type: String
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
		StatType.CARDS_PER_TURN, StatType.CARD_DRAW_BONUS:
			resource_name = "cards"
			modifier_type = "flat"
		StatType.TROOPS_PER_RECRUIT:
			resource_name = "troops"
			modifier_type = "flat"
		StatType.TROOP_MAINTENANCE_PERCENT:
			resource_name = "troop_maintenance"
			modifier_type = "percent"
		_:
			return ""

	return resource_name + "_" + modifier_type + "_" + signo


func _build_description() -> String:
	var sign := "+" if value >= 0.0 else ""
	var val_str: String

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
		StatType.CARD_DRAW_BONUS:
			val_str = "%s%d extra card%s on draw" % [sign, int(value), "" if absi(int(value)) == 1 else "s"]
		StatType.TROOPS_PER_RECRUIT:
			var scope := Troop.type_label_for(troop_type_filter) if troop_type_filter >= 0 else "troop"
			val_str = "%s%d extra %s%s per recruit" % [sign, int(value), scope.to_lower(),
					"" if absi(int(value)) == 1 else "s"]
		StatType.TROOP_MAINTENANCE_PERCENT:
			var scope := Troop.type_label_for(troop_type_filter) if troop_type_filter >= 0 else "troop"
			val_str = "%s%d%% %s maintenance" % [sign, int(value), scope.to_lower()]
		_:
			val_str = "%s%d" % [sign, int(value)]

	return val_str
