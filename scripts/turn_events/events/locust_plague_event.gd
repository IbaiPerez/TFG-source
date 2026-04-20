extends TurnEvent
class_name LocustPlagueEvent

## Plaga de Langostas - Evento negativo OBLIGATORIO repetible
## -20% comida durante 4 turnos (no escalado, siempre -20%)


func _init():
	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(6, Comparison.Type.GREATER_EQUAL),
		TurnNumberCondition.new(30, Comparison.Type.LESS_EQUAL),
	]

	# Unica opcion: sufrir la plaga
	var suffer := TurnEventChoice.new()
	suffer.label = "Sufrir la plaga"
	suffer.description = "Las langostas devoran tus cosechas. -20% comida durante 4 turnos."
	suffer.effects = [
		ScaledStatModifierEffect.new(
			"locust_plague_food", "Plaga de Langostas",
			StatModifier.StatType.PERCENT_FOOD,
			-20.0, 0.0, 0.0, 4
		)
	]

	choices = [suffer]
