extends TurnEvent
class_name TravelingArtisansEvent

## Artesanos Ambulantes - Evento positivo repetible
## -15% coste construccion durante 4 turnos


func _init():
	category = EventCategory.Type.FLAVOUR

	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(6),
	]

	var choice := make_choice("EVT_TRAVELING_ARTISANS_CH1_LABEL", "EVT_TRAVELING_ARTISANS_CH1_DESC",
		[
		ScaledBuildCostModifierEffect.new(
			"artisans_discount", "EVT_TRAVELING_ARTISANS_TITLE",
			15.0, 0.0, 4
		)
	])
	choices = [choice]
