extends TurnEvent
class_name UnlockCuartelEvent

## Generales Veteranos
## Se activa al tener una Megalópolis y controlar 20+ casillas.
## Añade una carta para construir el Cuartel de Expansión a la pila de descartes.
## Evento único: solo ocurre una vez por partida.

const BUILD_CUARTEL_CARD = preload("res://resources/cards/lategame/build_cuartel_card.tres")


func _init():
	conditions = [
		# Al menos 1 Megalopolis (location_type = 3)
		ControlledTilesCondition.new(1, Comparison.Type.GREATER_EQUAL, null, -1, 3),
		# Controlar 20+ casillas totales
		ControlledTilesCondition.new(20, Comparison.Type.GREATER_EQUAL),
	]

	var choice := TurnEventChoice.new()
	choice.label = "Reclutar a los generales"
	choice.description = "Añade una carta para construir el Cuartel de Expansión a tu pila de descartes."
	choice.effects = [
		AddCardEffect.new(BUILD_CUARTEL_CARD),
		AddToCardPoolEffect.new(BUILD_CUARTEL_CARD, 3.0, 0.15, 2.0),
	]
	choices = [choice]
