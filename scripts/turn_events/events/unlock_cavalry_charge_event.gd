extends TurnEvent
class_name UnlockCavalryChargeEvent

## Doctrina de Carga de Caballería
## Se desbloquea cuando ya has abierto un frente y tienes al menos 1
## Caballería en el pool. Otorga la carta táctica "Carga de Caballería".

const TACTIC_CARD = preload("res://resources/cards/tactic_cavalry_charge.tres")


func _init():
	id = "unlock_cavalry_charge"
	title = "Doctrina de Carga"
	description = "Tus jinetes han demostrado su valía. Tus generales proponen formalizar la doctrina de carga frontal: una embestida coordinada que aplaste las líneas enemigas... cuando el terreno lo permita."
	weight = 80.0
	unique = true
	allow_skip = true
	category = EventCategory.Type.OPTIONAL_PROGRESSION

	conditions = [
		UniqueEventOccurredCondition.new("unlock_open_front"),
		HasRecruitedTroopOfTypeCondition.new(Troop.TroopType.CABALLERIA, 1),
	]

	var choice := TurnEventChoice.new()
	choice.label = "Adoptar la doctrina de carga"
	choice.description = "Recibes la carta de Carga de Caballería y se desbloquea en el pool."
	choice.effects = [
		AddCardEffect.new(TACTIC_CARD),
		AddToCardPoolEffect.new(TACTIC_CARD, 5.0, -0.1, 1.5),
	]
	choices = [choice]
