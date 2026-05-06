extends Node3D
class_name BattleFrontVisual

## Representación visual 3D de un frente de batalla entre dos tiles.
## Se posiciona en el punto medio entre ambas tiles.
## Incluye Area3D en layer 3 ("BattleFront") para targeting de cartas tácticas.

signal front_clicked(front: BattleFront)

## Referencia al frente de datos
var battle_front: BattleFront

## Imperio del jugador local. Permite que el indicador de táctica activa
## sólo refleje el bando del jugador (si el jugador no participa o no se
## ha asignado, el indicador queda oculto).
var player_empire: Empire = null

## Nodos internos
var area_3d: Area3D
var collision_shape: CollisionShape3D
var bar_mesh: MeshInstance3D
var icon_sprite: Sprite3D
var tactic_indicator_sprite: Sprite3D
var highlight_material: StandardMaterial3D

## Materiales para el indicador de barra
var bar_material: StandardMaterial3D
var attacker_color: Color
var defender_color: Color

## Estado visual
var _highlighted: bool = false

## Tamaño de la barra visual
const BAR_LENGTH: float = 0.6
const BAR_WIDTH: float = 0.15
const BAR_HEIGHT: float = 0.08
const ICON_HEIGHT: float = 1.2
## Altura del estandarte indicador de táctica activa (encima del icono).
const TACTIC_INDICATOR_HEIGHT: float = 1.85


func _init(front: BattleFront) -> void:
	battle_front = front


func _ready() -> void:
	add_to_group("battle_front_visuals")
	_setup_position()
	_setup_area_3d()
	_setup_bar_mesh()
	_setup_icon()
	_setup_tactic_indicator()
	_setup_highlight_material()
	_update_visual()
	_update_tactic_indicator()

	# Conectar señales del frente para actualizar visual
	battle_front.marker_changed.connect(_on_marker_changed)
	battle_front.front_resolved.connect(_on_front_resolved)
	battle_front.bonuses_changed.connect(_on_bonuses_changed)


func _setup_position() -> void:
	# Posicionar en el punto medio entre las dos tiles
	var pos_a: Vector3 = battle_front.attacker_tile.global_position
	var pos_b: Vector3 = battle_front.defender_tile.global_position
	global_position = (pos_a + pos_b) / 2.0
	global_position.y += 0.1  # Elevar ligeramente sobre el terreno

	# Rotar para que la barra sea perpendicular a la línea entre tiles
	var direction := (pos_b - pos_a).normalized()
	var angle := atan2(direction.x, direction.z)
	rotation.y = angle + PI / 2.0


func _setup_area_3d() -> void:
	area_3d = Area3D.new()
	# Layer 3 = "BattleFront" = bit 2 = valor 4
	area_3d.collision_layer = 4
	area_3d.collision_mask = 0
	area_3d.monitorable = true
	area_3d.monitoring = false
	area_3d.input_event.connect(_on_area_input_event)
	add_child(area_3d)

	collision_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(BAR_LENGTH + 0.2, 0.4, BAR_WIDTH + 0.2)
	collision_shape.shape = box
	collision_shape.position.y = 0.15
	area_3d.add_child(collision_shape)


func _setup_bar_mesh() -> void:
	bar_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(BAR_LENGTH, BAR_HEIGHT, BAR_WIDTH)
	bar_mesh.mesh = box
	bar_mesh.position.y = BAR_HEIGHT / 2.0
	bar_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bar_mesh)

	bar_material = StandardMaterial3D.new()
	bar_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bar_material.albedo_color = Color(0.7, 0.2, 0.2)
	bar_mesh.material_override = bar_material


func _setup_icon() -> void:
	icon_sprite = Sprite3D.new()
	icon_sprite.pixel_size = 0.005
	icon_sprite.position.y = ICON_HEIGHT
	icon_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon_sprite.modulate = Color(1.0, 0.9, 0.7)
	add_child(icon_sprite)

	# Cargar icono de espadas cruzadas si existe
	var icon_path := "res://assets/military/battle_front_icon.svg"
	if ResourceLoader.exists(icon_path):
		icon_sprite.texture = load(icon_path)
	else:
		# Fallback: no mostrar icono si no existe el asset
		icon_sprite.visible = false


## Sprite billboard que aparece sobre el icono cuando el bando del JUGADOR
## tiene una táctica activa. Sirve como aviso de "ya hay táctica aquí, jugar
## otra carta sustituirá a la actual" (decisión de diseño con Ibai).
## Si el jugador no participa en este frente, el indicador queda siempre oculto.
func _setup_tactic_indicator() -> void:
	tactic_indicator_sprite = Sprite3D.new()
	tactic_indicator_sprite.pixel_size = 0.006
	tactic_indicator_sprite.position.y = TACTIC_INDICATOR_HEIGHT
	tactic_indicator_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tactic_indicator_sprite.modulate = Color(1.0, 1.0, 0.95)
	tactic_indicator_sprite.visible = false
	add_child(tactic_indicator_sprite)

	var icon_path := "res://assets/military/tactic_active_indicator.svg"
	if ResourceLoader.exists(icon_path):
		tactic_indicator_sprite.texture = load(icon_path)


## Asigna el imperio del jugador y refresca el indicador. Lo invoca el
## BattleFrontVisualManager al crear el visual.
func set_player_empire(empire: Empire) -> void:
	player_empire = empire
	_update_tactic_indicator()


## Muestra el estandarte sólo si el bando del JUGADOR tiene una táctica
## activa. Si el jugador no participa o aún no se ha asignado el imperio,
## el indicador permanece oculto.
func _update_tactic_indicator() -> void:
	if tactic_indicator_sprite == null or battle_front == null:
		return
	if player_empire == null:
		tactic_indicator_sprite.visible = false
		return

	var player_side: StringName = _get_player_side()
	if player_side == &"":
		tactic_indicator_sprite.visible = false
		return

	tactic_indicator_sprite.visible = battle_front.has_active_tactic_on_side(player_side)


## Devuelve el bando del jugador en este frente (&"attacker", &"defender")
## o un StringName vacío si no participa.
func _get_player_side() -> StringName:
	if battle_front == null or player_empire == null:
		return &""
	if battle_front.attacker_empire == player_empire:
		return &"attacker"
	if battle_front.defender_empire == player_empire:
		return &"defender"
	return &""


func _setup_highlight_material() -> void:
	highlight_material = StandardMaterial3D.new()
	highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	highlight_material.albedo_color = Color(1.0, 1.0, 0.2, 0.3)
	highlight_material.emission_enabled = true
	highlight_material.emission = Color(1.0, 1.0, 0.0)
	highlight_material.emission_energy_multiplier = 1.5


## Actualiza los colores de la barra según el marcador del frente.
func _update_visual() -> void:
	if battle_front.is_resolved:
		visible = false
		return

	# Colores de los imperios
	attacker_color = battle_front.attacker_empire.color if battle_front.attacker_empire else Color.RED
	defender_color = battle_front.defender_empire.color if battle_front.defender_empire else Color.BLUE

	# Interpolar color según marcador (normalizado al umbral)
	var t: float = 0.5
	if battle_front.threshold > 0.0:
		t = clampf((battle_front.marker / battle_front.threshold + 1.0) / 2.0, 0.0, 1.0)
	# t=1 → atacante domina, t=0 → defensor domina, t=0.5 → equilibrio
	bar_material.albedo_color = defender_color.lerp(attacker_color, t)

	# Hacer la barra más brillante si hay mucha actividad (tropas asignadas)
	var total_troops := battle_front.attacker_troops.size() + battle_front.defender_troops.size()
	if total_troops > 0:
		bar_material.emission_enabled = true
		bar_material.emission = bar_material.albedo_color
		bar_material.emission_energy_multiplier = clampf(0.3 + total_troops * 0.1, 0.3, 1.5)
	else:
		bar_material.emission_enabled = false


## Compatible con el sistema de targeting de cartas (card_target_selector).
func set_highlight(active: bool) -> void:
	_highlighted = active
	if active:
		bar_mesh.material_overlay = highlight_material
	else:
		bar_mesh.material_overlay = null


func _on_marker_changed(_front: BattleFront, _new_value: float) -> void:
	_update_visual()


func _on_bonuses_changed(_side: StringName) -> void:
	_update_tactic_indicator()


func _on_front_resolved(_front: BattleFront, _attacker_won: bool) -> void:
	# Animación de desaparición (simple fade)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _on_area_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			front_clicked.emit(battle_front)


func _exit_tree() -> void:
	if battle_front and battle_front.marker_changed.is_connected(_on_marker_changed):
		battle_front.marker_changed.disconnect(_on_marker_changed)
	if battle_front and battle_front.front_resolved.is_connected(_on_front_resolved):
		battle_front.front_resolved.disconnect(_on_front_resolved)
	if battle_front and battle_front.bonuses_changed.is_connected(_on_bonuses_changed):
		battle_front.bonuses_changed.disconnect(_on_bonuses_changed)
