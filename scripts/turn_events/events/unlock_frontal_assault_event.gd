extends TurnEvent
class_name UnlockFrontalAssaultEvent

## Doctrina de Asalto Frontal
## Se desbloquea cuando ya has abierto un frente y tienes al menos 1
## Infantería Pesada en el pool. Otorga una carta táctica que potencia
## a la infantería pesada en campo abierto.

const TACTIC_CARD = preload("res://resources/cards/tactic_frontal_assault.tres")


func _init():
	id = "unlock_frontal_assault"
	title = "Doctrina del Asalto Frontal"
	description = "Tu infantería pesada avanza como un muro de acero. Tus generales proponen una doctrina de combate frontal: armadura, disciplina y empuje implacable contra el centro enemigo."
	weight = 80.0
	unique = true
	allow_skip = true

	conditions = [
		UniqueEventOccurredCondition.new("unlock_open_front"),
		HasRecruitedTroopOfTypeCondition.new(Troop.TroopType.INFANTERIA_PESADA, 1),
	]

	var choice := TurnEventChoice.new()
	choice.label = "Adoptar la doctrina de asalto frontal"
	choice.description = "Recibes la carta de Asalto Frontal y se desbloquea en el pool."
	choice.effects = [
		AddCardEffect.new(TACTIC_CARD),
		AddToCardPoolEffect.new(TACTIC_CARD, 5.0, -0.1, 1.5),
	]
	choices = [choice]
