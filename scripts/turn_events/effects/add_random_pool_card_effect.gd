extends TurnEventEffect
class_name AddRandomPoolCardEffect

## Selecciona una carta aleatoria del pool desbloqueado usando pesos
## dinámicos según el turno actual, y la añade al descarte.


func execute(context:EventContext, _chosen_card:Card = null) -> void:
	var pool := context.stats.unlocked_card_pool
	if pool.is_empty():
		push_warning("Pool de cartas desbloqueadas vacío")
		return

	var turn := context.stats.turn_number
	var card := _weighted_pick(pool, turn)
	if card:
		var instance := card.duplicate()
		context.stats.sync_card_buildings(instance)
		context.stats.discard_pile.add_card(instance)


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
