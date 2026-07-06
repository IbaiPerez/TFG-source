extends TurnEvent
class_name BanditsEvent

## Bandidos en los Caminos - Evento negativo repetible (con opción de pagar)
## -oro flat durante 3 turnos (escalado: 8 + turno*0.3)
## Alternativa: pagar oro para contratar mercenarios


func _init():
	category = EventCategory.Type.FLAVOUR

	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(5, Comparison.Type.GREATER_EQUAL),
		ControlledTilesCondition.new(4, Comparison.Type.GREATER_EQUAL),
	]

	# Opcion 1: sufrir el robo
	var suffer := TurnEventChoice.new()
	suffer.label = tr("EVT_BANDITS_CH1_LABEL")
	suffer.description = tr("EVT_BANDITS_CH1_DESC")
	suffer.effects = [
		ScaledStatModifierEffect.new(
			"bandits_gold", "EVT_BANDITS_TITLE",
			StatModifier.StatType.FLAT_GOLD,
			-8.0, -0.3, 0.0, 3
		)
	]

	# Opcion 2: pagar oro para evitarlo
	var pay := TurnEventChoice.new()
	pay.label = tr("EVT_BANDITS_CH2_LABEL")
	pay.description = tr("EVT_BANDITS_CH2_DESC")
	pay.cost = ScaledGoldCost.new(30.0, 0.6, 0.0)
	pay.effects = []

	choices = [suffer, pay]
