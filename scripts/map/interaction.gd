extends Node3D
class_name InteractionTracker

@export var tile_cursor_scene : PackedScene
@export var main_camera : Camera3D
var selected_tile : Node3D
# Cursors
var tile_cursor : Node3D
var initial_scale
const MONGOL = preload("uid://b4mhfidkmt6ag")



func _ready() -> void:
	if not tile_cursor or tile_cursor == null:
		tile_cursor = tile_cursor_scene.instantiate()
		initial_scale = tile_cursor.scale
		add_child(tile_cursor)
	deselect()


func _input(event: InputEvent) -> void:
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
		if Input.is_action_just_pressed("RightClick") and event.pressed:
			Events.change_tile_controller.emit(hit_object,MONGOL)



func raycast_at_mouse(origin, end) -> Node3D:
		var query = PhysicsRayQueryParameters3D.create(origin, end)
		var collision = get_world_3d().direct_space_state.intersect_ray(query)
		if collision and collision.has("collider"):
			var hit = collision.collider.get_parent()
			return hit
		else:
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

func highlight_tile(tile):
	selected_tile = tile
	move_cursor(tile_cursor, tile.global_position)
	tile_cursor.visible = true
	animate_cursor(tile_cursor)
	print(tile.biome)


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
