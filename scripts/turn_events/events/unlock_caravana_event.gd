extends TurnEvent
class_name UnlockCaravanaEvent

## Se activa al controlar 3+ casillas de Desert.
## Desbloquea la Caravana Comercial como edificio construible.

const CARAVANA = preload("res://resources/buildings/caravana_comercial.tres")


func _init():
	category = EventCategory.Type.OPTIONAL_PROGRESSION

	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		ControlledTilesCondition.new(3, Comparison.Type.GREATER_EQUAL, null, 2)
	]

	var choice := TurnEventChoice.new()
	choice.label = tr("EVT_UNLOCK_CARAVANA_CH1_LABEL")
	choice.description = tr("EVT_UNLOCK_CARAVANA_CH1_DESC")
	choice.effects = [UnlockBuildingEffect.new(CARAVANA)]
	choices = [choice]
