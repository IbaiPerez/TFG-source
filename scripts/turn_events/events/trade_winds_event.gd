extends TurnEvent
class_name TradeWindsEvent

## Vientos de Comercio - Evento positivo repetible
## +oro% durante 3 turnos (escalado: 15 + turno*0.3)


func _init():
	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(8, Comparison.Type.GREATER_EQUAL),
		GoldGenerationCondition.new(10, Comparison.Type.GREATER_EQUAL),
	]

	var choice := TurnEventChoice.new()
	choice.label = "Aprovechar los vientos"
	choice.description = "Bonus temporal a la produccion de oro."
	choice.effects = [
		ScaledStatModifierEffect.new(
			"trade_winds_gold", "Vientos de Comercio",
			StatModifier.StatType.PERCENT_GOLD,
			15.0, 0.3, 0.0, 3
		)
	]
	choices = [choice]
