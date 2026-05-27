extends Node

## Bus de eventos de UI/navegacion (menus, paneles, transiciones de escena).
##
## Parte de la separacion de `events.gd` (god-object) en buses por dominio.
## Por compatibilidad, `Events` sigue siendo el bus canonico: este bus se
## suscribe a sus señales y las re-emite.

# --- Señales ---

signal navigate_to_empire_selection
signal navigate_to_generation(empire:Empire)
signal navigate_to_main_menu

# --- StringName constants ---

const NAVIGATE_TO_EMPIRE_SELECTION := &"navigate_to_empire_selection"
const NAVIGATE_TO_GENERATION := &"navigate_to_generation"
const NAVIGATE_TO_MAIN_MENU := &"navigate_to_main_menu"


func _ready() -> void:
	Events.navigate_to_empire_selection.connect(func(): navigate_to_empire_selection.emit())
	Events.navigate_to_generation.connect(func(e): navigate_to_generation.emit(e))
	Events.navigate_to_main_menu.connect(func(): navigate_to_main_menu.emit())
