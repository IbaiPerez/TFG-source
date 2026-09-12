extends TurnEvent
class_name TimeOfPlentyEvent

## Tiempo de Abundancia - Evento positivo repetible
## +comida% durante 3 turnos (escalado: 20 + turno*0.3)


func _init():
	category = EventCategory.Type.FLAVOUR

	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(8),
		FoodThresholdCondition.new(5),
	]

	var choice := make_choice("EVT_TIME_OF_PLENTY_CH1_LABEL", "EVT_TIME_OF_PLENTY_CH1_DESC", [
		ScaledStatModifierEffect.new(
			"time_of_plenty_food", "EVT_TIME_OF_PLENTY_TITLE",
			StatModifier.StatType.PERCENT_FOOD,
			20.0, 0.3, 0.0, 3
		)
	])
	choices = [choice]
