extends TurnEvent
class_name CardOfferingEvent

## Ofrenda de Cartas
## Evento repetible y saltable que otorga una copia de una carta
## del pool de cartas desbloqueadas.
## La carta se precalcula al dispararse el evento (en prepare())
## y se muestra en la descripción de la opción.
## Requiere que haya ocurrido construction_boom.

## Carta preseleccionada para esta instancia del evento.
var _selected_card:Card = null


func _init():
	conditions = [
		UniqueEventOccurredCondition.new("construction_boom"),
	]
	# Las choices se configuran en prepare() con la carta elegida.
	choices = []


func is_available(context:EventContext) -> bool:
	if not super.is_available(context):
		return false
	# Solo disponible si el pool tiene cartas
	return not context.stats.unlocked_card_pool.is_empty()


func prepare(context:EventContext) -> void:
	_selected_card = _weighted_pick(context.stats.unlocked_card_pool,
			context.stats.turn_number)

	if _selected_card == null:
		choices = []
		return

	var choice := TurnEventChoice.new()
	choice.label = "Aceptar la ofrenda"
	choice.description = "Recibes una copia de [b]%s[/b]." % _selected_card.id
	choice.effects = [AddCardEffect.new(_selected_card)]
	choices = [choice]


func _weighted_pick(pool:Array[UnlockedCardEntry], turn:int) -> Card:
	var total_weight := 0.0
	for entry in pool:
		total_weight += entry.get_weight(turn)

	if total_weight <= 0.0:
		return null

	var roll := randf() * total_weight
	var cumulative := 0.0
	for entry in pool:
		cumulative += entry.get_weight(turn)
		if roll <= cumulative:
			return entry.card

	return pool.back().card
