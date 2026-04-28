extends TurnEvent
class_name UnlockLibraryEvent

## Eruditos Viajeros
## Se activa al tener una Town y 3+ casillas urbanizadas (Town o Megalopolis).
## Añade una carta de un solo uso para construir una Library.
## Evento único: solo ocurre una vez por partida.

const BUILD_LIBRARY_CARD = preload("res://resources/cards/build_library_card.tres")


func _init():
	conditions = [
		# Al menos 1 Town (location_type = 2)
		ControlledTilesCondition.new(1, Comparison.Type.GREATER_EQUAL, null, -1, 2),
		# 3+ casillas urbanizadas (Town o Megalopolis)
		UrbanizedTilesCondition.new(3, Comparison.Type.GREATER_EQUAL),
	]

	var choice := TurnEventChoice.new()
	choice.label = "Acoger a los eruditos"
	choice.description = "Recibes una carta de un solo uso para construir una Library."
	choice.effects = [
		AddCardEffect.new(BUILD_LIBRARY_CARD),
		AddToCardPoolEffect.new(BUILD_LIBRARY_CARD, 3.0, 0.15, 2.0),
	]
	choices = [choice]
