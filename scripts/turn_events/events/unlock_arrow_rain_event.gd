extends TurnEvent
class_name UnlockArrowRainEvent

## Doctrina de Lluvia de Flechas
## Se desbloquea cuando ya has abierto un frente y tienes al menos 1
## tropa A Distancia en el pool. Otorga una carta táctica que potencia
## a los tiradores en campo abierto.

const TACTIC_CARD = preload("res://resources/cards/tactic_arrow_rain.tres")


func _init():
	id = "unlock_arrow_rain"
	title = "Doctrina del Tiro Masivo"
	description = "Tus arqueros han perfeccionado el tiro en parábola. Tus capitanes proponen formalizar la doctrina de la lluvia de flechas: una andanada coordinada que satura el campo enemigo... siempre que el terreno permita ver el blanco."
	weight = 80.0
	unique = true
	allow_skip = true
	category = EventCategory.Type.OPTIONAL_PROGRESSION

	conditions = [
		UniqueEventOccurredCondition.new("unlock_open_front"),
		HasRecruitedTroopOfTypeCondition.new(Troop.TroopType.A_DISTANCIA, 1),
	]

	var choice := TurnEventChoice.new()
	choice.label = "Adoptar la doctrina del tiro masivo"
	choice.description = "Recibes la carta de Lluvia de Flechas y se desbloquea en el pool."
	choice.effects = [
		AddCardEffect.new(TACTIC_CARD),
		AddToCardPoolEffect.new(TACTIC_CARD, 5.0, -0.1, 1.5),
	]
	choices = [choice]
