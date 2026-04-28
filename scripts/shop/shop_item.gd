extends Resource
class_name ShopItem

## Representa un articulo de la tienda: una carta con su precio y stock.

var card:Card
var price:int = 10
var stock:int = 1

var _sold_count:int = 0


func is_available() -> bool:
	return stock == -1 or _sold_count < stock


func can_afford(gold:int) -> bool:
	return gold >= price


func purchase(stats:Stats) -> void:
	stats.total_gold -= price
	var instance := card.duplicate()
	stats.sync_card_buildings(instance)
	stats.discard_pile.add_card(instance)
	_sold_count += 1
