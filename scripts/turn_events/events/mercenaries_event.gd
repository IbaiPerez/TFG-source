extends TurnEvent
class_name MercenariesEvent

## Mercenarios - Evento de intercambio repetible
## Paga oro para recibir una carta de Colonizar

const COLONIZE_CARD = preload("res://resources/cards/colonize_card.tres")


func _init():
	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(12, Comparison.Type.GREATER_EQUAL),
	]

	# Opcion 1: contratar mercenarios
	var hire := TurnEventChoice.new()
	hire.label = "Contratar mercenarios"
	hire.description = "Paga oro para recibir una carta de Colonizar."
	hire.cost = ScaledGoldCost.new(50.0, 1.2, 0.0)
	hire.effects = [AddCardEffect.new(COLONIZE_CARD)]

	# Opcion 2: rechazar
	var decline := TurnEventChoice.new()
	decline.label = "Rechazar la oferta"
	decline.description = "No contratas mercenarios."
	decline.effects = []

	choices = [hire, decline]
