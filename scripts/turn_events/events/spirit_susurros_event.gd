extends TurnEvent
class_name SpiritSusurrosEvent

## Susurros Ancestrales: +1 carta por turno durante 3 turnos.
## Requiere tener el Santuario del Bosque construido.


func _init():
	conditions = [
		HasBuildingCondition.new("Santuario del Bosque")
	]

	var choice := TurnEventChoice.new()
	choice.label = "Escuchar los susurros"
	choice.description = "Las voces ancestrales guían tus decisiones. +1 carta por turno durante 3 turnos."
	choice.effects = [
		ScaledStatModifierEffect.new(
			"spirit_susurros", "Susurros Ancestrales",
			StatModifier.StatType.CARDS_PER_TURN,
			1.0, 0.0, 0.0, 3
		)
	]
	choices = [choice]
