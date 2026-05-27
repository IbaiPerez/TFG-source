extends Node

## Bus de eventos relacionados con tiles, posiciones y mapa.
##
## Parte de la separacion de `events.gd` (god-object) en buses por dominio.
## Por compatibilidad, `Events` sigue siendo el bus canonico: este bus se
## suscribe a sus señales y las re-emite. El codigo nuevo puede subscribirse
## tanto a `Events.<signal>` como a `MapEvents.<signal>` indistintamente.
##
## Las constantes `StringName` evitan typos al usar .connect(SIGNAL_NAME, ...).

# --- Señales ---

signal change_tile_controller(tile:Tile, empire:Empire)
signal tile_controller_changed(tile:Tile)
signal change_tile_location_type(tile:Tile, location_type:LocationType)
signal tile_location_type_changed(tile:Tile)

signal tile_selected(tile:Tile)
signal tile_deselected()

signal change_map_mode(map_mode:int)

# --- StringName constants ---

const CHANGE_TILE_CONTROLLER := &"change_tile_controller"
const TILE_CONTROLLER_CHANGED := &"tile_controller_changed"
const CHANGE_TILE_LOCATION_TYPE := &"change_tile_location_type"
const TILE_LOCATION_TYPE_CHANGED := &"tile_location_type_changed"
const TILE_SELECTED := &"tile_selected"
const TILE_DESELECTED := &"tile_deselected"
const CHANGE_MAP_MODE := &"change_map_mode"


func _ready() -> void:
	# Forward de Events → MapEvents. Mantiene a `Events` como bus canonico
	# y permite que listeners suscritos a MapEvents reciban tambien las
	# emisiones del codigo legacy (`Events.tile_selected.emit(...)`).
	Events.change_tile_controller.connect(func(t, e): change_tile_controller.emit(t, e))
	Events.tile_controller_changed.connect(func(t): tile_controller_changed.emit(t))
	Events.change_tile_location_type.connect(func(t, lt): change_tile_location_type.emit(t, lt))
	Events.tile_location_type_changed.connect(func(t): tile_location_type_changed.emit(t))
	Events.tile_selected.connect(func(t): tile_selected.emit(t))
	Events.tile_deselected.connect(func(): tile_deselected.emit())
	Events.change_map_mode.connect(func(m): change_map_mode.emit(m))
