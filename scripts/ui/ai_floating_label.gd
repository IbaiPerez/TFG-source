extends Node3D
class_name AIFloatingLabel

## Etiqueta 3D efímera que aparece sobre una tile, sube ligeramente y se
## desvanece. Se usa para mostrar al jugador qué carta ha jugado la IA
## (nombre de la carta + color del imperio).
##
## Auto-destrucción tras el tween. El consumidor (AIActionFeedback) lo
## instancia, le pasa setup(...), lo añade al árbol y se olvida.

const RISE_DISTANCE := 1.2      ## Metros que sube el label
const ANIMATION_DURATION := 1.8 ## Segundos totales (subida + fade)
const FONT_SIZE := 32           ## Tamaño del Label3D (resolución de render)
const OUTLINE_SIZE := 4         ## Outline para legibilidad sobre el mapa
## pixel_size convierte píxel de render → metro de mundo. Con tile_size=1
## queremos un texto que no exceda el ancho de la tile (~1m). Una palabra
## de 8 chars × 32px × 0.003 = 0.77m. Ajustable si se ve demasiado pequeño.
const PIXEL_SIZE := 0.003

var _label: Label3D


func _ready() -> void:
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = FONT_SIZE
	_label.outline_size = OUTLINE_SIZE
	_label.outline_modulate = UITheme.TEXT_OUTLINE
	_label.fixed_size = true
	_label.pixel_size = PIXEL_SIZE
	add_child(_label)


## Configura el label con texto, color del imperio y posición mundial.
## Llamar ANTES de add_child o INMEDIATAMENTE después.
func setup(text: String, empire_color: Color, world_position: Vector3) -> void:
	if not is_node_ready():
		await ready
	_label.text = text
	_label.modulate = empire_color
	global_position = world_position
	_animate()


func _animate() -> void:
	# Subida + fade. Usamos parallel para que ocurran simultáneamente.
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y",
		position.y + RISE_DISTANCE, ANIMATION_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_label, "modulate:a",
		0.0, ANIMATION_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
