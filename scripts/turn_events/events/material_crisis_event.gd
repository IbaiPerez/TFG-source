extends TurnEvent
class_name MaterialCrisisEvent

## Crisis de Materiales - Evento negativo repetible (con opción de pagar)
## +25% coste de construccion durante 4 turnos
## Alternativa: pagar oro para asegurar suministros


func _init():
	category = EventCategory.Type.FLAVOUR

	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(8),
	]

	# Opcion 1: sufrir el encarecimiento
	var suffer := make_choice("EVT_MATERIAL_CRISIS_CH1_LABEL", "EVT_MATERIAL_CRISIS_CH1_DESC", [
		ScaledBuildCostModifierEffect.new(
			"material_crisis_cost", "EVT_MATERIAL_CRISIS_TITLE",
			-25.0, 0.0, 4
		)
	])

	# Opcion 2: pagar oro para evitarlo
	var pay := make_choice("EVT_MATERIAL_CRISIS_CH2_LABEL", "EVT_MATERIAL_CRISIS_CH2_DESC",
		[], TurnEventCost.new(40.0, 0.8, 0.0))

	choices = [suffer, pay]
