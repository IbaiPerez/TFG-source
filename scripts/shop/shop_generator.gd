extends RefCounted
class_name ShopGenerator

## Genera un ShopConfig dinamicamente escaneando las cartas disponibles
## y seleccionando aleatoriamente segun el tipo de tienda.

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

## Pool de cartas cacheado
static var _basic_cards:Array[Card] = []
static var _special_cards:Array[Card] = []
static var _single_use_cards:Array[Card] = []
static var _pool_loaded := false


static func _ensure_pool_loaded() -> void:
	if _pool_loaded:
		return
	_load_card_pool()
	_pool_loaded = true


static func _load_card_pool() -> void:
	_basic_cards.clear()
	_special_cards.clear()
	_single_use_cards.clear()

	var cards := _scan_cards_recursive("res://resources/cards/")

	for card in cards:
		match card.type:
			Card.Type.BASIC:
				_basic_cards.append(card)
			Card.Type.SPECIAL:
				_special_cards.append(card)
			Card.Type.SINGLE_USE:
				_single_use_cards.append(card)


static func _scan_cards_recursive(path:String) -> Array[Card]:
	var result:Array[Card] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := path + file_name
		if dir.current_is_dir():
			result.append_array(_scan_cards_recursive(full_path + "/"))
		elif file_name.ends_with(".tres"):
			var res := load(full_path)
			if res is Card:
				result.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()

	return result


## Genera una tienda basica:
## 2-3 cartas basicas + 1 uso de purga
static func generate_basic_shop(stats:Stats) -> ShopConfig:
	_ensure_pool_loaded()

	var config := ShopConfig.new()
	var turn := stats.turn_number

	# 2 o 3 cartas basicas
	var num_basic := randi_range(2, 3)
	var picked := _pick_random_cards(_basic_cards, num_basic)
	for card in picked:
		var item := ShopItem.new()
		item.card = card
		item.price = _scaled_price(BASIC_PRICE_MIN, BASIC_PRICE_MAX, turn, 8)
		item.stock = 1
		config.items.append(item)

	# Purga
	config.allow_purge = true
	config.max_purges = 1
	config.purge_cost = _get_purge_cost(stats.total_purges_done)

	return config


## Genera una tienda especial:
## 1 carta basica + 1 especial + 1 especial/single-use + 2-3 usos de purga
static func generate_special_shop(stats:Stats) -> ShopConfig:
	_ensure_pool_loaded()

	var config := ShopConfig.new()
	var turn := stats.turn_number

	# 1 carta basica
	var basic_picks := _pick_random_cards(_basic_cards, 1)
	for card in basic_picks:
		var item := ShopItem.new()
		item.card = card
		item.price = _scaled_price(BASIC_PRICE_MIN, BASIC_PRICE_MAX, turn, 12)
		item.stock = 1
		config.items.append(item)

	# 1 carta especial
	var special_picks := _pick_random_cards(_special_cards, 1)
	for card in special_picks:
		var item := ShopItem.new()
		item.card = card
		item.price = _scaled_price(SPECIAL_PRICE_MIN, SPECIAL_PRICE_MAX, turn, 12)
		item.stock = 1
		config.items.append(item)

	# 1 carta especial o single-use (pool combinado)
	var mixed_pool:Array[Card] = []
	mixed_pool.append_array(_special_cards)
	mixed_pool.append_array(_single_use_cards)
	var mixed_picks := _pick_random_cards(mixed_pool, 1)
	for card in mixed_picks:
		var item := ShopItem.new()
		item.card = card
		item.price = _scaled_price(SPECIAL_PRICE_MIN, SPECIAL_PRICE_MAX, turn, 12)
		item.stock = 1
		config.items.append(item)

	# 2-3 usos de purga
	config.allow_purge = true
	config.max_purges = randi_range(2, 3)
	config.purge_cost = _get_purge_cost(stats.total_purges_done)

	return config


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


## Selecciona N cartas aleatorias sin repeticion del pool dado.
static func _pick_random_cards(pool:Array[Card], count:int) -> Array[Card]:
	var result:Array[Card] = []
	if pool.is_empty():
		return result

	var available := pool.duplicate()
	available.shuffle()

	for i in range(mini(count, available.size())):
		result.append(available[i])

	return result
