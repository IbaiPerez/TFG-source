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

	choices = [make_building_unlock_choice(CARAVANA,
		"EVT_UNLOCK_CARAVANA_CH1_LABEL", "EVT_UNLOCK_CARAVANA_CH1_DESC")]
