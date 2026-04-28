extends TurnEvent
class_name UnlockColiseoEvent

## Arquitectos del Espectáculo
## Se activa al tener una Megalópolis y controlar 15+ casillas.
## Añade una carta para construir el Coliseo a la pila de descartes.
## Evento único: solo ocurre una vez por partida.

const BUILD_COLISEO_CARD = preload("res://resources/cards/lategame/build_coliseo_card.tres")


func _init():
	conditions = [
		# Al menos 1 Megalopolis (location_type = 3)
		ControlledTilesCondition.new(1, Comparison.Type.GREATER_EQUAL, null, -1, 3),
		# Controlar 15+ casillas totales
		ControlledTilesCondition.new(15, Comparison.Type.GREATER_EQUAL),
	]

	var choice := TurnEventChoice.new()
	choice.label = "Acoger a los arquitectos"
	choice.description = "Añade una carta para construir el Coliseo a tu pila de descartes."
	choice.effects = [
		AddCardEffect.new(BUILD_COLISEO_CARD),
		AddToCardPoolEffect.new(BUILD_COLISEO_CARD, 3.0, 0.15, 2.0),
	]
	choices = [choice]
