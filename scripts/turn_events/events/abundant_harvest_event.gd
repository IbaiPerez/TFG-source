extends TurnEvent
class_name AbundantHarvestEvent

## Cosecha Abundante - Evento positivo repetible
## +comida directa escalada (base 15 + turno*0.5 + 8% food)


func _init():
	category = EventCategory.Type.FLAVOUR

	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(5),
	]

	var choice := make_choice("EVT_ABUNDANT_CH1_LABEL", "EVT_ABUNDANT_CH1_DESC",
		[ScaledFoodEffect.new(15.0, 0.5, 0.08)])
	choices = [choice]
