extends Modifier
class_name BuildCostModifier

## Porcentaje de descuento (positivo) o encarecimiento (negativo)
## 20.0 = 20% descuento, -15.0 = 15% mas caro
var percent:float


func _init(p_id:String, p_name:String, p_percent:float,
		p_duration:int, p_icon:Texture2D = null):
	super(p_id, p_name, p_duration, p_icon)
	percent = p_percent


func duplicate_modifier() -> Modifier:
	return BuildCostModifier.new(id, name, percent, duration, icon)
