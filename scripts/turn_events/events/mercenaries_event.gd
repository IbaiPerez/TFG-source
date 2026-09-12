extends TurnEvent
class_name MercenariesEvent

## Mercenarios - Evento de intercambio repetible
## Paga oro para recibir una carta de Colonizar

const COLONIZE_CARD = preload("res://resources/cards/colonize_card.tres")


func _init():
	category = EventCategory.Type.FLAVOUR

	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(12),
	]

	# Opcion 1: contratar mercenarios
	var hire := make_choice("EVT_MERCENARIES_CH1_LABEL", "EVT_MERCENARIES_CH1_DESC",
		[AddCardEffect.new(COLONIZE_CARD)], TurnEventCost.new(50.0, 1.2, 0.0))

	# Opcion 2: rechazar
	var decline := make_choice("EVT_MERCENARIES_CH2_LABEL", "EVT_MERCENARIES_CH2_DESC", [])

	choices = [hire, decline]
