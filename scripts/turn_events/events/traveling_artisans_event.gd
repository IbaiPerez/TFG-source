extends TurnEvent
class_name TravelingArtisansEvent

## Artesanos Ambulantes - Evento positivo repetible
## -15% coste construccion durante 4 turnos


func _init():
	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
		TurnNumberCondition.new(6, Comparison.Type.GREATER_EQUAL),
	]

	var choice := TurnEventChoice.new()
	choice.label = "Contratar artesanos"
	choice.description = "Reduccion temporal del coste de construccion."
	choice.effects = [
		ScaledBuildCostModifierEffect.new(
			"artisans_discount", "Artesanos Ambulantes",
			15.0, 0.0, 4
		)
	]
	choices = [choice]
