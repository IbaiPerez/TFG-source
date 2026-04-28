extends TurnEvent
class_name DeckPurgeEvent

## Purga del Mazo
## Evento repetible frecuente que permite eliminar una carta del mazo.
## Requiere que haya ocurrido construction_boom.
## El jugador puede elegir una carta de su mazo para eliminarla,
## o saltar el evento sin hacer nada.


func _init():
	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
	]

	# Opcion 1: elegir una carta para eliminar
	var purge := TurnEventChoice.new()
	purge.label = "Depurar el mazo"
	purge.description = "Elige una carta de tu mazo para eliminarla permanentemente."
	purge.effects = [RemoveCardEventEffect.new(null, CardRemovalFilter.new())]

	# Opcion 2: no hacer nada
	var skip := TurnEventChoice.new()
	skip.label = "No hacer nada"
	skip.description = "Mantienes tu mazo intacto."
	skip.effects = []

	choices = [purge, skip]
