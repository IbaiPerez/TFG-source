extends Node
class_name TurnEventManager

var stats:Stats


func evaluate(context:EventContext) -> TurnEvent:
	# Fase 1: probabilidad de que ocurra un evento
	if randf() > stats.event_chance:
		return null

	# Fase 2: filtrar eventos disponibles
	var available:Array[TurnEvent] = []
	for event in stats.available_events:
		if event.unique and event.id in stats.used_unique_events:
			continue
		if event.is_available(context):
			available.append(event)

	if available.is_empty():
		return null

	# Fase 3: seleccion ponderada por peso
	var picked := _weighted_pick(available)
	if picked:
		picked.prepare(context)
	return picked


func resolve(event:TurnEvent, choice:TurnEventChoice,
		context:EventContext, chosen_cards:Dictionary = {}) -> void:
	choice.execute(context, chosen_cards)
	if event.unique:
		stats.used_unique_events.append(event.id)


func _weighted_pick(events:Array[TurnEvent]) -> TurnEvent:
	var total_weight := 0.0
	for e in events:
		total_weight += e.weight

	var roll := randf() * total_weight
	var cumulative := 0.0
	for e in events:
		cumulative += e.weight
		if roll <= cumulative:
			return e

	return events.back()
