extends TextureButton
class_name TroopPoolOpener

## Botón opener equivalente a CardPileOpener pero para el pool de tropas.
## Mantiene el contador sincronizado con el tamaño de stats.troop_pool.

@export var counter:Label
@export var stats:Stats:set = set_stats


func set_stats(new_value:Stats) -> void:
	stats = new_value
	if stats == null:
		return

	if not stats.troop_pool_changed.is_connected(_on_troop_pool_changed):
		stats.troop_pool_changed.connect(_on_troop_pool_changed)
	_on_troop_pool_changed(stats.troop_pool.size())


func _on_troop_pool_changed(troops_amount:int) -> void:
	if counter:
		counter.text = str(troops_amount)
