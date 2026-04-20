extends TurnEvent
class_name TimeOfPlentyEvent

## Tiempo de Abundancia - Evento positivo repetible
## +comida% durante 3 turnos (escalado: 20 + turno*0.3)


func _init():
	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(8, Comparison.Type.GREATER_EQUAL),
		FoodThresholdCondition.new(5, Comparison.Type.GREATER_EQUAL),
	]

	var choice := TurnEventChoice.new()
	choice.label = "Disfrutar la abundancia"
	choice.description = "Bonus temporal a la produccion de comida."
	choice.effects = [
		ScaledStatModifierEffect.new(
			"time_of_plenty_food", "Tiempo de Abundancia",
			StatModifier.StatType.PERCENT_FOOD,
			20.0, 0.3, 0.0, 3
		)
	]
	choices = [choice]
