extends TurnEvent
class_name UnlockTempleEvent

## Fervor Espiritual
## Se activa al tener una Town y 5+ edificios construidos.
## Añade una carta de un solo uso para construir un Temple.
## Evento único: solo ocurre una vez por partida.

const BUILD_TEMPLE_CARD = preload("res://resources/cards/build_temple_card.tres")


func _init():
	conditions = [
		# Al menos 1 Town (location_type = 2)
		ControlledTilesCondition.new(1, Comparison.Type.GREATER_EQUAL, null, -1, 2),
		# 5+ edificios construidos en total
		BuildingCountCondition.new(5, Comparison.Type.GREATER_EQUAL),
	]

	var choice := TurnEventChoice.new()
	choice.label = "Erigir un templo"
	choice.description = "Recibes una carta de un solo uso para construir un Temple."
	choice.effects = [
		AddCardEffect.new(BUILD_TEMPLE_CARD),
		AddToCardPoolEffect.new(BUILD_TEMPLE_CARD, 3.0, 0.15, 2.0),
	]
	choices = [choice]
