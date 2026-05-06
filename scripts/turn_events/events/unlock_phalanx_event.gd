extends TurnEvent
class_name UnlockPhalanxEvent

## Doctrina del Muro de Lanzas y Escudos (Falange)
## Se desbloquea cuando ya has abierto un frente y tienes al menos 1
## Piquero o Infantería Ligera en el pool. Otorga una carta defensiva
## que beneficia a piqueros e infantería ligera, especialmente en
## terreno accidentado.

const TACTIC_CARD = preload("res://resources/cards/tactic_phalanx.tres")


func _init():
	id = "unlock_phalanx"
	title = "Doctrina de la Falange"
	description = "Tus piqueros forman filas con disciplina. Tus instructores proponen una formación cerrada de lanzas y escudos: un muro humano que detiene cualquier embestida en terreno favorable."
	weight = 80.0
	unique = true
	allow_skip = true

	conditions = [
		UniqueEventOccurredCondition.new("unlock_open_front"),
		HasRecruitedTroopOfTypeCondition.new(Troop.TroopType.PIQUEROS, 1),
	]

	var choice := TurnEventChoice.new()
	choice.label = "Adoptar la formación de falange"
	choice.description = "Recibes la carta del Muro de Lanzas y Escudos y se desbloquea en el pool."
	choice.effects = [
		AddCardEffect.new(TACTIC_CARD),
		AddToCardPoolEffect.new(TACTIC_CARD, 5.0, -0.1, 1.5),
	]
	choices = [choice]
