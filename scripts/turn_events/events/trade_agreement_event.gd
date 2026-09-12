extends TurnEvent
class_name TradeAgreementEvent

## Tratado Comercial - Evento de intercambio repetible
## Paga oro ahora para obtener +oro% permanente


func _init():
	category = EventCategory.Type.FLAVOUR

	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(10),
		GoldGenerationCondition.new(15),
	]

	# Opcion 1: invertir en el tratado
	var invest := make_choice("EVT_TRADE_AGREEMENT_CH1_LABEL", "EVT_TRADE_AGREEMENT_CH1_DESC", [
		ApplyModifierEffect.new(
			StatModifier.new(
				"trade_agreement_gold", "EVT_TRADE_AGREEMENT_TITLE",
				StatModifier.StatType.PERCENT_GOLD, 10.0, -1
			)
		)
	], TurnEventCost.new(60.0, 1.0, 0.0))

	# Opcion 2: rechazar
	var decline := make_choice("EVT_TRADE_AGREEMENT_CH2_LABEL", "EVT_TRADE_AGREEMENT_CH2_DESC", [])

	choices = [invest, decline]
