extends TurnEvent
class_name CattleFairEvent

## Feria de Ganado - Evento de intercambio repetible
## Intercambio: pierdes comida flat 3 turnos / ganas +oro% 3 turnos


func _init():
	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(5, Comparison.Type.GREATER_EQUAL),
		FoodThresholdCondition.new(10, Comparison.Type.GREATER_EQUAL),
	]

	# Opcion 1: aceptar el intercambio
	var trade := TurnEventChoice.new()
	trade.label = "Vender ganado"
	trade.description = "Pierdes comida pero ganas oro durante 3 turnos."
	trade.effects = [
		ScaledStatModifierEffect.new(
			"cattle_fair_food", "Feria de Ganado",
			StatModifier.StatType.FLAT_FOOD,
			-8.0, -0.2, 0.0, 3
		),
		ScaledStatModifierEffect.new(
			"cattle_fair_gold", "Feria de Ganado",
			StatModifier.StatType.PERCENT_GOLD,
			15.0, 0.2, 0.0, 3
		),
	]

	# Opcion 2: rechazar
	var decline := TurnEventChoice.new()
	decline.label = "Rechazar la oferta"
	decline.description = "No participas en la feria."
	decline.effects = []

	choices = [trade, decline]
