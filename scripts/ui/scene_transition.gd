extends CanvasLayer

## Singleton de transiciones de escena. Renderiza un overlay negro
## (layer=100) sobre todo lo demás y expone fade_out/fade_in async.
## Uso en scene_manager: await SceneTransition.fade_out() ... await SceneTransition.fade_in()

const DURATION := 0.2

var _overlay: ColorRect
var _tween: Tween


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_overlay = ColorRect.new()
	_overlay.color = Color.BLACK
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.modulate.a = 0.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)


## Oscurece la pantalla (alpha 0→1). Awaitable.
func fade_out() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_overlay, "modulate:a", 1.0, DURATION)
	await _tween.finished


## Revela la pantalla (alpha 1→0). Awaitable.
func fade_in() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_overlay, "modulate:a", 0.0, DURATION)
	await _tween.finished
