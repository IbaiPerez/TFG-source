extends TurnEvent
class_name WiseTravelersEvent

## Sabios Viajeros - Evento positivo UNICO
## +1 carta por turno permanente


func _init():
	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(15, Comparison.Type.GREATER_EQUAL),
		ControlledTilesCondition.new(10, Comparison.Type.GREATER_EQUAL),
	]

	var choice := TurnEventChoice.new()
	choice.label = "Acoger a los sabios"
	choice.description = "+1 carta por turno de forma permanente."
	choice.effects = [
		ApplyModifierEffect.new(
			StatModifier.new(
				"wise_travelers_cards", "Sabios Viajeros",
				StatModifier.StatType.CARDS_PER_TURN, 1.0, -1
			)
		)
	]
	choices = [choice]
