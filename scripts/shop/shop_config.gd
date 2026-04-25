extends Resource
class_name ShopConfig

## Configuracion de una tienda generada dinamicamente.
## El coste de purga se recalcula tras cada uso usando Stats.total_purges_done.

var items:Array[ShopItem] = []
var purge_cost:int = 20
var allow_purge:bool = true
var max_purges:int = -1 ## -1 = ilimitado por visita

var _purges_done_this_visit:int = 0


func can_purge(gold:int) -> bool:
	if not allow_purge:
		return false
	if max_purges != -1 and _purges_done_this_visit >= max_purges:
		return false
	return gold >= purge_cost


func purge_card(card:Card, stats:Stats) -> bool:
	## Elimina la carta del mazo completo (draw_pile o discard_pile).
	## Retorna true si se elimino correctamente.
	if not can_purge(stats.total_gold):
		return false

	var removed := stats.draw_pile.remove_card(card)
	if not removed:
		removed = stats.discard_pile.remove_card(card)

	if removed:
		stats.total_gold -= purge_cost
		stats.total_purges_done += 1
		_purges_done_this_visit += 1
		# Recalcular coste para la siguiente purga
		purge_cost = ShopGenerator._get_purge_cost(stats.total_purges_done)

	return removed
