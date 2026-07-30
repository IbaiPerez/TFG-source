extends TurnEvent
class_name UnlockArrowRainEvent

## Doctrina de Lluvia de Flechas
## Se desbloquea cuando ya has abierto un frente y tienes al menos 1
## tropa A Distancia en el pool. Otorga una carta táctica que potencia
## a los tiradores en campo abierto.

const TACTIC_CARD = preload("res://resources/cards/tactic_arrow_rain.tres")


func _init():
	category = EventCategory.Type.OPTIONAL_PROGRESSION

	conditions = [
		UniqueEventOccurredCondition.new("unlock_open_front"),
		HasRecruitedTroopOfTypeCondition.new(Troop.TroopType.A_DISTANCIA, 1),
	]

	choices = [make_card_unlock_choice(TACTIC_CARD,
		"EVT_UNLOCK_ARROW_RAIN_CH1_LABEL", "EVT_UNLOCK_ARROW_RAIN_CH1_DESC", 5.0, -0.1, 1.5)]
