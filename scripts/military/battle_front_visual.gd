extends Node3D
class_name BattleFrontVisual

## Representación visual 3D de un frente de batalla al estilo Hearts of Iron.
## Muestra una fila de dientes/chevrons planos sobre el suelo a lo largo del
## borde compartido entre las dos tiles enfrentadas. Los dientes apuntan
## desde el atacante hacia el defensor, indicando la dirección del ataque.

signal front_clicked(front: BattleFront)

## Referencia al frente de datos
var battle_front: BattleFront

## Imperio del jugador local (para el indicador de táctica activa)
var player_empire: Empire = null

## Nodos internos
var area_3d: Area3D
var collision_shape: CollisionShape3D
var front_line: MeshInstance3D          ## Malla de dientes estilo HoI4
var front_line_material: StandardMaterial3D
var icon_sprite: Sprite3D
var tactic_indicator_sprite: Sprite3D

## Colores de los bandos (calculados en _update_visual)
var attacker_color: Color
var defender_color: Color

## Estado visual
var _highlighted: bool = false

## ── Constantes del frente ──────────────────────────────────────────────────
## Longitud total de la línea de dientes (a lo largo del borde compartido).
## El borde compartido entre dos tiles hex con R=1 mide exactamente 1.0 u.m.
const LINE_SPAN: float = 1.05
## Número de dientes a lo largo del borde.
## Con 4 dientes cada triángulo ocupa 0.26 u.m. de base → bien visible.
const NUM_TEETH: int = 4
## Semiancho de cada diente = LINE_SPAN / (2 × NUM_TEETH).
## Esto hace que los triángulos sean CONTIGUOS (estilo HoI4): el borde derecho
## de uno coincide exactamente con el borde izquierdo del siguiente.
const TOOTH_HALF_W: float = LINE_SPAN / (2.0 * NUM_TEETH)   # ≈ 0.131
## Profundidad de cada diente (hacia el defensor).
## TOOTH_DEPTH ≈ TOOTH_HALF_W × 2 da triángulos aproximadamente equiláteros;
## multiplicar por 2.5 los hace más agudos y direccionalmente claros.
const TOOTH_DEPTH: float = TOOTH_HALF_W * 2.5               # ≈ 0.328
## Margen de elevación sobre la superficie de la tile más alta del par.
## La y real se calcula dinámicamente en _setup_position() usando la AABB
## del MeshInstance3D de cada tile, para que montañas (top≈0.99) u otras
## tiles altas queden siempre cubiertas.
const FRONT_Y_MARGIN: float = 0.06
## Altura del icono billboard (relativa al suelo, no al techo de la tile)
const ICON_HEIGHT: float = 1.4
## Altura del estandarte de táctica activa
const TACTIC_INDICATOR_HEIGHT: float = 1.85
## Longitud usada para la caja de colisión (click detection)
const COLLISION_SPAN: float = 1.3


func _init(front: BattleFront) -> void:
	battle_front = front


func _ready() -> void:
	add_to_group("battle_front_visuals")
	_setup_position()
	_setup_area_3d()
	_setup_front_line()
	_setup_icon()
	_setup_tactic_indicator()
	_update_visual()
	_update_tactic_indicator()

	battle_front.marker_changed.connect(_on_marker_changed)
	battle_front.front_resolved.connect(_on_front_resolved)
	battle_front.bonuses_changed.connect(_on_bonuses_changed)


## Posiciona el visual en el punto medio entre las dos tiles. La rotación no
## afecta a los dientes (que se calculan en espacio local via to_local()),
## pero se mantiene para orientar la caja de colisión.
## La elevación en Y se calcula dinámicamente: se toma el techo de la tile
## más alta del par (montaña ≈ 0.99, tile normal ≈ 0.25) y se le suma
## FRONT_Y_MARGIN, garantizando visibilidad sobre cualquier tipo de tile.
func _setup_position() -> void:
	var pos_a: Vector3 = battle_front.attacker_tile.global_position
	var pos_b: Vector3 = battle_front.defender_tile.global_position
	global_position = (pos_a + pos_b) / 2.0

	var top_a := _get_tile_top_y(battle_front.attacker_tile)
	var top_b := _get_tile_top_y(battle_front.defender_tile)
	global_position.y = maxf(top_a, top_b) + FRONT_Y_MARGIN

	var direction := (pos_b - pos_a).normalized()
	var angle := atan2(direction.x, direction.z)
	rotation.y = angle + PI / 2.0


## Devuelve la coordenada Y de la superficie superior de una tile en
## coordenadas de mundo, usando la AABB del primer MeshInstance3D encontrado.
## Fallback a tile.global_position.y + 0.30 si no hay malla accesible.
func _get_tile_top_y(tile: Tile) -> float:
	# Tile extiende Node3D, no MeshInstance3D, así que no podemos hacer
	# `tile is MeshInstance3D` directamente (error de tipos estáticos).
	# Asignamos a Node3D primero: desde ahí el check `is MeshInstance3D`
	# es válido porque MeshInstance3D SÍ hereda de Node3D.
	var node: Node3D = tile
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		return mi.to_global(Vector3(0.0, mi.get_aabb().end.y, 0.0)).y
	# La raíz del GLB puede ser Node3D con hijos MeshInstance3D
	for child in tile.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			return mi.to_global(Vector3(0.0, mi.get_aabb().end.y, 0.0)).y
	# Fallback genérico
	return tile.global_position.y + 0.30


## Crea el Area3D de layer 4 ("BattleFront") que permite el click y el
## targeting de cartas tácticas.
func _setup_area_3d() -> void:
	area_3d = Area3D.new()
	area_3d.collision_layer = 4   # Bit 2 = layer "BattleFront"
	area_3d.collision_mask = 0
	area_3d.monitorable = true
	area_3d.monitoring = false
	area_3d.input_event.connect(_on_area_input_event)
	add_child(area_3d)

	collision_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	# La caja cubre toda la línea de dientes + margen para que sea fácil clicar
	box.size = Vector3(COLLISION_SPAN, 0.4, COLLISION_SPAN * 0.55)
	collision_shape.position.y = 0.15
	collision_shape.shape = box
	area_3d.add_child(collision_shape)


## Genera proceduralmente la malla de dientes estilo HoI4:
##   - La línea de dientes se extiende a lo largo del BORDE COMPARTIDO
##     entre las dos tiles (perpendicular al eje atacante→defensor).
##   - Cada diente es un triángulo plano cuya punta apunta hacia el defensor.
##
## Utiliza to_local() para convertir las posiciones world a espacio local
## del visual, garantizando que la rotación ya aplicada en _setup_position()
## quede correctamente integrada en los vértices de la malla.
func _setup_front_line() -> void:
	if battle_front == null:
		return

	# Proyectar posiciones de las tiles al plano Y del visual
	var pos_a := battle_front.attacker_tile.global_position
	var pos_b := battle_front.defender_tile.global_position
	pos_a.y = global_position.y
	pos_b.y = global_position.y

	# Convertir a espacio local (cancela traslación + rotación del visual)
	var la := to_local(pos_a)
	var lb := to_local(pos_b)
	la.y = 0.0
	lb.y = 0.0

	# forward: atacante → defensor en espacio local
	var forward := (lb - la).normalized()
	# along: a lo largo del borde compartido (perpendicular al frente)
	var along  := Vector3(-forward.z, 0.0, forward.x)

	# ── Construir vértices ────────────────────────────────────────────────
	var verts := PackedVector3Array()
	var norms  := PackedVector3Array()
	var inds   := PackedInt32Array()

	for i in range(NUM_TEETH):
		# Posición central del diente a lo largo del borde (centrada en 0)
		var t       := (float(i) + 0.5) / float(NUM_TEETH)  # 0..1
		var p_along := along * ((t - 0.5) * LINE_SPAN)
		p_along.y = 0.0

		# Los tres vértices del triángulo (plano, y = 0 en espacio local)
		var v_left  := p_along - along * TOOTH_HALF_W
		var v_right := p_along + along * TOOTH_HALF_W
		var v_tip   := p_along + forward * TOOTH_DEPTH
		v_left.y  = 0.0
		v_right.y = 0.0
		v_tip.y   = 0.0

		var base := verts.size()
		verts.append(v_left)
		verts.append(v_right)
		verts.append(v_tip)
		norms.append_array([Vector3.UP, Vector3.UP, Vector3.UP])

		# Winding CCW visto desde arriba → normal +Y
		# CULL_DISABLED hace el material visible por las dos caras igualmente
		inds.append(base + 0)
		inds.append(base + 2)
		inds.append(base + 1)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX]  = inds

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	front_line = MeshInstance3D.new()
	front_line.mesh = mesh
	front_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(front_line)

	front_line_material = StandardMaterial3D.new()
	front_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	front_line_material.cull_mode    = BaseMaterial3D.CULL_DISABLED
	front_line.material_override = front_line_material


func _setup_icon() -> void:
	icon_sprite = Sprite3D.new()
	icon_sprite.pixel_size = 0.012
	icon_sprite.position.y = ICON_HEIGHT
	icon_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon_sprite.modulate = Color(1.0, 0.9, 0.7)
	add_child(icon_sprite)

	var icon_path := "res://assets/military/battle_front_icon.svg"
	if ResourceLoader.exists(icon_path):
		icon_sprite.texture = load(icon_path)
	else:
		icon_sprite.visible = false


## Sprite billboard que aparece sobre el icono cuando el bando del JUGADOR
## tiene una táctica activa en este frente.
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


## Asigna el imperio del jugador y refresca el indicador de táctica.
func set_player_empire(empire: Empire) -> void:
	player_empire = empire
	_update_tactic_indicator()


## Actualiza los dientes y el icono según el estado actual del frente.
func _update_visual() -> void:
	if battle_front.is_resolved:
		visible = false
		return

	attacker_color = battle_front.attacker_empire.color if battle_front.attacker_empire else Color.RED
	defender_color = battle_front.defender_empire.color if battle_front.defender_empire else Color.BLUE

	if front_line_material == null:
		return

	# Interpolar color: t=1 → atacante domina, t=0 → defensor domina
	var t: float = 0.5
	var effective_threshold := battle_front.get_current_threshold()
	if effective_threshold > 0.0:
		t = clampf((battle_front.marker / effective_threshold + 1.0) / 2.0, 0.0, 1.0)
	front_line_material.albedo_color = defender_color.lerp(attacker_color, t)

	# Añadir emisión si hay tropas comprometidas (frente activo)
	var total_troops := battle_front.attacker_troops.size() + battle_front.defender_troops.size()
	if total_troops > 0:
		front_line_material.emission_enabled = true
		front_line_material.emission = front_line_material.albedo_color
		front_line_material.emission_energy_multiplier = clampf(0.4 + total_troops * 0.15, 0.4, 1.8)
	else:
		front_line_material.emission_enabled = false


## Muestra el estandarte sólo si el bando del JUGADOR tiene una táctica activa.
func _update_tactic_indicator() -> void:
	if tactic_indicator_sprite == null or battle_front == null:
		return
	if player_empire == null:
		tactic_indicator_sprite.visible = false
		return

	var player_side: BattleFront.Side = _get_player_side()
	if player_side == BattleFront.Side.NONE:
		tactic_indicator_sprite.visible = false
		return

	tactic_indicator_sprite.visible = battle_front.has_active_tactic_on_side(player_side)


func _get_player_side() -> BattleFront.Side:
	if battle_front == null or player_empire == null:
		return BattleFront.Side.NONE
	if battle_front.attacker_empire == player_empire:
		return BattleFront.Side.ATTACKER
	if battle_front.defender_empire == player_empire:
		return BattleFront.Side.DEFENDER
	return BattleFront.Side.NONE


## Resaltado para el targeting de cartas tácticas.
## Activa/desactiva la emisión amarilla de los dientes.
func set_highlight(active: bool) -> void:
	_highlighted = active
	if front_line_material == null:
		return
	if active:
		front_line_material.emission_enabled = true
		front_line_material.emission = Color(1.0, 1.0, 0.2)
		front_line_material.emission_energy_multiplier = 2.5
	else:
		_update_visual()


## ── Callbacks ──────────────────────────────────────────────────────────────

func _on_marker_changed(_front: BattleFront, _new_value: float) -> void:
	_update_visual()


func _on_bonuses_changed(_side: BattleFront.Side) -> void:
	_update_tactic_indicator()


func _on_front_resolved(_front: BattleFront, _attacker_won: bool) -> void:
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
