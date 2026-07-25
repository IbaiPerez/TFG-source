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

	choices = [make_card_unlock_choice(TACTIC_CARD,
		"EVT_UNLOCK_ARROW_RAIN_CH1_LABEL", "EVT_UNLOCK_ARROW_RAIN_CH1_DESC", 5.0, -0.1, 1.5)]
