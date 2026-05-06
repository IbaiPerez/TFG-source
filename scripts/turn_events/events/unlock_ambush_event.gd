extends TurnEvent
class_name UnlockAmbushEvent

## Doctrina de Emboscada
## Se desbloquea cuando ya has abierto un frente y tienes al menos 1
## Infantería Ligera en el pool. Otorga una carta táctica que potencia
## a la infantería ligera en terreno difícil.

const TACTIC_CARD = preload("res://resources/cards/tactic_ambush.tres")


func _init():
	id = "unlock_ambush"
	title = "Doctrina de Emboscada"
	description = "Tus exploradores conocen cada sendero, cada arboleda, cada pantano. Tus capitanes proponen una doctrina de combate irregular: golpear desde la maleza y desaparecer antes de que el enemigo reaccione."
	weight = 80.0
	unique = true
	allow_skip = true

	conditions = [
		UniqueEventOccurredCondition.new("unlock_open_front"),
		HasRecruitedTroopOfTypeCondition.new(Troop.TroopType.INFANTERIA_LIGERA, 1),
	]

	var choice := TurnEventChoice.new()
	choice.label = "Adoptar la doctrina de emboscada"
	choice.description = "Recibes la carta de Emboscada y se desbloquea en el pool."
	choice.effects = [
		AddCardEffect.new(TACTIC_CARD),
		AddToCardPoolEffect.new(TACTIC_CARD, 5.0, -0.1, 1.5),
	]
	choices = [choice]
