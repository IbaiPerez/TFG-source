extends TurnEvent
class_name UnlockAmbushEvent

## Doctrina de Emboscada
## Se desbloquea cuando ya has abierto un frente y tienes al menos 1
## Infantería Ligera en el pool. Otorga una carta táctica que potencia
## a la infantería ligera en terreno difícil.

const TACTIC_CARD = preload("res://resources/cards/tactic_ambush.tres")


func _init():
	category = EventCategory.Type.OPTIONAL_PROGRESSION

	conditions = [
		UniqueEventOccurredCondition.new("unlock_open_front"),
		HasRecruitedTroopOfTypeCondition.new(Troop.TroopType.INFANTERIA_LIGERA, 1),
	]

	choices = [make_card_unlock_choice(TACTIC_CARD,
		"EVT_UNLOCK_AMBUSH_CH1_LABEL", "EVT_UNLOCK_AMBUSH_CH1_DESC", 5.0, -0.1, 1.5)]
