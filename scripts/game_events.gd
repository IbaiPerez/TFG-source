extends Node

## Bus de eventos globales del juego (ciclo de imperio, modifiers, generacion).
##
## Parte de la separacion de `events.gd` (god-object) en buses por dominio.
## Por compatibilidad, `Events` sigue siendo el bus canonico: este bus se
## suscribe a sus señales y las re-emite.

# --- Señales ---

signal generate_world(settings:GenerationSettings, stats:Stats)
signal request_add_modifier(modifier:Modifier, stats:Stats)
signal request_remove_modifier(modifier:Modifier)

# --- StringName constants ---

const GENERATE_WORLD := &"generate_world"
const REQUEST_ADD_MODIFIER := &"request_add_modifier"
const REQUEST_REMOVE_MODIFIER := &"request_remove_modifier"


func _ready() -> void:
	Events.generate_world.connect(func(s, st): generate_world.emit(s, st))
	Events.request_add_modifier.connect(func(m, s): request_add_modifier.emit(m, s))
	Events.request_remove_modifier.connect(func(m): request_remove_modifier.emit(m))
