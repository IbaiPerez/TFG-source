extends TurnEvent
class_name MerchantCaravanEvent

## Caravana Mercante - Evento positivo repetible
## +oro directo escalado (base 20 + turno*0.8 + 5% gold_per_turn)


func _init():
	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(3, Comparison.Type.GREATER_EQUAL),
		ControlledTilesCondition.new(3, Comparison.Type.GREATER_EQUAL),
	]

	var choice := TurnEventChoice.new()
	choice.label = "Aceptar las monedas"
	choice.description = "Recibes oro de los mercaderes."
	choice.effects = [ScaledGoldEffect.new(20.0, 0.8, 0.05)]
	choices = [choice]
