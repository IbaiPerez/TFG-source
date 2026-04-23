extends TurnEvent
class_name UnlockObservatorioEvent

## Se activa al controlar 3+ casillas de Tundra.
## Desbloquea el Observatorio como edificio construible.

const OBSERVATORIO = preload("res://resources/buildings/observatorio.tres")


func _init():
	conditions = [
		ControlledTilesCondition.new(3, Comparison.Type.GREATER_EQUAL, null, 4)
	]

	var choice := TurnEventChoice.new()
	choice.label = "Estudiar las estrellas"
	choice.description = "Desbloquea el Observatorio como edificio construible en la tundra."
	choice.effects = [UnlockBuildingEffect.new(OBSERVATORIO)]
	choices = [choice]
