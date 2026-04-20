extends BuildingEffect
class_name AddStatModifierEffect

## BuildingEffect que añade un StatModifier permanente al construir.
## Al demoler el edificio, se elimina el modificador.

@export var modifier_id:String
@export var modifier_name:String
@export var stat_type:StatModifier.StatType
@export var value:float

var _active_modifier:Modifier


func apply_effect(_tile: Tile, stats: Stats) -> void:
	_active_modifier = StatModifier.new(
		modifier_id, modifier_name, stat_type, value, -1, null, null
	)
	Events.request_add_modifier.emit(_active_modifier, stats)


func remove_effect(_tile: Tile, _stats: Stats) -> void:
	if _active_modifier:
		Events.request_remove_modifier.emit(_active_modifier)
		_active_modifier = null
