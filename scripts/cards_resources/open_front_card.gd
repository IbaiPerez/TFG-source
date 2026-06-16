extends Card
class_name OpenFrontCard

## Carta para abrir un frente de batalla.
## Flujo de dos pasos:
## 1) Apuntar a una tile enemiga adyacente (sistema de apuntado actual).
## 2) Seleccionar la tile propia desde la que se ataca (highlighting + click).
## Si se cancela en cualquier paso, la carta vuelve a la mano.

## Referencia al BattleFrontManager (se asigna al jugar)
var battle_front_manager: BattleFrontManager

## Tiles seleccionadas durante el flujo
var target_enemy_tile: Tile
var source_own_tile: Tile

## Campo requerido por card_confirming_state
var menu: OpenFrontPanel
var chosen: Tile


func _build_tooltip() -> String:
	return tr("CARD_OPENFRONT_TOOLTIP")


func get_valid_targets(stats: Stats) -> Array[Node]:
	var condition := EnemyAdjacentCondition.new()
	condition.empire = stats.empire
	condition.battle_front_manager = battle_front_manager
	return condition.valid_targets()


func is_valid_target(node: Node, stats: Stats) -> bool:
	var condition := EnemyAdjacentCondition.new()
	condition.empire = stats.empire
	condition.battle_front_manager = battle_front_manager
	return condition.is_valid_target(node)


## Paso 1 completado: se ha seleccionado la tile enemiga.
## Ahora pedimos al jugador que seleccione la tile propia desde la que atacar.
func confirm(targets: Array[Node], stats: Stats) -> void:
	if targets.size() != 1:
		return
	target_enemy_tile = targets[0] as Tile
	if target_enemy_tile == null:
		return

	# Buscar tiles propias adyacentes a la tile enemiga seleccionada
	var own_adjacent: Array[Tile] = []
	for neighbor in target_enemy_tile.neighbors:
		if neighbor != null and neighbor.controller == stats.empire:
			own_adjacent.append(neighbor)

	if own_adjacent.is_empty():
		return

	# Si solo hay una opción, seleccionarla automáticamente
	if own_adjacent.size() == 1:
		source_own_tile = own_adjacent[0]
		Events.open_front_card_confirm_started.emit(self, target_enemy_tile, own_adjacent, stats)
		return

	# Varias opciones: emitir señal para que la UI haga highlighting
	Events.open_front_card_confirm_started.emit(self, target_enemy_tile, own_adjacent, stats)


## Paso 2 completado: el jugador ha seleccionado la tile propia.
func set_source_tile(tile: Tile) -> void:
	source_own_tile = tile
	chosen = tile


func apply_effects(_targets: Array[Node], stats: Stats) -> void:
	if target_enemy_tile == null or source_own_tile == null:
		return
	if battle_front_manager == null:
		return

	battle_front_manager.open_front(source_own_tile, target_enemy_tile)
