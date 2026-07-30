extends RefCounted
class_name TileBorderMesh

## Generación procedural de la malla 3D de bordes de un Tile hexagonal.
##
## Stateless: separa las matemáticas de geometría (que antes vivían dentro de
## `Tile`, mezclando dominio y render) del resto de la clase. `Tile.update_borders`
## decide QUÉ aristas dibujar; aquí se construye CÓMO se ven.

const _BORDER_WIDTH := 0.05
const _BORDER_HEIGHT := 1.0
const _BASE_ELEVATION := 0.0
const _HEX_RADIUS := 1.0
const _HEX_START_ANGLE := 60.0


## Vértices del hexágono unidad (6), en el plano XZ. Constante geométrica: no
## depende del estado del tile, por eso es estática.
static func hex_vertices() -> Array:
	var vertices := []
	for i in range(6):
		var angle := deg_to_rad(_HEX_START_ANGLE - 60.0 * i)
		vertices.append(Vector3(
			_HEX_RADIUS * cos(angle),
			0,
			_HEX_RADIUS * sin(angle)
		))
	return vertices


## Construye un ArrayMesh con un prisma de borde por cada arista indicada,
## coloreado con `color`. Devuelve null si no hay aristas que dibujar.
static func build(border_indices: Array, color: Color) -> ArrayMesh:
	if border_indices.is_empty():
		return null

	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	var hex_verts := hex_vertices()
	var drawn := 0
	for border_index in border_indices:
		if border_index >= hex_verts.size():
			continue
		_append_edge_prism(vertices, colors, normals,
			hex_verts[border_index],
			hex_verts[(border_index + 1) % hex_verts.size()],
			color)
		drawn += 1

	# Los índices son los mismos para cada prisma salvo el desplazamiento de base.
	# OJO: se recorre `border_indices.size()`, no `drawn`. Se conserva tal cual para
	# no alterar la malla; con un índice de arista fuera de rango (que `continue`
	# descarta) el bucle generaría índices más allá de los vértices emitidos.
	for i in range(border_indices.size()):
		_append_prism_indices(indices, i * 8)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	array_mesh.surface_set_material(0, _make_border_material())
	return array_mesh


## Emite los 8 vértices (+ color y normal de cada uno) del prisma de UNA arista.
##
## Disposición, que es la que asumen los índices de `_append_prism_indices`:
##   0..3 = anillo INFERIOR  (inicio−perp, inicio+perp, fin+perp, fin−perp)
##   4..7 = anillo SUPERIOR, en el mismo orden
## es decir, los pares verticales son (0,4) (1,5) (2,6) (3,7).
static func _append_edge_prism(vertices: PackedVector3Array, colors: PackedColorArray,
		normals: PackedVector3Array, start_vertex: Vector3, end_vertex: Vector3,
		color: Color) -> void:
	var dir := (end_vertex - start_vertex).normalized()
	var perp := Vector3(-dir.z, 0, dir.x) * _BORDER_WIDTH
	var bottom := Vector3(0, _BASE_ELEVATION, 0)
	var top := Vector3(0, _BASE_ELEVATION + _BORDER_HEIGHT, 0)

	vertices.append(start_vertex - perp + bottom)
	vertices.append(start_vertex + perp + bottom)
	vertices.append(end_vertex + perp + bottom)
	vertices.append(end_vertex - perp + bottom)
	vertices.append(start_vertex - perp + top)
	vertices.append(start_vertex + perp + top)
	vertices.append(end_vertex + perp + top)
	vertices.append(end_vertex - perp + top)

	for i in range(8):
		colors.append(color)

	# Normales alternando por PAREJAS, tal como estaban. No siguen el lado ±perp de
	# cada vértice, así que geométricamente no son las de las caras; da igual porque
	# el material es UNSHADED y no las usa. Se preservan para no tocar la malla.
	var normal_out := Vector3(-dir.z, 0, dir.x).normalized()
	var normal_in := -normal_out
	for i in range(2):
		normals.append(normal_out)
	for i in range(2):
		normals.append(normal_in)
	for i in range(2):
		normals.append(normal_out)
	for i in range(2):
		normals.append(normal_in)


## Las 5 caras visibles del prisma (la inferior no se emite: queda contra el suelo).
## `base` es el índice del primer vértice del prisma.
static func _append_prism_indices(indices: PackedInt32Array, base: int) -> void:
	_append_quad(indices, base + 0, base + 4, base + 5, base + 1)   # tapa de inicio
	_append_quad(indices, base + 3, base + 2, base + 6, base + 7)   # tapa de fin
	_append_quad(indices, base + 0, base + 3, base + 7, base + 4)   # lateral −perp
	_append_quad(indices, base + 1, base + 5, base + 6, base + 2)   # lateral +perp
	_append_quad(indices, base + 4, base + 7, base + 6, base + 5)   # cara superior


## Un quad como dos triángulos, (a,b,c) + (a,c,d). El ORDEN importa: define el
## sentido de giro y, con él, hacia dónde mira la cara.
static func _append_quad(indices: PackedInt32Array, a: int, b: int, c: int, d: int) -> void:
	indices.append(a)
	indices.append(b)
	indices.append(c)
	indices.append(a)
	indices.append(c)
	indices.append(d)


## Material del borde: color plano por vértice, sin iluminación ni descarte de caras,
## para que el borde se vea igual desde cualquier ángulo.
static func _make_border_material() -> StandardMaterial3D:
	var border_material := StandardMaterial3D.new()
	border_material.vertex_color_use_as_albedo = true
	border_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	border_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	border_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	border_material.no_depth_test = false
	border_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	return border_material
