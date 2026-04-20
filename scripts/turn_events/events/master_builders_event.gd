extends TurnEvent
class_name MasterBuildersEvent

## Maestros Constructores - Evento positivo REPETIBLE
## Añade una carta de Construir (version no-unica del Boom)

const BUILD_CARD = preload("res://resources/cards/build_card.tres")


func _init():
	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(10, Comparison.Type.GREATER_EQUAL),
		ControlledTilesCondition.new(7, Comparison.Type.GREATER_EQUAL),
	]

	var choice := TurnEventChoice.new()
	choice.label = "Acoger a los constructores"
	choice.description = "Añade una carta de Construir a tu pila de descartes."
	choice.effects = [AddCardEffect.new(BUILD_CARD)]
	choices = [choice]
