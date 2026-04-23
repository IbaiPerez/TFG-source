extends TurnEvent
class_name SpiritOfrendaEvent

## Ofrenda del Bosque: ganancia directa de comida escalada por turno.
## Requiere tener el Santuario del Bosque construido.


func _init():
	conditions = [
		HasBuildingCondition.new("Santuario del Bosque")
	]

	var choice := TurnEventChoice.new()
	choice.label = "Aceptar la ofrenda"
	choice.description = "Los espíritus ofrecen los frutos del bosque. Ganas comida según el avance de la partida."
	choice.effects = [
		ScaledFoodEffect.new(20.0, 2.0, 0.0)
	]
	choices = [choice]
