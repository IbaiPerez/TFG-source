extends TurnEvent
class_name TradeAgreementEvent

## Tratado Comercial - Evento de intercambio repetible
## Paga oro ahora para obtener +oro% permanente


func _init():
	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(10, Comparison.Type.GREATER_EQUAL),
		GoldGenerationCondition.new(15, Comparison.Type.GREATER_EQUAL),
	]

	# Opcion 1: invertir en el tratado
	var invest := TurnEventChoice.new()
	invest.label = "Firmar el tratado"
	invest.description = "Paga oro para obtener +10% oro permanente."
	invest.cost = ScaledGoldCost.new(60.0, 1.0, 0.0)
	invest.effects = [
		ApplyModifierEffect.new(
			StatModifier.new(
				"trade_agreement_gold", "Tratado Comercial",
				StatModifier.StatType.PERCENT_GOLD, 10.0, -1
			)
		)
	]

	# Opcion 2: rechazar
	var decline := TurnEventChoice.new()
	decline.label = "Rechazar el tratado"
	decline.description = "No firmas el acuerdo."
	decline.effects = []

	choices = [invest, decline]
