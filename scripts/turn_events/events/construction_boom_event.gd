extends TurnEvent
class_name ConstructionBoomEvent

## Boom de Construcción
## Se activa al controlar 5 o más provincias.
## Añade una carta de Construir a la pila de descartes.
## Evento único: solo ocurre una vez por partida.

const BUILD_CARD = preload("res://resources/cards/build_card.tres")


func _init():
	category = EventCategory.Type.CORE_PROGRESSION

	# Condicion: controlar al menos 5 casillas
	conditions = [
		ControlledTilesCondition.new(5, Comparison.Type.GREATER_EQUAL)
	]

	# Eleccion: recibir la carta de construir
	var choice := TurnEventChoice.new()
	choice.label = tr("EVT_CONSTRUCTION_BOOM_CH1_LABEL")
	choice.description = tr("EVT_CONSTRUCTION_BOOM_CH1_DESC")
	choice.effects = [
		AddCardEffect.new(BUILD_CARD),
		AddToCardPoolEffect.new(BUILD_CARD, 10.0, -0.2, 3.0),
	]
	choices = [choice]
