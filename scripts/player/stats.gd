extends Resource
class_name Stats

signal stats_changed
signal possible_buildings_changed
signal troop_recruited(troop:Troop)
signal troop_lost(troop:Troop)
signal troop_pool_changed(new_size:int)

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

## Back-reference al ModifierManager que gestiona los modifiers de este
## imperio. La asigna `EmpireController` en `start_game` / `restore_from_save`
## tras crear ambos. Necesaria para que cartas como `RecruitCard` puedan
## leer bonuses (`get_troops_per_recruit_bonus`) sin tener que buscar el
## controller por scene tree.
##
## Puede ser `null` en tests que construyen Stats con `.new()` sin
## controller; en ese caso las cartas deben tratar el bonus como 0.
var modifier_manager:ModifierManager

@export var empire:Empire
@export var event_chance:float = 0.5
@export var available_events:Array[TurnEvent] = []
## Pesos por categoría usados por TurnEventManager para la selección
## ponderada en dos fases (categoría → evento). Si es null, el manager
## cae a un peso uniforme por categoría.
@export var category_weights:EventCategoryWeights
var used_unique_events:Array[String] = []
var turn_number:int = 0
var total_purges_done:int = 0

## Pool de tropas reclutadas
var troop_pool:Array[Troop] = []

## Contador historico de tropas reclutadas por tipo (Troop.TroopType → int).
## A diferencia de `troop_pool`, no decrece cuando una tropa se asigna a un
## frente o muere en combate: una vez reclutada, el tipo queda contabilizado
## para toda la partida.
##
## Lo usa `HasRecruitedTroopOfTypeCondition` para desbloquear las tacticas
## tematicas (Falange, Carga de Caballeria, Lluvia de Flechas, etc.) sin
## quedar a merced de que la tropa siga viva en el pool en el momento exacto
## en que el evento se evalua. Antes la condicion miraba `troop_pool` y, como
## el AIController vacia el pool a los frentes con `_assign_troops_to_fronts`,
## casi ninguna tactica llegaba a desbloquearse aunque el imperio si hubiera
## reclutado el tipo requerido.
var types_ever_recruited:Dictionary = {}

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
	instance.troop_pool = []
	instance.types_ever_recruited = {}
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


## --- Gestión de tropas ---

func recruit_troop(troop:Troop) -> bool:
	var cost_gold := troop.recruitment_cost_gold
	if total_gold < cost_gold:
		return false
	total_gold -= cost_gold
	troop_pool.append(troop)
	# Tracking historico: solo se incrementa al RECLUTAR. Las tropas que
	# regresan al pool tras resolverse un frente NO pasan por aqui (se hace
	# `troop_pool.append(troop)` directamente en BattleFrontManager), asi
	# que el contador no se infla con devoluciones.
	types_ever_recruited[troop.type] = int(types_ever_recruited.get(troop.type, 0)) + 1
	troop_recruited.emit(troop)
	troop_pool_changed.emit(troop_pool.size())
	stats_changed.emit()
	return true


func remove_troop(troop:Troop) -> void:
	var idx := troop_pool.find(troop)
	if idx >= 0:
		troop_pool.remove_at(idx)
		troop_lost.emit(troop)
		troop_pool_changed.emit(troop_pool.size())
		stats_changed.emit()


## Comprueba si se puede reclutar la tropa AHORA. Tres condiciones:
##
##   1. Hay oro suficiente para pagar `recruitment_cost_gold` (coste one-shot).
##   2. La produccion actual de oro (`gold_per_turn`, que ya incluye el
##      mantenimiento de las tropas existentes) puede absorber el
##      mantenimiento de la nueva tropa sin caer en negativo:
##      `gold_per_turn - troop.maintenance_gold >= 0`.
##   3. La produccion actual de comida (`food`) puede absorber el
##      mantenimiento de la nueva tropa sin caer en negativo:
##      `food - troop.maintenance_food >= 0`.
##
## Las condiciones 2 y 3 (Opcion 3b) evitan que el jugador o la IA
## sigan reclutando cuando ya estan en deficit, lo que con la Opcion 3a
## ademas debilita las tropas existentes. Es un freno duro: si no
## puedes mantenerla, no la puedes reclutar.
func can_afford_troop(troop:Troop) -> bool:
	if total_gold < troop.recruitment_cost_gold:
		return false
	if gold_per_turn - troop.maintenance_gold < 0:
		return false
	if food - troop.maintenance_food < 0:
		return false
	return true


func get_troop_maintenance_gold() -> int:
	var total := 0
	for troop in troop_pool:
		total += troop.maintenance_gold
	return total


func get_troop_maintenance_food() -> int:
	var total := 0
	for troop in troop_pool:
		total += troop.maintenance_food
	return total
