extends TurnEvent
class_name UnlockGranjaSanguijuelasEvent

## Se activa al controlar 3+ casillas de Swamp.
## Desbloquea la Granja de Sanguijuelas como edificio construible.

const GRANJA = preload("res://resources/buildings/granja_sanguijuelas.tres")


func _init():
	category = EventCategory.Type.OPTIONAL_PROGRESSION

	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		ControlledTilesCondition.new(3, Comparison.Type.GREATER_EQUAL, null, 3)
	]

	var choice := TurnEventChoice.new()
	choice.label = tr("EVT_UNLOCK_GRANJA_SANG_CH1_LABEL")
	choice.description = tr("EVT_UNLOCK_GRANJA_SANG_CH1_DESC")
	choice.effects = [UnlockBuildingEffect.new(GRANJA)]
	choices = [choice]
