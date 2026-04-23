extends TurnEvent
class_name SpiritRaicesEvent

## Raíces Protectoras: -15% coste de construcción durante 3 turnos.
## Requiere tener el Santuario del Bosque construido.


func _init():
	conditions = [
		HasBuildingCondition.new("Santuario del Bosque")
	]

	var choice := TurnEventChoice.new()
	choice.label = "Aceptar la protección"
	choice.description = "Las raíces del bosque fortalecen tus cimientos. -15% coste de construcción durante 3 turnos."
	choice.effects = [
		ScaledBuildCostModifierEffect.new(
			"spirit_raices", "Raíces Protectoras",
			15.0, 0.0, 3
		)
	]
	choices = [choice]
