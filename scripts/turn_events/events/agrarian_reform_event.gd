extends TurnEvent
class_name AgrarianReformEvent

## Reforma Agraria - Evento de intercambio repetible
## Intercambio: -oro% 4 turnos / +comida% 4 turnos


func _init():
	category = EventCategory.Type.FLAVOUR

	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(10),
		ControlledTilesCondition.new(8),
	]

	# Opcion 1: implementar la reforma
	var reform := make_choice("EVT_AGRARIAN_CH1_LABEL", "EVT_AGRARIAN_CH1_DESC", [
		ScaledStatModifierEffect.new(
			"agrarian_reform_gold", "EVT_AGRARIAN_TITLE",
			StatModifier.StatType.PERCENT_GOLD,
			-15.0, -0.2, 0.0, 4
		),
		ScaledStatModifierEffect.new(
			"agrarian_reform_food", "EVT_AGRARIAN_TITLE",
			StatModifier.StatType.PERCENT_FOOD,
			20.0, 0.3, 0.0, 4
		),
	])

	# Opcion 2: rechazar
	var decline := make_choice("EVT_AGRARIAN_CH2_LABEL", "EVT_AGRARIAN_CH2_DESC", [])

	choices = [reform, decline]
