extends TurnEvent
class_name UnlockGranjaSanguijuelasEvent

## Se activa al controlar 3+ casillas de Swamp.
## Desbloquea la Granja de Sanguijuelas como edificio construible.

const GRANJA = preload("res://resources/buildings/granja_sanguijuelas.tres")


func _init():
	conditions = [
		ControlledTilesCondition.new(3, Comparison.Type.GREATER_EQUAL, null, 3)
	]

	var choice := TurnEventChoice.new()
	choice.label = "Aprovechar los pantanos"
	choice.description = "Desbloquea la Granja de Sanguijuelas como edificio construible en pantanos."
	choice.effects = [UnlockBuildingEffect.new(GRANJA)]
	choices = [choice]
