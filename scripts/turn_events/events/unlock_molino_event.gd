extends TurnEvent
class_name UnlockMolinoEvent

## Se activa al controlar 3+ casillas de Grassland.
## Desbloquea el Molino como edificio construible.

const MOLINO = preload("res://resources/buildings/molino.tres")


func _init():
	conditions = [
		ControlledTilesCondition.new(3, Comparison.Type.GREATER_EQUAL, null, 0)
	]

	var choice := TurnEventChoice.new()
	choice.label = "Construir Molinos"
	choice.description = "Desbloquea el Molino como edificio construible en praderas."
	choice.effects = [UnlockBuildingEffect.new(MOLINO)]
	choices = [choice]
