extends TurnEventEffect
class_name RemoveCardEventEffect

## Filtro para eliminacion automatica (sin eleccion del jugador)
var auto_filter:CardRemovalFilter = null
## Filtro para eliminacion con eleccion del jugador
var player_filter:CardRemovalFilter = null


func _init(p_auto_filter:CardRemovalFilter = null, p_player_filter:CardRemovalFilter = null):
	auto_filter = p_auto_filter
	player_filter = p_player_filter


func needs_player_input() -> bool:
	return player_filter != null


func get_candidates(stats:Stats) -> Array[Card]:
	if player_filter:
		return player_filter.get_candidates(stats)
	return []


func execute(context:EventContext, chosen_card:Card = null) -> void:
	if auto_filter != null:
		var result = auto_filter.find_first(context.stats)
		if not result.is_empty():
			result.pile.remove_card(result.card)

	if player_filter != null and chosen_card != null:
		_remove_from_piles(context.stats, chosen_card)


func _remove_from_piles(stats:Stats, card:Card) -> void:
	for p in [stats.discard_pile, stats.draw_pile]:
		if p.remove_card(card):
			return
