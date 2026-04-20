extends TurnEvent
class_name AgrarianReformEvent

## Reforma Agraria - Evento de intercambio repetible
## Intercambio: -oro% 4 turnos / +comida% 4 turnos


func _init():
	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(10, Comparison.Type.GREATER_EQUAL),
		ControlledTilesCondition.new(8, Comparison.Type.GREATER_EQUAL),
	]

	# Opcion 1: implementar la reforma
	var reform := TurnEventChoice.new()
	reform.label = "Implementar la reforma"
	reform.description = "Pierdes oro pero ganas comida durante 4 turnos."
	reform.effects = [
		ScaledStatModifierEffect.new(
			"agrarian_reform_gold", "Reforma Agraria",
			StatModifier.StatType.PERCENT_GOLD,
			-15.0, -0.2, 0.0, 4
		),
		ScaledStatModifierEffect.new(
			"agrarian_reform_food", "Reforma Agraria",
			StatModifier.StatType.PERCENT_FOOD,
			20.0, 0.3, 0.0, 4
		),
	]

	# Opcion 2: rechazar
	var decline := TurnEventChoice.new()
	decline.label = "Mantener el orden actual"
	decline.description = "No implementas la reforma."
	decline.effects = []

	choices = [reform, decline]
