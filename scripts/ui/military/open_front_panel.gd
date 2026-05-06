extends PanelContainer
class_name OpenFrontPanel

## Panel para el segundo paso de la carta de Abrir Frente.
## Muestra highlighting en tiles propias adyacentes y espera a que el jugador
## haga click en una de ellas. Emite card_confirmed con la tile seleccionada
## o null si se cancela.

signal card_confirmed(tile: Tile)

var own_tiles: Array[Tile] = []
var card: OpenFrontCard
var _tile_selected_handler: Callable
var _resolved: bool = false


func setup(p_card: OpenFrontCard, p_own_tiles: Array[Tile]) -> void:
	card = p_card
	own_tiles = p_own_tiles

	# Si solo hay una opción, confirmar automáticamente
	if own_tiles.size() == 1:
		_select_tile(own_tiles[0])
		return

	# Resaltar tiles válidas
	for tile in own_tiles:
		tile.set_highlight(true)

	# Escuchar selección
	_tile_selected_handler = _on_tile_selected
	Events.tile_selected.connect(_tile_selected_handler)


func _on_tile_selected(tile: Tile) -> void:
	if _resolved:
		return
	if tile in own_tiles:
		_select_tile(tile)


func _select_tile(tile: Tile) -> void:
	_resolved = true
	_cleanup_highlights()
	card.set_source_tile(tile)
	card_confirmed.emit(tile)


func cancel() -> void:
	if _resolved:
		return
	_resolved = true
	_cleanup_highlights()
	card_confirmed.emit(null)


func _cleanup_highlights() -> void:
	for tile in own_tiles:
		if is_instance_valid(tile):
			tile.set_highlight(false)
	if Events.tile_selected.is_connected(_tile_selected_handler):
		Events.tile_selected.disconnect(_tile_selected_handler)


func _exit_tree() -> void:
	_cleanup_highlights()
