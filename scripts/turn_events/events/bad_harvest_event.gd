extends TurnEvent
class_name BadHarvestEvent

## Mala Cosecha - Evento negativo repetible (con opción de pagar)
## -comida flat durante 3 turnos (escalado: 10 + turno*0.3)
## Alternativa: pagar oro para evitarlo


func _init():
	category = EventCategory.Type.FLAVOUR

	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(4, Comparison.Type.GREATER_EQUAL),
	]

	# Opcion 1: sufrir la penalizacion
	var suffer := TurnEventChoice.new()
	suffer.label = tr("EVT_BAD_HARVEST_CH1_LABEL")
	suffer.description = tr("EVT_BAD_HARVEST_CH1_DESC")
	suffer.effects = [
		ScaledStatModifierEffect.new(
			"bad_harvest_food", "EVT_BAD_HARVEST_TITLE",
			StatModifier.StatType.FLAT_FOOD,
			-10.0, -0.3, 0.0, 3
		)
	]

	# Opcion 2: pagar oro para evitarlo
	var pay := TurnEventChoice.new()
	pay.label = tr("EVT_BAD_HARVEST_CH2_LABEL")
	pay.description = tr("EVT_BAD_HARVEST_CH2_DESC")
	pay.cost = ScaledGoldCost.new(25.0, 0.5, 0.0)
	pay.effects = []

	choices = [suffer, pay]
