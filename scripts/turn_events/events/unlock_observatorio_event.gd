extends TurnEvent
class_name UnlockObservatorioEvent

## Se activa al controlar 3+ casillas de Tundra.
## Desbloquea el Observatorio como edificio construible.

const OBSERVATORIO = preload("res://resources/buildings/observatorio.tres")


func _init():
	category = EventCategory.Type.OPTIONAL_PROGRESSION

	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		ControlledTilesCondition.new(3, Comparison.Type.GREATER_EQUAL, null, 4)
	]

	var choice := TurnEventChoice.new()
	choice.label = tr("EVT_UNLOCK_OBSERVATORIO_CH1_LABEL")
	choice.description = tr("EVT_UNLOCK_OBSERVATORIO_CH1_DESC")
	choice.effects = [UnlockBuildingEffect.new(OBSERVATORIO)]
	choices = [choice]
