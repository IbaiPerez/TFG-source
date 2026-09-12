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
	var purge := make_choice("EVT_DECK_PURGE_CH1_LABEL", "EVT_DECK_PURGE_CH1_DESC",
		[RemoveCardEventEffect.new()])

	# Opcion 2: no hacer nada
	var skip := make_choice("EVT_DECK_PURGE_CH2_LABEL", "EVT_DECK_PURGE_CH2_DESC", [])

	choices = [purge, skip]
