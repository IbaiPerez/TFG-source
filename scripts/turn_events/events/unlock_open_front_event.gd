extends TurnEvent
class_name UnlockOpenFrontEvent

## Conflicto fronterizo
## Se activa tras haber desbloqueado Reclutar y tener al menos 1 tropa.
## Otorga la carta de Abrir Frente.
## Evento único: solo ocurre una vez por partida.

const OPEN_FRONT_CARD = preload("res://resources/cards/open_front_card.tres")
const CUARTEL_BUILDING = preload("res://resources/buildings/lategame/cuartel_expansion.tres")


func _init():
	id = "unlock_open_front"
	title = "Conflicto fronterizo"
	description = "Tus tropas están listas. Ha llegado el momento de tomar la iniciativa y abrir un frente de batalla."
	weight = 100.0
	unique = true
	allow_skip = false
	category = EventCategory.Type.CORE_PROGRESSION

	conditions = [
		UniqueEventOccurredCondition.new("unlock_recruit"),
		HasTroopsCondition.new(1),
	]

	var choice := TurnEventChoice.new()
	choice.label = tr("EVT_UNLOCK_OPEN_FRONT_CH1_LABEL")
	choice.description = tr("EVT_UNLOCK_OPEN_FRONT_CH1_DESC")
	choice.effects = [
		AddCardEffect.new(OPEN_FRONT_CARD),
		AddToCardPoolEffect.new(OPEN_FRONT_CARD, 6.0, -0.1, 2.0),
		# Idempotente: Stats.add_possible_building filtra duplicados. Lo
		# emitimos aqui ademas de en unlock_recruit para cubrir saves antiguos
		# y por si la cadena de eventos llega aqui via otra ruta.
		UnlockBuildingEffect.new(CUARTEL_BUILDING),
	]
	choices = [choice]
