extends TurnEventEffect
class_name RemoveCardEventEffect

## El jugador elige una carta de su mazo (draw + discard) y la elimina.


func needs_player_input() -> bool:
	return true


func get_candidates(stats:Stats) -> Array[Card]:
	var candidates:Array[Card] = []
	candidates.append_array(stats.discard_pile.cards)
	candidates.append_array(stats.draw_pile.cards)
	return candidates


func execute(context:EventContext, chosen_card:Card = null) -> void:
	if chosen_card == null:
		return
	for p in [context.stats.discard_pile, context.stats.draw_pile]:
		if p.remove_card(chosen_card):
			return
