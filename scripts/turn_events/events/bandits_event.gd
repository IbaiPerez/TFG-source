extends TurnEvent
class_name BanditsEvent

## Bandidos en los Caminos - Evento negativo repetible (con opción de pagar)
## -oro flat durante 3 turnos (escalado: 8 + turno*0.3)
## Alternativa: pagar oro para contratar mercenarios


func _init():
	category = EventCategory.Type.FLAVOUR

	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(5),
		ControlledTilesCondition.new(4),
	]

	# Opcion 1: sufrir el robo
	var suffer := make_choice("EVT_BANDITS_CH1_LABEL", "EVT_BANDITS_CH1_DESC", [
		ScaledStatModifierEffect.new(
			"bandits_gold", "EVT_BANDITS_TITLE",
			StatModifier.StatType.FLAT_GOLD,
			-8.0, -0.3, 0.0, 3
		)
	])

	# Opcion 2: pagar oro para evitarlo
	var pay := make_choice("EVT_BANDITS_CH2_LABEL", "EVT_BANDITS_CH2_DESC",
		[], TurnEventCost.new(30.0, 0.6, 0.0))

	choices = [suffer, pay]
