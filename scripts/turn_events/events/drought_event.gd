extends TurnEvent
class_name DroughtEvent

## Sequía - Evento negativo OBLIGATORIO repetible
## -comida% durante 5 turnos (escalado: 15 + turno*0.2)


func _init():
	category = EventCategory.Type.FLAVOUR

	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(10, Comparison.Type.GREATER_EQUAL),
		TurnNumberCondition.new(40, Comparison.Type.LESS_EQUAL),
	]

	# Unica opcion: sufrir la sequia
	var suffer := TurnEventChoice.new()
	suffer.label = tr("EVT_DROUGHT_CH1_LABEL")
	suffer.description = tr("EVT_DROUGHT_CH1_DESC")
	suffer.effects = [
		ScaledStatModifierEffect.new(
			"drought_food", "Sequia",
			StatModifier.StatType.PERCENT_FOOD,
			-15.0, -0.2, 0.0, 5
		)
	]

	choices = [suffer]
