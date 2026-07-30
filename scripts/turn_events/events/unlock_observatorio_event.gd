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

	choices = [make_building_unlock_choice(OBSERVATORIO,
		"EVT_UNLOCK_OBSERVATORIO_CH1_LABEL", "EVT_UNLOCK_OBSERVATORIO_CH1_DESC")]
