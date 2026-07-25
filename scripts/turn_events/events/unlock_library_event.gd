extends TurnEvent
class_name UnlockLibraryEvent

## Eruditos Viajeros
## Se activa al tener una Town y 3+ casillas urbanizadas (Town o Megalopolis).
## Añade una carta de un solo uso para construir una Library.
## Evento único: solo ocurre una vez por partida.

const BUILD_LIBRARY_CARD = preload("res://resources/cards/build_library_card.tres")


func _init():
	category = EventCategory.Type.OPTIONAL_PROGRESSION

	conditions = [
		# Al menos 1 Town (location_type = 2)
		ControlledTilesCondition.new(1, Comparison.Type.GREATER_EQUAL, null, -1, 2),
		# 3+ casillas urbanizadas (Town o Megalopolis)
		UrbanizedTilesCondition.new(3, Comparison.Type.GREATER_EQUAL),
	]

	choices = [make_card_unlock_choice(BUILD_LIBRARY_CARD,
		"EVT_UNLOCK_LIBRARY_CH1_LABEL", "EVT_UNLOCK_LIBRARY_CH1_DESC", 3.0, 0.15, 2.0)]
