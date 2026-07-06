extends TurnEvent
class_name AgrarianReformEvent

## Reforma Agraria - Evento de intercambio repetible
## Intercambio: -oro% 4 turnos / +comida% 4 turnos


func _init():
	category = EventCategory.Type.FLAVOUR

	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(10, Comparison.Type.GREATER_EQUAL),
		ControlledTilesCondition.new(8, Comparison.Type.GREATER_EQUAL),
	]

	# Opcion 1: implementar la reforma
	var reform := TurnEventChoice.new()
	reform.label = tr("EVT_AGRARIAN_CH1_LABEL")
	reform.description = tr("EVT_AGRARIAN_CH1_DESC")
	reform.effects = [
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
	]

	# Opcion 2: rechazar
	var decline := TurnEventChoice.new()
	decline.label = tr("EVT_AGRARIAN_CH2_LABEL")
	decline.description = tr("EVT_AGRARIAN_CH2_DESC")
	decline.effects = []

	choices = [reform, decline]
