extends TurnEvent
class_name UnlockUpgradeEvent

## Maestros del Oficio
## Se activa al tener 4+ edificios construidos tras el Boom de Construcción.
## Añade una carta de Mejorar Edificio al descarte.
## Evento único: solo ocurre una vez por partida.

const UPGRADE_CARD = preload("res://resources/cards/upgrade_building_card.tres")


func _init():
	category = EventCategory.Type.CORE_PROGRESSION

	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		BuildingCountCondition.new(4, Comparison.Type.GREATER_EQUAL),
	]

	choices = [make_card_unlock_choice(UPGRADE_CARD,
		"EVT_UNLOCK_UPGRADE_CH1_LABEL", "EVT_UNLOCK_UPGRADE_CH1_DESC", 8.0, -0.1, 3.0)]
