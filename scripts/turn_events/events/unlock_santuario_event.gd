extends TurnEvent
class_name UnlockSantuarioEvent

## Se activa al controlar 3+ casillas de Forest.
## Otorga una carta de un solo uso para construir el Santuario del Bosque.
## El jugador puede rechazar la oferta (allow_skip = true).

const BUILD_SANTUARIO_CARD = preload("res://resources/cards/build_santuario_card.tres")


func _init():
	category = EventCategory.Type.OPTIONAL_PROGRESSION

	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		ControlledTilesCondition.new(3, Comparison.Type.GREATER_EQUAL, null, 1)
	]

	var choice := TurnEventChoice.new()
	choice.label = tr("EVT_UNLOCK_SANTUARIO_CH1_LABEL")
	choice.description = tr("EVT_UNLOCK_SANTUARIO_CH1_DESC")
	choice.effects = [AddCardEffect.new(BUILD_SANTUARIO_CARD)]
	choices = [choice]
