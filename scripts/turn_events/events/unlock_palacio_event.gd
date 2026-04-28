extends TurnEvent
class_name UnlockPalacioEvent

## La Corona Imperial
## Se activa al tener una Megalópolis y controlar 25+ casillas.
## Añade una carta para construir el Palacio Imperial a la pila de descartes.
## Evento único: solo ocurre una vez por partida.

const BUILD_PALACIO_CARD = preload("res://resources/cards/lategame/build_palacio_card.tres")


func _init():
	conditions = [
		# Al menos 1 Megalopolis (location_type = 3)
		ControlledTilesCondition.new(1, Comparison.Type.GREATER_EQUAL, null, -1, 3),
		# Controlar 25+ casillas totales
		ControlledTilesCondition.new(25, Comparison.Type.GREATER_EQUAL),
	]

	var choice := TurnEventChoice.new()
	choice.label = "Erigir el palacio"
	choice.description = "Añade una carta para construir el Palacio Imperial a tu pila de descartes."
	choice.effects = [
		AddCardEffect.new(BUILD_PALACIO_CARD),
		AddToCardPoolEffect.new(BUILD_PALACIO_CARD, 3.0, 0.15, 2.0),
	]
	choices = [choice]
