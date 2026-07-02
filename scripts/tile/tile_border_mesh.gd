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

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)

	var vertices = PackedVector3Array()
	var colors = PackedColorArray()
	var normals = PackedVector3Array()

	var hex_verts = hex_vertices()

	for border_index in border_indices:
		if border_index >= hex_verts.size():
			continue

		var start_vertex = hex_verts[border_index]
		var end_vertex = hex_verts[(border_index + 1) % hex_verts.size()]

		var dir = (end_vertex - start_vertex).normalized()
		var perp = Vector3(-dir.z, 0, dir.x) * _BORDER_WIDTH
		var normal_out = Vector3(-dir.z, 0, dir.x).normalized()
		var normal_in = -normal_out

		vertices.append(start_vertex - perp + Vector3(0, _BASE_ELEVATION, 0))
		vertices.append(start_vertex + perp + Vector3(0, _BASE_ELEVATION, 0))
		vertices.append(end_vertex + perp + Vector3(0, _BASE_ELEVATION, 0))
		vertices.append(end_vertex - perp + Vector3(0, _BASE_ELEVATION, 0))

		vertices.append(start_vertex - perp + Vector3(0, _BASE_ELEVATION + _BORDER_HEIGHT, 0))
		vertices.append(start_vertex + perp + Vector3(0, _BASE_ELEVATION + _BORDER_HEIGHT, 0))
		vertices.append(end_vertex + perp + Vector3(0, _BASE_ELEVATION + _BORDER_HEIGHT, 0))
		vertices.append(end_vertex - perp + Vector3(0, _BASE_ELEVATION + _BORDER_HEIGHT, 0))

		for i in range(8):
			colors.append(color)

		for i in range(2):
			normals.append(normal_out)
		for i in range(2):
			normals.append(normal_in)
		for i in range(2):
			normals.append(normal_out)
		for i in range(2):
			normals.append(normal_in)

	var indices = PackedInt32Array()
	for i in range(border_indices.size()):
		var base = i * 8

		indices.append(base + 0)
		indices.append(base + 4)
		indices.append(base + 5)
		indices.append(base + 0)
		indices.append(base + 5)
		indices.append(base + 1)

		indices.append(base + 3)
		indices.append(base + 2)
		indices.append(base + 6)
		indices.append(base + 3)
		indices.append(base + 6)
		indices.append(base + 7)

		indices.append(base + 0)
		indices.append(base + 3)
		indices.append(base + 7)
		indices.append(base + 0)
		indices.append(base + 7)
		indices.append(base + 4)

		indices.append(base + 1)
		indices.append(base + 5)
		indices.append(base + 6)
		indices.append(base + 1)
		indices.append(base + 6)
		indices.append(base + 2)

		indices.append(base + 4)
		indices.append(base + 7)
		indices.append(base + 6)
		indices.append(base + 4)
		indices.append(base + 6)
		indices.append(base + 5)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var border_material = StandardMaterial3D.new()
	border_material.vertex_color_use_as_albedo = true
	border_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	border_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	border_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	border_material.no_depth_test = false
	border_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS

	array_mesh.surface_set_material(0, border_material)

	return array_mesh
