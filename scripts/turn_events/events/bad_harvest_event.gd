extends TurnEvent
class_name BadHarvestEvent

## Mala Cosecha - Evento negativo repetible (con opción de pagar)
## -comida flat durante 3 turnos (escalado: 10 + turno*0.3)
## Alternativa: pagar oro para evitarlo


func _init():
	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(4, Comparison.Type.GREATER_EQUAL),
	]

	# Opcion 1: sufrir la penalizacion
	var suffer := TurnEventChoice.new()
	suffer.label = "Aceptar las perdidas"
	suffer.description = "Tus campos producen menos de lo esperado."
	suffer.effects = [
		ScaledStatModifierEffect.new(
			"bad_harvest_food", "Mala Cosecha",
			StatModifier.StatType.FLAT_FOOD,
			-10.0, -0.3, 0.0, 3
		)
	]

	# Opcion 2: pagar oro para evitarlo
	var pay := TurnEventChoice.new()
	pay.label = "Comprar grano de emergencia"
	pay.description = "Paga oro para compensar las perdidas."
	pay.cost = ScaledGoldCost.new(25.0, 0.5, 0.0)
	pay.effects = []

	choices = [suffer, pay]
