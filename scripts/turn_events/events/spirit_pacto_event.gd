extends TurnEvent
class_name SpiritPactoEvent

## Pacto con el Bosque: coloniza automáticamente una casilla adyacente.
## Prioriza casillas de Forest. Solo disponible si hay casillas colonizables.
## Requiere tener el Santuario del Bosque construido.


func _init():
	conditions = [
		HasBuildingCondition.new("Santuario del Bosque"),
		HasAdjacentUncontrolledCondition.new()
	]

	var choice := TurnEventChoice.new()
	choice.label = "Sellar el pacto"
	choice.description = "Los espíritus extienden las raíces del bosque y reclaman una casilla adyacente para tu imperio."
	choice.effects = [
		ColonizeAdjacentEffect.new(1)  # 1 = Forest, prioriza bosque
	]
	choices = [choice]
