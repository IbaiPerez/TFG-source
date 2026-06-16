extends TurnEvent
class_name SpiritBendicionEvent

## Bendición de la Naturaleza: +25% comida durante 3 turnos.
## Requiere tener el Santuario del Bosque construido.


func _init():
	category = EventCategory.Type.SPIRIT

	conditions = [
		HasBuildingCondition.new("BLD_SANTUARIO_NAME")
	]

	var choice := TurnEventChoice.new()
	choice.label = tr("EVT_SPIRIT_BENDICION_CH1_LABEL")
	choice.description = tr("EVT_SPIRIT_BENDICION_CH1_DESC")
	choice.effects = [
		ScaledStatModifierEffect.new(
			"spirit_bendicion", "Bendición Natural",
			StatModifier.StatType.PERCENT_FOOD,
			25.0, 0.0, 0.0, 3
		)
	]
	choices = [choice]
