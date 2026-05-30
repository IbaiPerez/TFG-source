extends Node3D
class_name InteractionTracker

@export var tile_cursor_scene : PackedScene
@export var main_camera : Camera3D
var selected_tile : Node3D
# Cursors
var tile_cursor : Node3D
var initial_scale



func _ready() -> void:
	if not tile_cursor or tile_cursor == null:
		tile_cursor = tile_cursor_scene.instantiate()
		initial_scale = tile_cursor.scale
		add_child(tile_cursor)
	deselect()


## Usamos `_unhandled_input` (no `_input`) para que los clicks que la UI
## ya ha consumido (p. ej. el botón de demoler en TilePanel, las cartas
## en la mano, popups, etc.) no se reinterpreten aquí como clicks en el
## mundo. De lo contrario el raycast atravesaba la UI, golpeaba la tile
## detrás del panel y disparaba `tile_selected`, reconstruyendo el
## TilePanel y matando el botón que se acababa de pulsar.
##
## Además, bloqueamos clics cuando hay menús abiertos (mediante UIState)
## para evitar seleccionar tiles mientras se confirma una carta o evento.
func _unhandled_input(event: InputEvent) -> void:
	if UIState and UIState.is_any_menu_open():
		return
	if event is InputEventMouseButton:
		var mouse_pos = get_viewport().get_mouse_position()
		var origin = main_camera.project_ray_origin(mouse_pos)
		var dir = main_camera.project_ray_normal(mouse_pos)
		var end = origin + dir * 1000
		var hit_object = raycast_at_mouse(origin, end)
		if not hit_object:
			return
		if Input.is_action_just_pressed("Click") and event.pressed:
			attempt_select(hit_object)



func raycast_at_mouse(origin, end) -> Node3D:
		var space := get_world_3d().direct_space_state

		# 1er raycast: solo cuerpos físicos (tiles). Comportamiento original sin cambios.
		var body_query := PhysicsRayQueryParameters3D.create(origin, end)
		var body_hit := space.intersect_ray(body_query)
		if body_hit and body_hit.has("collider"):
			return body_hit.collider.get_parent().get_parent() as Node3D

		# 2do raycast: solo áreas de layer 3 (BattleFrontVisual, mask = bit 2 = 4).
		# Separado para que las áreas de targeting de cartas (layers 1-2) no interfieran.
		var area_query := PhysicsRayQueryParameters3D.create(origin, end)
		area_query.collision_mask = 4
		area_query.collide_with_areas = true
		area_query.collide_with_bodies = false
		var area_hit := space.intersect_ray(area_query)
		if area_hit and area_hit.has("collider"):
			var parent := area_hit.collider.get_parent() as Node3D
			if parent and parent.is_in_group("battle_front_visuals"):
				return parent

		deselect()
		return null


func deselect():
	hide_cursor(tile_cursor)
	Events.tile_deselected.emit()



func attempt_select(hit):
	deselect()
	if hit.is_in_group("tiles"):
		highlight_tile(hit)
		Events.tile_selected.emit(hit)
	elif hit.is_in_group("battle_front_visuals"):
		var visual := hit as BattleFrontVisual
		if visual and visual.battle_front:
			Events.battle_front_selected.emit(visual.battle_front)

func highlight_tile(tile):
	selected_tile = tile
	move_cursor(tile_cursor, tile.global_position)
	tile_cursor.visible = true
	animate_cursor(tile_cursor)
	GameLogger.debug(str(tile.biome))


## move cursor with optional height difference
func move_cursor(cursor : Node3D, pos : Vector3, height : float = 0):
	cursor.position = pos
	if height != 0:
		tile_cursor.position.y += height


func animate_cursor(cursor : Node3D):
	var tween = get_tree().create_tween()
	var target_scale = initial_scale * 1.15
	tween.set_trans(Tween.TRANS_SPRING)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(cursor, "scale", target_scale, 0.175)
	tween.tween_property(cursor, "scale", initial_scale, 0.2)


func hide_cursor(cursor : Node3D):
	if cursor:
		move_cursor(cursor, Vector3.ZERO, -10)
		cursor.visible = false
