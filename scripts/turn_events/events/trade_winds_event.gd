extends TurnEvent
class_name TradeWindsEvent

## Vientos de Comercio - Evento positivo repetible
## +oro% durante 3 turnos (escalado: 15 + turno*0.3)


func _init():
	category = EventCategory.Type.FLAVOUR

	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(8, Comparison.Type.GREATER_EQUAL),
		GoldGenerationCondition.new(10, Comparison.Type.GREATER_EQUAL),
	]

	var choice := TurnEventChoice.new()
	choice.label = tr("EVT_TRADE_WINDS_CH1_LABEL")
	choice.description = tr("EVT_TRADE_WINDS_CH1_DESC")
	choice.effects = [
		ScaledStatModifierEffect.new(
			"trade_winds_gold", "EVT_TRADE_WINDS_TITLE",
			StatModifier.StatType.PERCENT_GOLD,
			15.0, 0.3, 0.0, 3
		)
	]
	choices = [choice]
