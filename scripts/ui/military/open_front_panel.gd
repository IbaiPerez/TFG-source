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


func _ready() -> void:
	pass


func setup(p_card: OpenFrontCard, p_own_tiles: Array[Tile]) -> void:
	card = p_card
	own_tiles = p_own_tiles
	_build_ui()

	# Si solo hay una opción, diferir la selección automática al siguiente frame
	# para que CardConfirmingState.enter() tenga tiempo de conectarse a card_confirmed
	# antes de que la señal se emita. Si se llama síncrono dentro de setup(), la
	# señal dispara ANTES de que se establezca la conexión → la carta queda bloqueada.
	if own_tiles.size() == 1:
		call_deferred("_select_tile", own_tiles[0])
		return

	# Resaltar tiles válidas
	for tile in own_tiles:
		tile.set_highlight(true)

	# Escuchar selección
	_tile_selected_handler = _on_tile_selected
	Events.tile_selected.connect(_tile_selected_handler)


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left -= 8.0
	offset_top += 120.0

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.custom_minimum_size.x = 210
	margin.add_child(vbox)

	var title := Label.new()
	title.text = tr("OPENFRONT_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var separator := HSeparator.new()
	vbox.add_child(separator)

	var instruction := Label.new()
	instruction.text = tr("OPENFRONT_INSTRUCTION")
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(instruction)

	var cancel_hint := Label.new()
	cancel_hint.text = tr("OPENFRONT_CANCEL_HINT")
	cancel_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(cancel_hint)


func _on_tile_selected(tile: Tile) -> void:
	if _resolved:
		return
	if tile in own_tiles:
		_select_tile(tile)


func _select_tile(tile: Tile) -> void:
	_resolved = true
	_cleanup_highlights()
	card.set_source_tile(tile)
	Events.open_front_source_selected.emit(card, tile)
	card_confirmed.emit(tile)


func cancel() -> void:
	if _resolved:
		return
	_resolved = true
	_cleanup_highlights()
	Events.open_front_source_cancelled.emit(card)
	card_confirmed.emit(null)


func _cleanup_highlights() -> void:
	for tile in own_tiles:
		if is_instance_valid(tile):
			tile.set_highlight(false)
	if Events.tile_selected.is_connected(_tile_selected_handler):
		Events.tile_selected.disconnect(_tile_selected_handler)


func _exit_tree() -> void:
	_cleanup_highlights()
