extends RefCounted
class_name TurnEventCost

var gold:int = 0
var food:int = 0

## Eliminacion automatica: carta concreta sin eleccion del jugador
var auto_remove_filter:CardRemovalFilter = null
## Eliminacion con eleccion: el jugador elige de las candidatas
var player_remove_filter:CardRemovalFilter = null


func can_pay(context:EventContext) -> bool:
	if gold > 0 and context.total_gold < gold:
		return false
	if food > 0 and context.food < food:
		return false
	if auto_remove_filter != null and not auto_remove_filter.has_match(context.stats):
		return false
	if player_remove_filter != null:
		var candidates = player_remove_filter.get_candidates(context.stats)
		if candidates.is_empty():
			return false
	return true


func needs_player_input() -> bool:
	return player_remove_filter != null


func get_removal_candidates(stats:Stats) -> Array[Card]:
	if player_remove_filter:
		return player_remove_filter.get_candidates(stats)
	return []


func pay(context:EventContext, chosen_card:Card = null) -> void:
	context.stats.total_gold -= gold
	context.stats.food -= food

	if auto_remove_filter != null:
		var result = auto_remove_filter.find_first(context.stats)
		if not result.is_empty():
			result.pile.remove_card(result.card)

	if player_remove_filter != null and chosen_card != null:
		_remove_from_piles(context.stats, chosen_card)


func _remove_from_piles(stats:Stats, card:Card) -> void:
	for p in [stats.discard_pile, stats.draw_pile]:
		if p.remove_card(card):
			return
