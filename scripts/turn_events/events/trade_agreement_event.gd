extends TurnEvent
class_name TradeAgreementEvent

## Tratado Comercial - Evento de intercambio repetible
## Paga oro ahora para obtener +oro% permanente


func _init():
	category = EventCategory.Type.FLAVOUR

	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(10, Comparison.Type.GREATER_EQUAL),
		GoldGenerationCondition.new(15, Comparison.Type.GREATER_EQUAL),
	]

	# Opcion 1: invertir en el tratado
	var invest := TurnEventChoice.new()
	invest.label = tr("EVT_TRADE_AGREEMENT_CH1_LABEL")
	invest.description = tr("EVT_TRADE_AGREEMENT_CH1_DESC")
	invest.cost = ScaledGoldCost.new(60.0, 1.0, 0.0)
	invest.effects = [
		ApplyModifierEffect.new(
			StatModifier.new(
				"trade_agreement_gold", "EVT_TRADE_AGREEMENT_TITLE",
				StatModifier.StatType.PERCENT_GOLD, 10.0, -1
			)
		)
	]

	# Opcion 2: rechazar
	var decline := TurnEventChoice.new()
	decline.label = tr("EVT_TRADE_AGREEMENT_CH2_LABEL")
	decline.description = tr("EVT_TRADE_AGREEMENT_CH2_DESC")
	decline.effects = []

	choices = [invest, decline]
