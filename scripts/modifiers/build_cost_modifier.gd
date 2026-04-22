extends Modifier
class_name BuildCostModifier

## Porcentaje de descuento (positivo) o encarecimiento (negativo)
## 20.0 = 20% descuento, -15.0 = 15% mas caro

## Iconos precargados por signo
const ICONS := {
	"build_cost_positive": preload("res://assets/modifiers/build_cost_positive.svg"),
	"build_cost_negative": preload("res://assets/modifiers/build_cost_negative.svg"),
}

var percent:float


func _init(p_id:String, p_name:String, p_percent:float,
		p_duration:int, p_icon:Texture2D = null):
	super(p_id, p_name, p_duration, p_icon)
	percent = p_percent

	# Asignar icono y descripcion automaticamente
	if icon == null:
		icon = _resolve_icon()
	if description.is_empty():
		description = _build_description()


func duplicate_modifier() -> Modifier:
	return BuildCostModifier.new(id, name, percent, duration, icon)


func _resolve_icon() -> Texture2D:
	var key := _build_icon_key()
	return ICONS.get(key)


func _build_icon_key() -> String:
	var signo := "positive" if percent >= 0.0 else "negative"
	return "build_cost_" + signo


func _build_description() -> String:
	if percent >= 0.0:
		return "-%d%% build cost" % [int(percent)]
	else:
		return "+%d%% build cost" % [int(absf(percent))]
