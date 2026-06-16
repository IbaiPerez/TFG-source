extends TurnEvent
class_name DeckPurgeEvent

## Purga del Mazo
## Evento repetible frecuente que permite eliminar una carta del mazo.
## Requiere que haya ocurrido construction_boom.
## El jugador puede elegir una carta de su mazo para eliminarla,
## o saltar el evento sin hacer nada.


func _init():
	category = EventCategory.Type.DECK

	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
	]

	# Opcion 1: elegir una carta para eliminar
	var purge := TurnEventChoice.new()
	purge.label = tr("EVT_DECK_PURGE_CH1_LABEL")
	purge.description = tr("EVT_DECK_PURGE_CH1_DESC")
	purge.effects = [RemoveCardEventEffect.new(null, CardRemovalFilter.new())]

	# Opcion 2: no hacer nada
	var skip := TurnEventChoice.new()
	skip.label = tr("EVT_DECK_PURGE_CH2_LABEL")
	skip.description = tr("EVT_DECK_PURGE_CH2_DESC")
	skip.effects = []

	choices = [purge, skip]
