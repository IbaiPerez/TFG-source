extends TurnEvent
class_name UnlockMolinoEvent

## Se activa al controlar 3+ casillas de Grassland.
## Desbloquea el Molino como edificio construible.

const MOLINO = preload("res://resources/buildings/molino.tres")


func _init():
	category = EventCategory.Type.OPTIONAL_PROGRESSION

	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		ControlledTilesCondition.new(3, Comparison.Type.GREATER_EQUAL, null, 0)
	]

	var choice := TurnEventChoice.new()
	choice.label = tr("EVT_UNLOCK_MOLINO_CH1_LABEL")
	choice.description = tr("EVT_UNLOCK_MOLINO_CH1_DESC")
	choice.effects = [UnlockBuildingEffect.new(MOLINO)]
	choices = [choice]
