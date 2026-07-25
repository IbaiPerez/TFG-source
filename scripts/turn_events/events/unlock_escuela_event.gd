extends TurnEvent
class_name UnlockEscuelaEvent

## Urbanistas Ilustrados
## Se activa al tener una Megalópolis y 4+ casillas urbanizadas (Town o Megalopolis).
## Añade una carta para construir la Escuela de Planificación a la pila de descartes.
## Evento único: solo ocurre una vez por partida.

const BUILD_ESCUELA_CARD = preload("res://resources/cards/lategame/build_escuela_card.tres")


func _init():
	category = EventCategory.Type.OPTIONAL_PROGRESSION

	conditions = [
		# Al menos 1 Megalopolis (location_type = 3)
		ControlledTilesCondition.new(1, Comparison.Type.GREATER_EQUAL, null, -1, 3),
		# 4+ casillas urbanizadas (Town o Megalopolis)
		UrbanizedTilesCondition.new(4, Comparison.Type.GREATER_EQUAL),
	]

	choices = [make_card_unlock_choice(BUILD_ESCUELA_CARD,
		"EVT_UNLOCK_ESCUELA_CH1_LABEL", "EVT_UNLOCK_ESCUELA_CH1_DESC", 3.0, 0.15, 2.0)]
