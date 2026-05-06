extends TurnEvent
class_name UnlockOpenFrontEvent

## Conflicto fronterizo
## Se activa tras haber desbloqueado Reclutar y tener al menos 1 tropa.
## Otorga la carta de Abrir Frente.
## Evento único: solo ocurre una vez por partida.

const OPEN_FRONT_CARD = preload("res://resources/cards/open_front_card.tres")


func _init():
	id = "unlock_open_front"
	title = "Conflicto fronterizo"
	description = "Tus tropas están listas. Ha llegado el momento de tomar la iniciativa y abrir un frente de batalla."
	weight = 100.0
	unique = true
	allow_skip = false

	conditions = [
		UniqueEventOccurredCondition.new("unlock_recruit"),
		HasTroopsCondition.new(1),
	]

	var choice := TurnEventChoice.new()
	choice.label = "Preparar la ofensiva"
	choice.description = "Recibes una carta de Abrir Frente y se desbloquea en el pool de cartas."
	choice.effects = [
		AddCardEffect.new(OPEN_FRONT_CARD),
		AddToCardPoolEffect.new(OPEN_FRONT_CARD, 6.0, -0.1, 2.0),
	]
	choices = [choice]
