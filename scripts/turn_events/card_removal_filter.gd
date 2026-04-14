extends RefCounted
class_name CardRemovalFilter

## Si no es vacio, solo cartas con este id
var card_id:String = ""
## Si no es -1, solo cartas de este tipo
var card_type:int = -1
## Si no es null, solo buscar en esta pila concreta
var pile:CardPile = null


func get_candidates(stats:Stats) -> Array[Card]:
	var piles_to_search:Array[CardPile] = _get_piles(stats)
	var candidates:Array[Card] = []
	for p in piles_to_search:
		for card in p.cards:
			if _matches(card):
				candidates.append(card)
	return candidates


func find_first(stats:Stats) -> Dictionary:
	var piles_to_search:Array[CardPile] = _get_piles(stats)
	for p in piles_to_search:
		for card in p.cards:
			if _matches(card):
				return {"card": card, "pile": p}
	return {}


func has_match(stats:Stats) -> bool:
	return not find_first(stats).is_empty()


func _get_piles(stats:Stats) -> Array[CardPile]:
	if pile != null:
		return [pile]
	return [stats.discard_pile, stats.draw_pile]


func _matches(card:Card) -> bool:
	if card_id != "" and card.id != card_id:
		return false
	if card_type != -1 and card.type != card_type:
		return false
	return true
