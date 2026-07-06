extends TurnEvent
class_name LocustPlagueEvent

## Plaga de Langostas - Evento negativo OBLIGATORIO repetible
## -20% comida durante 4 turnos (no escalado, siempre -20%)


func _init():
	category = EventCategory.Type.FLAVOUR

	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(6, Comparison.Type.GREATER_EQUAL),
		TurnNumberCondition.new(30, Comparison.Type.LESS_EQUAL),
	]

	# Unica opcion: sufrir la plaga
	var suffer := TurnEventChoice.new()
	suffer.label = tr("EVT_LOCUST_CH1_LABEL")
	suffer.description = tr("EVT_LOCUST_CH1_DESC")
	suffer.effects = [
		ScaledStatModifierEffect.new(
			"locust_plague_food", "EVT_LOCUST_TITLE",
			StatModifier.StatType.PERCENT_FOOD,
			-20.0, 0.0, 0.0, 4
		)
	]

	choices = [suffer]
