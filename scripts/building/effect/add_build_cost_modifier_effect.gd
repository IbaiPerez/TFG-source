extends BuildingEffect
class_name AddBuildCostModifierEffect

## BuildingEffect que añade un BuildCostModifier permanente al construir.
## Al demoler el edificio, se elimina el modificador.

@export var modifier_id:String
@export var modifier_name:String
@export var percent:float  ## positivo = descuento, negativo = encarecimiento

var _active_modifier:Modifier


func apply_effect(_tile: Tile, stats: Stats) -> void:
	_active_modifier = BuildCostModifier.new(
		modifier_id, modifier_name, percent, -1, null
	)
	Events.request_add_modifier.emit(_active_modifier, stats)


func remove_effect(_tile: Tile, _stats: Stats) -> void:
	if _active_modifier:
		Events.request_remove_modifier.emit(_active_modifier)
		_active_modifier = null
