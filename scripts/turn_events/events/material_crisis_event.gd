extends TurnEvent
class_name MaterialCrisisEvent

## Crisis de Materiales - Evento negativo repetible (con opción de pagar)
## +25% coste de construccion durante 4 turnos
## Alternativa: pagar oro para asegurar suministros


func _init():
	category = EventCategory.Type.FLAVOUR

	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(8, Comparison.Type.GREATER_EQUAL),
	]

	# Opcion 1: sufrir el encarecimiento
	var suffer := TurnEventChoice.new()
	suffer.label = tr("EVT_MATERIAL_CRISIS_CH1_LABEL")
	suffer.description = tr("EVT_MATERIAL_CRISIS_CH1_DESC")
	suffer.effects = [
		ScaledBuildCostModifierEffect.new(
			"material_crisis_cost", "Crisis de Materiales",
			-25.0, 0.0, 4
		)
	]

	# Opcion 2: pagar oro para evitarlo
	var pay := TurnEventChoice.new()
	pay.label = tr("EVT_MATERIAL_CRISIS_CH2_LABEL")
	pay.description = tr("EVT_MATERIAL_CRISIS_CH2_DESC")
	pay.cost = ScaledGoldCost.new(40.0, 0.8, 0.0)
	pay.effects = []

	choices = [suffer, pay]
