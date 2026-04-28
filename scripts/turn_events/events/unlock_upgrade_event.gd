extends TurnEvent
class_name UnlockUpgradeEvent

## Maestros del Oficio
## Se activa al tener 4+ edificios construidos tras el Boom de Construcción.
## Añade una carta de Mejorar Edificio al descarte.
## Evento único: solo ocurre una vez por partida.

const UPGRADE_CARD = preload("res://resources/cards/upgrade_building_card.tres")


func _init():
	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		BuildingCountCondition.new(4, Comparison.Type.GREATER_EQUAL),
	]

	var choice := TurnEventChoice.new()
	choice.label = "Acoger a los maestros"
	choice.description = "Recibes una carta de Mejorar Edificio."
	choice.effects = [
		AddCardEffect.new(UPGRADE_CARD),
		AddToCardPoolEffect.new(UPGRADE_CARD, 8.0, -0.1, 3.0),
	]
	choices = [choice]
