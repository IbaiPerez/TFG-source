extends Resource
class_name BuildingEffect

@export_multiline var tooltipe_text:String

func apply_effect(_tile: Tile, _stats: Stats) -> void:
	pass

func remove_effect(_tile: Tile, _stats: Stats) -> void:
	pass


## Indica si este efecto debe re-aplicarse cuando se carga una partida
## desde un save. Default: true (la mayoría de efectos solo conectan
## señales, que NO se persisten en el snapshot).
##
## Las subclases que producen Modifiers a través del ModifierManager
## (vía Events.request_add_modifier) deben sobreescribir esto a `false`,
## porque los modifiers que añadirían ya vienen restaurados desde el
## snapshot — reaplicar duplicaría su efecto.
func should_reapply_on_load() -> bool:
	return true
