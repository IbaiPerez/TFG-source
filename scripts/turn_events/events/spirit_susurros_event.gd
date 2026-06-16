extends TurnEvent
class_name SpiritSusurrosEvent

## Susurros Ancestrales: +1 carta por turno durante 3 turnos.
## Requiere tener el Santuario del Bosque construido.


func _init():
	category = EventCategory.Type.SPIRIT

	conditions = [
		HasBuildingCondition.new("BLD_SANTUARIO_NAME")
	]

	var choice := TurnEventChoice.new()
	choice.label = tr("EVT_SPIRIT_SUSURROS_CH1_LABEL")
	choice.description = tr("EVT_SPIRIT_SUSURROS_CH1_DESC")
	choice.effects = [
		ScaledStatModifierEffect.new(
			"spirit_susurros", "Susurros Ancestrales",
			StatModifier.StatType.CARDS_PER_TURN,
			1.0, 0.0, 0.0, 3
		)
	]
	choices = [choice]
