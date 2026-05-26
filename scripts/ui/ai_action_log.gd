extends PanelContainer
class_name AIActionLog

## Mini-log lateral con las últimas N acciones de la IA. Sirve como capa
## de respaldo si el jugador se ha distraído cuando aparecía el floating
## label 3D. Persistente entre turnos de la IA.
##
## Se instancia desde scenes/UI/ai_action_log.tscn. El botón de la cabecera
## anima el colapso/expansión del panel completo mediante un Tween sobre
## offset_bottom. clip_contents=true recorta el contenido durante la animación.

## Número máximo de líneas visibles. Las más viejas se eliminan al exceder.
@export var max_lines: int = 6

## Texto a mostrar cuando un evento (no carta) ocurre. Si está vacío no
## se muestra texto de eventos (sólo cartas).
@export var show_events: bool = false

## Duración de la animación de colapso/expansión en segundos.
@export var anim_duration: float = 0.22

@onready var _box: VBoxContainer = $Layout/Lines
@onready var _toggle_btn: Button = $Layout/Header/ToggleButton

var _expanded: bool = true
var _full_height: float
var _tween: Tween


func _ready() -> void:
	# Registrar la altura expandida desde los offsets que fija general_ui.tscn.
	# Fallback a 300 cuando se instancia fuera de esa escena (p.ej. en tests).
	_full_height = offset_bottom - offset_top if offset_bottom > offset_top else 300.0
	Events.ai_card_played.connect(_on_ai_card_played)
	_toggle_btn.pressed.connect(_on_toggle_pressed)


func _on_toggle_pressed() -> void:
	_expanded = not _expanded
	_toggle_btn.text = "▾" if _expanded else "▸"

	# Altura colapsada: solo la cabecera más el padding interno del panel.
	var header_h: float = $Layout/Header.size.y + 8.0
	var target_bottom := offset_top + (_full_height if _expanded else header_h)

	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_OUT if _expanded else Tween.EASE_IN)
	_tween.tween_property(self, "offset_bottom", target_bottom, anim_duration)

	if _expanded:
		# Las líneas aparecen antes de que empiece la expansión.
		_box.visible = true
	else:
		# Las líneas se ocultan al terminar el colapso, sin dejar rastro.
		_tween.tween_callback(_box.hide)


func _on_ai_card_played(card: Card, anchor_tile: Tile, empire: Empire,
		payload: Dictionary) -> void:
	if card == null or empire == null:
		return
	var line := _format_line(card, anchor_tile, empire, payload)
	_append_line(line, empire.color)


## Formatea una entrada del log. Si la opción lleva payload con
## sub-decisiones (building, troop), las incluye.
func _format_line(card: Card, anchor_tile: Tile, empire: Empire,
		payload: Dictionary) -> String:
	var empire_name := empire.name if empire.name else "?"
	var card_name := _describe_card(card, payload)

	var location := ""
	if anchor_tile != null and anchor_tile.pos_data != null:
		var g: Vector2i = anchor_tile.pos_data.grid_position
		location = " en (%d, %d)" % [g.x, g.y]

	return "[%s] %s%s" % [empire_name, card_name, location]


func _describe_card(card: Card, payload: Dictionary) -> String:
	# Enriquecer con payload cuando esté disponible.
	if payload.has("building") and payload["building"] != null:
		var b: Building = payload["building"]
		return "construye %s" % (b.name if b.name else "edificio")
	if payload.has("new_building") and payload["new_building"] != null:
		var nb: Building = payload["new_building"]
		return "mejora a %s" % (nb.name if nb.name else "edificio")
	if payload.has("troop") and payload["troop"] != null:
		var t: Troop = payload["troop"]
		return "recluta %s" % (t.name if t.name else "tropa")
	if payload.has("chosen_card") and payload["chosen_card"] != null:
		var c: Card = payload["chosen_card"]
		return "recupera %s" % (c.id.capitalize() if c.id else "carta")
	# Fallback: el id de la carta.
	return "juega %s" % (card.id.capitalize() if card.id else "carta")


func _append_line(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.05))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(label)

	# Limitar entradas: eliminar las más viejas (al principio del VBox).
	while _box.get_child_count() > max_lines:
		var oldest := _box.get_child(0)
		_box.remove_child(oldest)
		oldest.queue_free()


## Limpia el log. Útil entre partidas o al cargar saves.
func clear_log() -> void:
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
