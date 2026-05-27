extends Node

## Bus de eventos relacionados con cartas (aim, play, return, selection).
##
## Parte de la separacion de `events.gd` (god-object) en buses por dominio.
## Por compatibilidad, `Events` sigue siendo el bus canonico: este bus se
## suscribe a sus señales y las re-emite. El codigo nuevo puede subscribirse
## tanto a `Events.<signal>` como a `CardEvents.<signal>` indistintamente.

# --- Señales ---

signal card_aim_started(card_ui:CardUI)
signal card_aim_ended(card_ui:CardUI)
signal card_played(card:Card, owner_stats:Stats)
signal card_returned_to_hand(card:Card, owner_stats:Stats)

signal build_card_confirm_started(card:BuildCard, targets:Array[Node], stats:Stats)
signal upgrade_building_card_confirm_started(card:UpgradeBuildingCard, targets:Array[Node], stats:Stats)
signal recover_card_confirm_started(card:RecoverCard, stats:Stats)

signal request_card_selection(candidates:Array[Card])
signal card_selection_made(card:Card)
signal card_selection_cancelled()

# --- StringName constants ---

const CARD_AIM_STARTED := &"card_aim_started"
const CARD_AIM_ENDED := &"card_aim_ended"
const CARD_PLAYED := &"card_played"
const CARD_RETURNED_TO_HAND := &"card_returned_to_hand"
const BUILD_CARD_CONFIRM_STARTED := &"build_card_confirm_started"
const UPGRADE_BUILDING_CARD_CONFIRM_STARTED := &"upgrade_building_card_confirm_started"
const RECOVER_CARD_CONFIRM_STARTED := &"recover_card_confirm_started"
const REQUEST_CARD_SELECTION := &"request_card_selection"
const CARD_SELECTION_MADE := &"card_selection_made"
const CARD_SELECTION_CANCELLED := &"card_selection_cancelled"


func _ready() -> void:
	Events.card_aim_started.connect(func(c): card_aim_started.emit(c))
	Events.card_aim_ended.connect(func(c): card_aim_ended.emit(c))
	Events.card_played.connect(func(c, s): card_played.emit(c, s))
	Events.card_returned_to_hand.connect(func(c, s): card_returned_to_hand.emit(c, s))
	Events.build_card_confirm_started.connect(func(c, t, s): build_card_confirm_started.emit(c, t, s))
	Events.upgrade_building_card_confirm_started.connect(func(c, t, s): upgrade_building_card_confirm_started.emit(c, t, s))
	Events.recover_card_confirm_started.connect(func(c, s): recover_card_confirm_started.emit(c, s))
	Events.request_card_selection.connect(func(c): request_card_selection.emit(c))
	Events.card_selection_made.connect(func(c): card_selection_made.emit(c))
	Events.card_selection_cancelled.connect(func(): card_selection_cancelled.emit())
