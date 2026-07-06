extends TurnEvent
class_name CattleFairEvent

## Feria de Ganado - Evento de intercambio repetible
## Intercambio: pierdes comida flat 3 turnos / ganas +oro% 3 turnos


func _init():
	category = EventCategory.Type.FLAVOUR

	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(5, Comparison.Type.GREATER_EQUAL),
		FoodThresholdCondition.new(10, Comparison.Type.GREATER_EQUAL),
	]

	# Opcion 1: aceptar el intercambio
	var trade := TurnEventChoice.new()
	trade.label = tr("EVT_CATTLE_FAIR_CH1_LABEL")
	trade.description = tr("EVT_CATTLE_FAIR_CH1_DESC")
	trade.effects = [
		ScaledStatModifierEffect.new(
			"cattle_fair_food", "EVT_CATTLE_FAIR_TITLE",
			StatModifier.StatType.FLAT_FOOD,
			-8.0, -0.2, 0.0, 3
		),
		ScaledStatModifierEffect.new(
			"cattle_fair_gold", "EVT_CATTLE_FAIR_TITLE",
			StatModifier.StatType.PERCENT_GOLD,
			15.0, 0.2, 0.0, 3
		),
	]

	# Opcion 2: rechazar
	var decline := TurnEventChoice.new()
	decline.label = tr("EVT_CATTLE_FAIR_CH2_LABEL")
	decline.description = tr("EVT_CATTLE_FAIR_CH2_DESC")
	decline.effects = []

	choices = [trade, decline]
