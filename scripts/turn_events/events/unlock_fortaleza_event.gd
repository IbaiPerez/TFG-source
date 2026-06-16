extends TurnEvent
class_name UnlockFortalezaEvent

## Se activa al controlar 3+ casillas de Mountain.
## Desbloquea la Fortaleza como edificio construible.

const FORTALEZA = preload("res://resources/buildings/fortaleza.tres")


func _init():
	category = EventCategory.Type.OPTIONAL_PROGRESSION

	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		ControlledTilesCondition.new(3, Comparison.Type.GREATER_EQUAL, null, 6)
	]

	var choice := TurnEventChoice.new()
	choice.label = tr("EVT_UNLOCK_FORTALEZA_CH1_LABEL")
	choice.description = tr("EVT_UNLOCK_FORTALEZA_CH1_DESC")
	choice.effects = [UnlockBuildingEffect.new(FORTALEZA)]
	choices = [choice]
