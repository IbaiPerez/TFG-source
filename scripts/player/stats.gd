extends Resource
class_name Stats

signal stats_changed
signal possible_buildings_changed

@export var initial_gold:int
@export var initial_gold_per_turn:int
@export var starting_deck:CardPile
@export var cards_per_turn:int:set = set_cards_per_turn
@export var possible_buildings:Array[Building] = []

var total_gold:int:set = set_gold
var gold_per_turn:int:set = set_gold_per_turn
var food:int:set = set_food

var deck:CardPile
var discard_pile:CardPile
var draw_pile:CardPile
var played_pile:CardPile

@export var empire:Empire
@export var event_chance:float = 0.5
@export var available_events:Array[TurnEvent] = []
var used_unique_events:Array[String] = []
var turn_number:int = 0
var total_purges_done:int = 0

## Pool de cartas desbloqueadas (evento genérico + tienda)
var unlocked_card_pool:Array[UnlockedCardEntry] = []
## Cartas exclusivas de tienda (no aparecen en el evento genérico)
var shop_exclusive_pool:Array[UnlockedCardEntry] = []


func set_cards_per_turn(value:int) -> void:
	cards_per_turn = clampi(value,1,20)
	stats_changed.emit()

func set_gold(value:int) -> void:
	total_gold = value
	stats_changed.emit()

func set_gold_per_turn(value:int) -> void:
	gold_per_turn = value
	stats_changed.emit()

func set_food(value:int) -> void:
	food = value
	stats_changed.emit()


func add_possible_building(building:Building) -> void:
	if building in possible_buildings:
		return
	possible_buildings.append(building)
	_sync_build_cards()
	possible_buildings_changed.emit()
	stats_changed.emit()


func remove_possible_building(building:Building) -> void:
	if building not in possible_buildings:
		return
	possible_buildings.erase(building)
	_sync_build_cards()
	possible_buildings_changed.emit()
	stats_changed.emit()


func _sync_build_cards() -> void:
	for pile:CardPile in [deck, draw_pile, discard_pile, played_pile]:
		if pile == null:
			continue
		for card:Card in pile.cards:
			if card is BuildCard and not card is DirectBuildCard:
				card.buildings = possible_buildings.duplicate()


## Sincroniza buildings en una BuildCard suelta (antes de añadirla a una pila).
func sync_card_buildings(card:Card) -> void:
	if card is BuildCard and not card is DirectBuildCard:
		card.buildings = possible_buildings.duplicate()


## Cartas precargadas para los pools iniciales
const _COLONIZE_CARD = preload("res://resources/cards/colonize_card.tres")
const _CARD_DRAW_CARD = preload("res://resources/cards/card_draw_card.tres")
const _RECOVER_CARD = preload("res://resources/cards/recover_card.tres")


func create_instance() -> Resource:
	var instance:Stats = self.duplicate()
	instance.total_gold = initial_gold
	instance.gold_per_turn = initial_gold_per_turn
	instance.food = 0
	instance.deck = instance.starting_deck.duplicate()
	instance.draw_pile = CardPile.new()
	instance.discard_pile = CardPile.new()
	instance.played_pile = CardPile.new()
	instance.empire = empire
	instance.used_unique_events = []
	instance.turn_number = 0
	instance.total_purges_done = 0
	instance.possible_buildings = possible_buildings.duplicate()
	instance._sync_build_cards()
	instance._init_card_pools()
	return instance


func _init_card_pools() -> void:
	# Pool general: empieza con colonizar
	unlocked_card_pool = [
		# BASIC: peso alto al inicio, baja con los turnos
		UnlockedCardEntry.new(_COLONIZE_CARD, 10.0, -0.3, 2.0),
	]

	# Pool exclusivo de tienda
	shop_exclusive_pool = [
		UnlockedCardEntry.new(_CARD_DRAW_CARD, 5.0, 0.1, 3.0),
		UnlockedCardEntry.new(_RECOVER_CARD, 4.0, 0.1, 2.0),
	]


func add_to_card_pool(entry:UnlockedCardEntry) -> void:
	for existing in unlocked_card_pool:
		if existing.card.id == entry.card.id:
			return  # Ya existe, no duplicar
	unlocked_card_pool.append(entry)


func get_full_shop_pool() -> Array[UnlockedCardEntry]:
	var pool:Array[UnlockedCardEntry] = []
	pool.append_array(unlocked_card_pool)
	pool.append_array(shop_exclusive_pool)
	return pool
