extends TurnEvent
class_name MegalopolisEvent

## Fundación de Megalópolis
## Se activa al tener una Town con 3+ edificios y 200+ oro.
## Permite al jugador elegir una Town elegible para urbanizarla a Megalópolis.
## Evento repetible con probabilidad baja.


func _init():
	category = EventCategory.Type.DECISION

	conditions = [
		# Al menos 1 Town con 3+ edificios
		TownWithBuildingsCondition.new(3),
		# Al menos 200 de oro para poder pagar
		GoldThresholdCondition.new(200),
	]

	var choice := TurnEventChoice.new()
	choice.label = tr("EVT_MEGALOPOLIS_CH1_LABEL")
	choice.description = tr("EVT_MEGALOPOLIS_CH1_DESC")
	choice.cost = TurnEventCost.new(200.0)
	choice.effects = [UrbanizeToMegalopolisEffect.new()]
	choices = [choice]
