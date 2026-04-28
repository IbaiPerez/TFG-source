extends RefCounted
class_name ShopGenerator

## Genera un ShopConfig dinámicamente a partir del pool de cartas
## desbloqueadas del jugador, seleccionando por tipo y peso.

## Rango de precios base (antes de escalado)
const BASIC_PRICE_MIN := 30
const BASIC_PRICE_MAX := 50
const SPECIAL_PRICE_MIN := 50
const SPECIAL_PRICE_MAX := 80

## Escalado de precio por turno: +2% por turno a partir del turno base
const PRICE_SCALE_PER_TURN := 0.02

## Purga: coste base + incremento por cada purga previa
const PURGE_BASE_COST := 20
const PURGE_COST_PER_USE := 8


## Genera una tienda basica:
## 2-3 cartas del pool desbloqueado + 1 uso de purga
static func generate_basic_shop(stats:Stats) -> ShopConfig:
	var config := ShopConfig.new()
	var turn := stats.turn_number
	var pool := stats.get_full_shop_pool()

	# 2 o 3 cartas ponderadas del pool
	var num_cards := randi_range(2, 3)
	var picked := _weighted_pick_cards(pool, num_cards, turn)
	for card in picked:
		var item := ShopItem.new()
		item.card = card
		item.price = _price_for_card(card, turn, 8)
		item.stock = 1
		config.items.append(item)

	# Purga
	config.allow_purge = true
	config.max_purges = 1
	config.purge_cost = _get_purge_cost(stats.total_purges_done)

	return config


## Genera una tienda especial:
## 3 cartas del pool desbloqueado + 2-3 usos de purga
static func generate_special_shop(stats:Stats) -> ShopConfig:
	var config := ShopConfig.new()
	var turn := stats.turn_number
	var pool := stats.get_full_shop_pool()

	# 3 cartas ponderadas del pool
	var picked := _weighted_pick_cards(pool, 3, turn)
	for card in picked:
		var item := ShopItem.new()
		item.card = card
		item.price = _price_for_card(card, turn, 12)
		item.stock = 1
		config.items.append(item)

	# 2-3 usos de purga
	config.allow_purge = true
	config.max_purges = randi_range(2, 3)
	config.purge_cost = _get_purge_cost(stats.total_purges_done)

	return config


## Calcula el precio según el tipo de carta.
static func _price_for_card(card:Card, turn:int, base_turn:int) -> int:
	match card.type:
		Card.Type.BASIC:
			return _scaled_price(BASIC_PRICE_MIN, BASIC_PRICE_MAX, turn, base_turn)
		Card.Type.SPECIAL, Card.Type.SINGLE_USE:
			return _scaled_price(SPECIAL_PRICE_MIN, SPECIAL_PRICE_MAX, turn, base_turn)
		_:
			return _scaled_price(BASIC_PRICE_MIN, BASIC_PRICE_MAX, turn, base_turn)


## Calcula un precio aleatorio dentro del rango, escalado por turno.
static func _scaled_price(base_min:int, base_max:int, turn:int,
		base_turn:int) -> int:
	var base := randi_range(base_min, base_max)
	var turns_past := maxi(turn - base_turn, 0)
	var multiplier := 1.0 + turns_past * PRICE_SCALE_PER_TURN
	return int(base * multiplier)


## Calcula el coste de purga escalado por usos globales.
static func _get_purge_cost(total_purges:int) -> int:
	return PURGE_BASE_COST + total_purges * PURGE_COST_PER_USE


## Selecciona N cartas del pool usando pesos dinámicos, sin repetición.
static func _weighted_pick_cards(pool:Array[UnlockedCardEntry], count:int,
		turn:int) -> Array[Card]:
	var result:Array[Card] = []
	if pool.is_empty():
		return result

	var remaining := pool.duplicate()

	for _i in range(mini(count, remaining.size())):
		var total_weight := 0.0
		for entry in remaining:
			total_weight += entry.get_weight(turn)

		if total_weight <= 0.0:
			break

		var roll := randf() * total_weight
		var cumulative := 0.0
		for j in remaining.size():
			cumulative += remaining[j].get_weight(turn)
			if roll <= cumulative:
				result.append(remaining[j].card)
				remaining.remove_at(j)
				break

	return result
