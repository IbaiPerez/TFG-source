extends TurnEvent
class_name TravelingArtisansEvent

## Artesanos Ambulantes - Evento positivo repetible
## -15% coste construccion durante 4 turnos


func _init():
	category = EventCategory.Type.FLAVOUR

	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(6, Comparison.Type.GREATER_EQUAL),
	]

	var choice := TurnEventChoice.new()
	choice.label = tr("EVT_TRAVELING_ARTISANS_CH1_LABEL")
	choice.description = tr("EVT_TRAVELING_ARTISANS_CH1_DESC")
	choice.effects = [
		ScaledBuildCostModifierEffect.new(
			"artisans_discount", "EVT_TRAVELING_ARTISANS_TITLE",
			15.0, 0.0, 4
		)
	]
	choices = [choice]
