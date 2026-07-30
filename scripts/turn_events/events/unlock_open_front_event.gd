extends TurnEvent
class_name UnlockOpenFrontEvent

## Conflicto fronterizo
## Se activa tras haber desbloqueado Reclutar y tener al menos 1 tropa.
## Otorga la carta de Abrir Frente.
## Evento único: solo ocurre una vez por partida.

const OPEN_FRONT_CARD = preload("res://resources/cards/open_front_card.tres")
const CUARTEL_BUILDING = preload("res://resources/buildings/lategame/cuartel_expansion.tres")


func _init():
	category = EventCategory.Type.CORE_PROGRESSION

	conditions = [
		UniqueEventOccurredCondition.new("unlock_recruit"),
		HasTroopsCondition.new(1),
	]

	# Idempotente: Stats.add_possible_building filtra duplicados. Emitimos el
	# Cuartel aqui ademas de en unlock_recruit para cubrir saves antiguos y por si
	# la cadena de eventos llega aqui via otra ruta.
	choices = [make_card_unlock_choice(OPEN_FRONT_CARD,
		"EVT_UNLOCK_OPEN_FRONT_CH1_LABEL", "EVT_UNLOCK_OPEN_FRONT_CH1_DESC", 6.0, -0.1, 2.0,
		[UnlockBuildingEffect.new(CUARTEL_BUILDING)])]
