extends TurnEvent
class_name UnlockCavalryChargeEvent

## Doctrina de Carga de Caballería
## Se desbloquea cuando ya has abierto un frente y tienes al menos 1
## Caballería en el pool. Otorga la carta táctica "Carga de Caballería".

const TACTIC_CARD = preload("res://resources/cards/tactic_cavalry_charge.tres")


func _init():
	category = EventCategory.Type.OPTIONAL_PROGRESSION

	conditions = [
		UniqueEventOccurredCondition.new("unlock_open_front"),
		HasRecruitedTroopOfTypeCondition.new(Troop.TroopType.CABALLERIA, 1),
	]

	choices = [make_card_unlock_choice(TACTIC_CARD,
		"EVT_UNLOCK_CAVALRY_CHARGE_CH1_LABEL", "EVT_UNLOCK_CAVALRY_CHARGE_CH1_DESC", 5.0, -0.1, 1.5)]
