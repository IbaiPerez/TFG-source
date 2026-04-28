extends TurnEvent
class_name UnlockOficinaEvent

## Burocracia Imperial
## Se activa al tener una Megalópolis y 10+ edificios construidos.
## Añade una carta para construir la Oficina de Construcción a la pila de descartes.
## Evento único: solo ocurre una vez por partida.

const BUILD_OFICINA_CARD = preload("res://resources/cards/lategame/build_oficina_card.tres")


func _init():
	conditions = [
		# Al menos 1 Megalopolis (location_type = 3)
		ControlledTilesCondition.new(1, Comparison.Type.GREATER_EQUAL, null, -1, 3),
		# 10+ edificios construidos en total
		BuildingCountCondition.new(10, Comparison.Type.GREATER_EQUAL),
	]

	var choice := TurnEventChoice.new()
	choice.label = "Establecer la oficina"
	choice.description = "Añade una carta para construir la Oficina de Construcción a tu pila de descartes."
	choice.effects = [
		AddCardEffect.new(BUILD_OFICINA_CARD),
		AddToCardPoolEffect.new(BUILD_OFICINA_CARD, 3.0, 0.15, 2.0),
	]
	choices = [choice]
