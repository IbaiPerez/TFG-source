extends TurnEvent
class_name SpiritOfrendaEvent

## Ofrenda del Bosque: +comida por turno durante 3 turnos, escalada por el turno
## (7 + turno*0.7). Producción y no comida suelta: la comida no se acumula.
## Requiere tener el Santuario del Bosque construido.


func _init():
	category = EventCategory.Type.SPIRIT

	conditions = [
		HasBuildingCondition.new("BLD_SANTUARIO_NAME")
	]

	var choice := make_choice("EVT_SPIRIT_OFRENDA_CH1_LABEL", "EVT_SPIRIT_OFRENDA_CH1_DESC", [
		ScaledStatModifierEffect.new(
			"spirit_ofrenda_food", "EVT_SPIRIT_OFRENDA_TITLE",
			StatModifier.StatType.FLAT_FOOD, 7.0, 0.7, 0.0, 3
		)
	])
	choices = [choice]
