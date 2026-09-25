extends TurnEvent
class_name AbundantHarvestEvent

## Cosecha Abundante - Evento positivo repetible
## +comida por turno durante 3 turnos (escalado: 5 + turno*0.2). La comida es un
## balance que se recalcula cada turno, no un depósito: un evento solo puede
## tocarla a través de la producción.


func _init():
	category = EventCategory.Type.FLAVOUR

	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(5),
	]

	var choice := make_choice("EVT_ABUNDANT_CH1_LABEL", "EVT_ABUNDANT_CH1_DESC",
		[ScaledStatModifierEffect.new(
			"abundant_harvest_food", "EVT_ABUNDANT_TITLE",
			StatModifier.StatType.FLAT_FOOD, 5.0, 0.2, 0.0, 3
		)])
	choices = [choice]
