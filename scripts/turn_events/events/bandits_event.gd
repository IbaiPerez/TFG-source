extends TurnEvent
class_name BanditsEvent

## Bandidos en los Caminos - Evento negativo repetible (con opción de pagar)
## -oro flat durante 3 turnos (escalado: 8 + turno*0.3)
## Alternativa: pagar oro para contratar mercenarios


func _init():
	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(5, Comparison.Type.GREATER_EQUAL),
		ControlledTilesCondition.new(4, Comparison.Type.GREATER_EQUAL),
	]

	# Opcion 1: sufrir el robo
	var suffer := TurnEventChoice.new()
	suffer.label = "Ignorar a los bandidos"
	suffer.description = "Los bandidos saquean tus rutas comerciales."
	suffer.effects = [
		ScaledStatModifierEffect.new(
			"bandits_gold", "Bandidos",
			StatModifier.StatType.FLAT_GOLD,
			-8.0, -0.3, 0.0, 3
		)
	]

	# Opcion 2: pagar oro para evitarlo
	var pay := TurnEventChoice.new()
	pay.label = "Contratar escoltas"
	pay.description = "Paga oro para proteger tus caravanas."
	pay.cost = ScaledGoldCost.new(30.0, 0.6, 0.0)
	pay.effects = []

	choices = [suffer, pay]
