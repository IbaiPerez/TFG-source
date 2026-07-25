extends TurnEvent
class_name UnlockColiseoEvent

## Arquitectos del Espectáculo
## Se activa al tener una Megalópolis y controlar 15+ casillas.
## Añade una carta para construir el Coliseo a la pila de descartes.
## Evento único: solo ocurre una vez por partida.

const BUILD_COLISEO_CARD = preload("res://resources/cards/lategame/build_coliseo_card.tres")


func _init():
	category = EventCategory.Type.OPTIONAL_PROGRESSION

	conditions = [
		# Al menos 1 Megalopolis (location_type = 3)
		ControlledTilesCondition.new(1, Comparison.Type.GREATER_EQUAL, null, -1, 3),
		# Controlar 15+ casillas totales
		ControlledTilesCondition.new(15, Comparison.Type.GREATER_EQUAL),
	]

	choices = [make_card_unlock_choice(BUILD_COLISEO_CARD,
		"EVT_UNLOCK_COLISEO_CH1_LABEL", "EVT_UNLOCK_COLISEO_CH1_DESC", 3.0, 0.15, 2.0)]
