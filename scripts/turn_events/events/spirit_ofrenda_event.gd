extends TurnEvent
class_name SpiritOfrendaEvent

## Ofrenda del Bosque: ganancia directa de comida escalada por turno.
## Requiere tener el Santuario del Bosque construido.


func _init():
	category = EventCategory.Type.SPIRIT

	conditions = [
		HasBuildingCondition.new("BLD_SANTUARIO_NAME")
	]

	var choice := TurnEventChoice.new()
	choice.label = tr("EVT_SPIRIT_OFRENDA_CH1_LABEL")
	choice.description = tr("EVT_SPIRIT_OFRENDA_CH1_DESC")
	choice.effects = [
		ScaledFoodEffect.new(20.0, 2.0, 0.0)
	]
	choices = [choice]
