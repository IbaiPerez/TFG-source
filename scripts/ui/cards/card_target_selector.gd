extends Node2D

const ARC_POINTS := 10

@onready var area_3d: Area3D = $Area3D
@onready var card_arc: Line2D = $CanvasLayer/CardArc

var current_card:CardUI
var targeting := false

var highlighted_targets:Array[Node] = []
@export var main_camera : Camera3D


func _ready() -> void:
	Events.card_aim_started.connect(on_card_aim_started)
	Events.card_aim_ended.connect(on_card_aim_ended)

func _process(_delta: float) -> void:
	if not targeting:
		return
	
	area_3d.position.x = get_local_mouse_position().x
	area_3d.position.y = get_local_mouse_position().y
	
	var mouse_pos = get_viewport().get_mouse_position()
	var origin = main_camera.project_ray_origin(mouse_pos)
	var dir = main_camera.project_ray_normal(mouse_pos)
	
	var ground_plane = Plane(Vector3.UP, 0)
	var intersection = ground_plane.intersects_ray(origin, dir)
	
	if intersection:
		area_3d.global_position = intersection
	
	card_arc.points = _get_points() 

func _get_points() -> Array:
	var points := []
	var start := current_card.global_position
	start.x += (current_card.size.x/2)
	var target := get_local_mouse_position()
	var distance := (target - start)
	
	for i in range(ARC_POINTS):
		var t := (1.0/ARC_POINTS) * i
		var x := start.x + (distance.x/ARC_POINTS) * i
		var y := start.y + ease_out_cubic(t) * distance.y
		points.append(Vector2(x,y))
	points .append(target)
	
	return points

func ease_out_cubic(number:float) -> float:
	return 1.0 - pow(1.0 - number, 3.0)

func on_card_aim_started(card:CardUI) -> void:
	if not card.card.is_tile_targeted():
		return
	
	targeting = true
	area_3d.monitoring = true
	area_3d.monitorable = true
	if card.card.is_batle_front_targeted():
		area_3d.collision_mask = 3
	current_card = card
	highlight_valid_targets(current_card.card.get_valid_targets(current_card.stats))

func on_card_aim_ended(_card:CardUI) -> void:
	targeting = false
	card_arc.clear_points()
	area_3d.position = Vector3.ZERO
	area_3d.monitoring = false
	area_3d.monitorable = false
	area_3d.collision_mask = 1
	current_card = null
	clear_highlights()

func _on_area_3d_area_entered(area: Area3D) -> void:
	if not current_card or not targeting:
		return
	if not current_card.targets.has(area.get_parent()) and current_card.card.is_target_valid(area.get_parent(),current_card.stats):
		current_card.targets.append(area.get_parent())

func _on_area_3d_area_exited(area: Area3D) -> void:
	if not current_card or not targeting:
		return
	current_card.targets.erase(area.get_parent())

func highlight_valid_targets(valid_targets:Array[Node]) -> void:
	clear_highlights()
	
	for target in valid_targets:
		if target.has_method("set_highlight"):
			highlighted_targets.append(target)
			target.set_highlight(true)

func clear_highlights() -> void:
	for target in highlighted_targets:
		if is_instance_valid(target) and target.has_method("set_highlight"):
			target.set_highlight(false)
	highlighted_targets.clear()
