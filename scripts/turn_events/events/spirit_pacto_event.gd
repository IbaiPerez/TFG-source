extends TurnEvent
class_name SpiritPactoEvent

## Pacto con el Bosque: coloniza automáticamente una casilla adyacente.
## Prioriza casillas de Forest. Solo disponible si hay casillas colonizables.
## Requiere tener el Santuario del Bosque construido.


func _init():
	category = EventCategory.Type.SPIRIT

	conditions = [
		HasBuildingCondition.new("BLD_SANTUARIO_NAME"),
		HasAdjacentUncontrolledCondition.new()
	]

	var choice := TurnEventChoice.new()
	choice.label = tr("EVT_SPIRIT_PACTO_CH1_LABEL")
	choice.description = tr("EVT_SPIRIT_PACTO_CH1_DESC")
	choice.effects = [
		ColonizeAdjacentEffect.new(1)  # 1 = Forest, prioriza bosque
	]
	choices = [choice]
