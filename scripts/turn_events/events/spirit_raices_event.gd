extends TurnEvent
class_name SpiritRaicesEvent

## Raíces Protectoras: -15% coste de construcción durante 3 turnos.
## Requiere tener el Santuario del Bosque construido.


func _init():
	category = EventCategory.Type.SPIRIT

	conditions = [
		HasBuildingCondition.new("BLD_SANTUARIO_NAME")
	]

	var choice := TurnEventChoice.new()
	choice.label = tr("EVT_SPIRIT_RAICES_CH1_LABEL")
	choice.description = tr("EVT_SPIRIT_RAICES_CH1_DESC")
	choice.effects = [
		ScaledBuildCostModifierEffect.new(
			"spirit_raices", "Raíces Protectoras",
			15.0, 0.0, 3
		)
	]
	choices = [choice]
