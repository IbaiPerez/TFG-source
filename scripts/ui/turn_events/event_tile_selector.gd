extends Node
class_name EventTileSelector

## Gestiona la selección de tiles durante eventos que lo requieran.
## Escucha request_tile_selection, resalta tiles elegibles, y captura
## la selección del jugador a través de Events.tile_selected.

var _eligible_tiles: Array[Tile] = []
var _active := false


func _ready() -> void:
	Events.request_tile_selection.connect(_on_request_tile_selection)


func _on_request_tile_selection(eligible: Array[Tile]) -> void:
	_eligible_tiles = eligible
	_active = true

	# Resaltar tiles elegibles
	for tile in _eligible_tiles:
		if tile.has_method("set_highlight"):
			tile.set_highlight(true)

	# Escuchar click en tiles
	Events.tile_selected.connect(_on_tile_selected)


func _on_tile_selected(tile: Tile) -> void:
	if not _active:
		return

	if tile in _eligible_tiles:
		_cleanup()
		Events.tile_selection_made.emit(tile)
	# Si la tile no es elegible, ignorar el click (mantener selección activa)


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return

	# Cancelar con Escape
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cleanup()
		Events.tile_selection_cancelled.emit()


func _cleanup() -> void:
	_active = false

	# Quitar resaltado
	for tile in _eligible_tiles:
		if is_instance_valid(tile) and tile.has_method("set_highlight"):
			tile.set_highlight(false)
	_eligible_tiles.clear()

	# Desconectar
	if Events.tile_selected.is_connected(_on_tile_selected):
		Events.tile_selected.disconnect(_on_tile_selected)
