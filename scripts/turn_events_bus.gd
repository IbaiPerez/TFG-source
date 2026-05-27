extends Node

## Bus de eventos relacionados con el turno y los eventos de turno/tienda.
##
## Llamado `TurnEvents` como autoload. El archivo se llama `turn_events_bus.gd`
## para no colisionar con la carpeta `scripts/turn_events/`.
##
## Parte de la separacion de `events.gd` (god-object) en buses por dominio.
## Por compatibilidad, `Events` sigue siendo el bus canonico: este bus se
## suscribe a sus señales y las re-emite.

# --- Señales ---

signal player_hand_drawn
signal player_hand_discarded
signal player_turn_ended

signal empire_turn_started(controller:EmpireController)
signal empire_turn_ended(controller:EmpireController)

signal ai_card_played(card:Card, anchor_tile:Tile, empire:Empire, payload:Dictionary)
signal ai_turn_started(controller:EmpireController)
signal ai_turn_ended(controller:EmpireController)

signal turn_event_triggered(event:TurnEvent, context:EventContext)
signal turn_event_resolved()

signal shop_event_triggered(shop_config:ShopConfig, context:EventContext)
signal shop_event_resolved()

signal request_tile_selection(eligible_tiles:Array[Tile])
signal tile_selection_made(tile:Tile)
signal tile_selection_cancelled()

# --- StringName constants ---

const PLAYER_HAND_DRAWN := &"player_hand_drawn"
const PLAYER_HAND_DISCARDED := &"player_hand_discarded"
const PLAYER_TURN_ENDED := &"player_turn_ended"
const EMPIRE_TURN_STARTED := &"empire_turn_started"
const EMPIRE_TURN_ENDED := &"empire_turn_ended"
const AI_CARD_PLAYED := &"ai_card_played"
const AI_TURN_STARTED := &"ai_turn_started"
const AI_TURN_ENDED := &"ai_turn_ended"
const TURN_EVENT_TRIGGERED := &"turn_event_triggered"
const TURN_EVENT_RESOLVED := &"turn_event_resolved"
const SHOP_EVENT_TRIGGERED := &"shop_event_triggered"
const SHOP_EVENT_RESOLVED := &"shop_event_resolved"
const REQUEST_TILE_SELECTION := &"request_tile_selection"
const TILE_SELECTION_MADE := &"tile_selection_made"
const TILE_SELECTION_CANCELLED := &"tile_selection_cancelled"


func _ready() -> void:
	Events.player_hand_drawn.connect(func(): player_hand_drawn.emit())
	Events.player_hand_discarded.connect(func(): player_hand_discarded.emit())
	Events.player_turn_ended.connect(func(): player_turn_ended.emit())
	Events.empire_turn_started.connect(func(c): empire_turn_started.emit(c))
	Events.empire_turn_ended.connect(func(c): empire_turn_ended.emit(c))
	Events.ai_card_played.connect(func(c, t, e, p): ai_card_played.emit(c, t, e, p))
	Events.ai_turn_started.connect(func(c): ai_turn_started.emit(c))
	Events.ai_turn_ended.connect(func(c): ai_turn_ended.emit(c))
	Events.turn_event_triggered.connect(func(e, c): turn_event_triggered.emit(e, c))
	Events.turn_event_resolved.connect(func(): turn_event_resolved.emit())
	Events.shop_event_triggered.connect(func(s, c): shop_event_triggered.emit(s, c))
	Events.shop_event_resolved.connect(func(): shop_event_resolved.emit())
	Events.request_tile_selection.connect(func(t): request_tile_selection.emit(t))
	Events.tile_selection_made.connect(func(t): tile_selection_made.emit(t))
	Events.tile_selection_cancelled.connect(func(): tile_selection_cancelled.emit())
