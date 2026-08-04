extends TurnEvent
class_name UnlockPhalanxEvent

## Doctrina del Muro de Lanzas y Escudos (Falange)
## Se desbloquea cuando ya has abierto un frente y tienes al menos 1
## Piquero o Infantería Ligera en el pool. Otorga una carta defensiva
## que beneficia a piqueros e infantería ligera, especialmente en
## terreno accidentado.

const TACTIC_CARD = preload("res://resources/cards/tactic_phalanx.tres")


func _init():
	category = EventCategory.Type.OPTIONAL_PROGRESSION

	conditions = [
		UniqueEventOccurredCondition.new("unlock_open_front"),
		HasRecruitedTroopOfTypeCondition.new(Troop.TroopType.PIQUEROS, 1),
	]

	choices = [make_card_unlock_choice(TACTIC_CARD,
		"EVT_UNLOCK_PHALANX_CH1_LABEL", "EVT_UNLOCK_PHALANX_CH1_DESC", GameBalance.TACTIC_POOL_WEIGHT_BASE,
		GameBalance.TACTIC_POOL_WEIGHT_PER_TURN, GameBalance.TACTIC_POOL_WEIGHT_MIN)]
