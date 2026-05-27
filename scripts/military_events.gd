extends Node

## Bus de eventos militares (frentes de batalla, tropas, cartas militares).
##
## Parte de la separacion de `events.gd` (god-object) en buses por dominio.
## Por compatibilidad, `Events` sigue siendo el bus canonico: este bus se
## suscribe a sus señales y las re-emite.

# --- Señales ---

signal recruit_card_confirm_started(card:RecruitCard, stats:Stats)
signal open_front_card_confirm_started(card:OpenFrontCard, target_tile:Tile, own_tiles:Array[Tile], stats:Stats)
signal open_front_source_selected(card:OpenFrontCard, source_tile:Tile)
signal open_front_source_cancelled(card:OpenFrontCard)

signal battle_front_opened(front:BattleFront)
signal battle_front_resolved(front:BattleFront, attacker_won:bool)
signal battle_front_marker_changed(front:BattleFront, new_value:float)
signal troop_assigned_to_front(front:BattleFront, troop:Troop, side:StringName)
signal battle_front_bonus_applied(front:BattleFront, side:StringName)
signal battle_front_selected(front:BattleFront)

# --- StringName constants ---

const RECRUIT_CARD_CONFIRM_STARTED := &"recruit_card_confirm_started"
const OPEN_FRONT_CARD_CONFIRM_STARTED := &"open_front_card_confirm_started"
const OPEN_FRONT_SOURCE_SELECTED := &"open_front_source_selected"
const OPEN_FRONT_SOURCE_CANCELLED := &"open_front_source_cancelled"
const BATTLE_FRONT_OPENED := &"battle_front_opened"
const BATTLE_FRONT_RESOLVED := &"battle_front_resolved"
const BATTLE_FRONT_MARKER_CHANGED := &"battle_front_marker_changed"
const TROOP_ASSIGNED_TO_FRONT := &"troop_assigned_to_front"
const BATTLE_FRONT_BONUS_APPLIED := &"battle_front_bonus_applied"
const BATTLE_FRONT_SELECTED := &"battle_front_selected"


func _ready() -> void:
	Events.recruit_card_confirm_started.connect(func(c, s): recruit_card_confirm_started.emit(c, s))
	Events.open_front_card_confirm_started.connect(func(c, t, o, s): open_front_card_confirm_started.emit(c, t, o, s))
	Events.open_front_source_selected.connect(func(c, t): open_front_source_selected.emit(c, t))
	Events.open_front_source_cancelled.connect(func(c): open_front_source_cancelled.emit(c))
	Events.battle_front_opened.connect(func(f): battle_front_opened.emit(f))
	Events.battle_front_resolved.connect(func(f, w): battle_front_resolved.emit(f, w))
	Events.battle_front_marker_changed.connect(func(f, v): battle_front_marker_changed.emit(f, v))
	Events.troop_assigned_to_front.connect(func(f, t, s): troop_assigned_to_front.emit(f, t, s))
	Events.battle_front_bonus_applied.connect(func(f, s): battle_front_bonus_applied.emit(f, s))
	Events.battle_front_selected.connect(func(f): battle_front_selected.emit(f))
