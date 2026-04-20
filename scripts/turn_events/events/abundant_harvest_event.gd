extends TurnEvent
class_name AbundantHarvestEvent

## Cosecha Abundante - Evento positivo repetible
## +comida directa escalada (base 15 + turno*0.5 + 8% food)


func _init():
	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(5, Comparison.Type.GREATER_EQUAL),
	]

	var choice := TurnEventChoice.new()
	choice.label = "Recoger la cosecha"
	choice.description = "Tus campos producen mas de lo esperado."
	choice.effects = [ScaledFoodEffect.new(15.0, 0.5, 0.08)]
	choices = [choice]
