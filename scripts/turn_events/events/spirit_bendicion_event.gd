extends TurnEvent
class_name SpiritBendicionEvent

## Bendición de la Naturaleza: +25% comida durante 3 turnos.
## Requiere tener el Santuario del Bosque construido.


func _init():
	conditions = [
		HasBuildingCondition.new("Santuario del Bosque")
	]

	var choice := TurnEventChoice.new()
	choice.label = "Aceptar la bendición"
	choice.description = "Los espíritus bendicen tus cosechas. +25% producción de comida durante 3 turnos."
	choice.effects = [
		ScaledStatModifierEffect.new(
			"spirit_bendicion", "Bendición Natural",
			StatModifier.StatType.PERCENT_FOOD,
			25.0, 0.0, 0.0, 3
		)
	]
	choices = [choice]
