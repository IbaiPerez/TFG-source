extends Camera3D

@export_category("Movement")
@export var movespeed = 8
@export var zoomspeed = 2
@export var zoom = Vector2(25.0, 90.0)
@export var height = Vector2(0, 40)
@export var rot = Vector2(-20, -80)
@export var sun: DirectionalLight3D
var parent


func _ready() -> void:
	parent = get_parent()
	adjust_height()
	adjust_rotation()


func _process(delta: float) -> void:
	move_camera(delta)


func move_camera(delta):
	## Movement
	var move_vector : Vector3 = Vector3.ZERO
	if Input.is_action_pressed("MoveForward"):
		move_vector += -parent.transform.basis.z
	if Input.is_action_pressed("MoveBackwards"):
		move_vector += parent.transform.basis.z
	if Input.is_action_pressed("MoveLeft"):
		move_vector += -parent.transform.basis.x
	if Input.is_action_pressed("MoveRight"):
		move_vector += parent.transform.basis.x
	## Rotation
	if Input.is_action_pressed("RotateCameraLeft"):
		parent.rotate(Vector3.UP, 0.005)
	if Input.is_action_pressed("RotateCameraRight"):
		parent.rotate(Vector3.UP, -0.005)
	## Apply movement & rotation
	if move_vector != Vector3.ZERO:
		move_vector = move_vector.normalized() * movespeed * delta
		parent.position += move_vector


func _input(event: InputEvent) -> void:
	# Check for mouse wheel scrolling
	if event is InputEventMouseButton:
		change_fov(event.button_index)
		adjust_height()
		adjust_rotation()
		adjust_shadows()


func change_fov(index):
	if index == MOUSE_BUTTON_WHEEL_UP:
		fov = max(zoom.x, fov - zoomspeed)  # Zoom in by decreasing FOV
	elif index == MOUSE_BUTTON_WHEEL_DOWN:
		fov = min(zoom.y, fov + zoomspeed)  # Zoom out by increasing FOV
	

func adjust_height():
	var new_height = inverse_lerp(zoom.x, zoom.y, fov)
	position.y = lerpf(height.x, height.y, new_height)


func adjust_rotation():
	var min_r = deg_to_rad(rot.x)
	var max_r = deg_to_rad(rot.y)
	var new_rot = inverse_lerp(zoom.x, zoom.y, fov)
	rotation.x = lerpf(min_r, max_r, new_rot)


## Test to see if we can turn shadows on or off when getting closer to the scene
func adjust_shadows():
	if fov < 40 or position.y < 10:
		sun.shadow_enabled = true
	elif sun.shadow_enabled:
		sun.shadow_enabled = false
