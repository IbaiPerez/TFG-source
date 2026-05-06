extends Node
class_name BattleFrontVisualManager

## Gestiona la creación y destrucción de BattleFrontVisual en el mapa 3D.
## Escucha señales globales de Events para reaccionar a la apertura y resolución de frentes.
## Se añade como hijo del nodo que contiene las tiles (tile_parent) o similar.

@export var visual_parent: Node3D

## Mapa de BattleFront → BattleFrontVisual para búsqueda rápida
var _visuals: Dictionary = {}  # { BattleFront: BattleFrontVisual }


func _ready() -> void:
	Events.battle_front_opened.connect(_on_front_opened)
	Events.battle_front_resolved.connect(_on_front_resolved)


func _on_front_opened(front: BattleFront) -> void:
	if _visuals.has(front):
		return  # Ya existe un visual para este frente

	var visual := BattleFrontVisual.new(front)
	visual.front_clicked.connect(_on_front_visual_clicked)
	_visuals[front] = visual

	if visual_parent:
		visual_parent.add_child(visual)
	else:
		add_child(visual)

	# Inyectar el imperio del jugador para que el indicador de táctica activa
	# sólo se ilumine cuando el JUGADOR tiene táctica en ese frente. Mismo
	# patrón que usa scene_manager para localizar al jugador.
	var player_empire: Empire = _resolve_player_empire()
	if player_empire != null:
		visual.set_player_empire(player_empire)


## Devuelve el imperio del jugador local buscándolo vía el grupo
## "player_handler". Si no hay PlayerHandler en escena (p. ej. en tests
## que no levantan el árbol completo) devuelve null y el visual mantiene
## el indicador oculto sin romper.
func _resolve_player_empire() -> Empire:
	var tree := get_tree()
	if tree == null:
		return null
	var ph: Node = tree.get_first_node_in_group("player_handler")
	if ph == null:
		return null
	var stats = ph.get("stats")
	if stats == null:
		return null
	return stats.empire


func _on_front_resolved(front: BattleFront, _attacker_won: bool) -> void:
	if not _visuals.has(front):
		return

	# El visual se auto-destruye con animación en _on_front_resolved
	# Solo limpiamos la referencia después de un delay
	var visual: BattleFrontVisual = _visuals[front]
	_visuals.erase(front)

	# Si el visual aún no se ha liberado (por si la señal llega antes que la del propio front)
	if is_instance_valid(visual) and not visual.is_queued_for_deletion():
		visual.tree_exited.connect(func(): pass, CONNECT_ONE_SHOT)


func _on_front_visual_clicked(front: BattleFront) -> void:
	# Emitir señal global para que la UI reaccione
	Events.battle_front_selected.emit(front)


## Obtiene el visual de un frente específico (para targeting de cartas, etc.)
func get_visual_for_front(front: BattleFront) -> BattleFrontVisual:
	return _visuals.get(front, null)


## Obtiene todos los visuales activos (para get_valid_targets de cartas tácticas).
func get_all_visuals() -> Array[BattleFrontVisual]:
	var result: Array[BattleFrontVisual] = []
	for visual in _visuals.values():
		if is_instance_valid(visual):
			result.append(visual)
	return result
