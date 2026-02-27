extends Node3D
class_name Tile

enum biome_type {Grassland, Forest, Desert, Swamp, Tundra, Ocean, Mountain}
enum location_type {Uncolonized, Village,Town,Megalopolis}
var biome : String
var mesh_data : TileMeshData
var pos_data : PositionData
var natural_resource:NaturalResource
var controller:Empire
var location:LocationType
var buildings:Array[Building] = []

var neighbors = []

var debug_label : Label3D
var material:StandardMaterial3D
var natural_resource_image: Sprite3D
var border_mesh:MeshInstance3D

func set_parameters() -> void:
	material = StandardMaterial3D.new()
	material.albedo_color = mesh_data.color
	var mesh_instance: MeshInstance3D = get_child(0) as MeshInstance3D
	if mesh_instance:
		mesh_instance.material_override = material

	var image = Sprite3D.new()
	add_child(image)
	image.texture = natural_resource.image
	if natural_resource.image.get_height()<100:
		image.scale = Vector3(2,2,2)
	image.position.y += 1
	image.billboard = true
	natural_resource_image = image
	natural_resource_image.visible = false
	
	border_mesh = MeshInstance3D.new()
	add_child(border_mesh)
	border_mesh.position.y = 0.03
	border_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	

func set_biome_material():
	material.albedo_color = mesh_data.color
	natural_resource_image.visible = false

func set_natural_resource_material():
	material.albedo_color = natural_resource.color
	natural_resource_image.visible = true

func set_empire_material():
	material.albedo_color = controller.color if controller else Color.WHITE
	natural_resource_image.visible = false

func set_location_type_material():
	material.albedo_color = location.color
	natural_resource_image.visible = false

func set_controller(new_controller:Empire):
	if new_controller != controller:
		controller = new_controller
		update_borders()
		update_neighbors_borders()

func set_location_type(new_location:LocationType):
	if location != new_location:
		location = new_location

func update_neighbors_borders() -> void:
	for neighbor in neighbors:
		if neighbor != null:
			neighbor.update_borders()

func update_borders() -> void:
	if not border_mesh:
		return
	
	# Si no hay controlador, no dibujamos fronteras
	if controller == null:
		border_mesh.mesh = null
		return
	
	var borders_to_draw = []
	
	# Revisar cada vecino
	for i in range(neighbors.size()):
		var neighbor = neighbors[i]
		# Si el vecino no existe, tiene diferente controlador, o no tiene controlador
		if neighbor == null or neighbor.controller != controller:
			borders_to_draw.append(i)
	
	# Si hay fronteras que dibujar, crear el mesh
	if borders_to_draw.size() > 0:
		create_border_mesh(borders_to_draw)
	else:
		border_mesh.mesh = null

# Crear el mesh de las fronteras
func create_border_mesh(border_indices: Array) -> void:
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices = PackedVector3Array()
	var colors = PackedColorArray()
	var normals = PackedVector3Array()
	
	# Obtener el color del país
	var border_color = controller.color if controller else Color.WHITE
	
	# Parámetros de la línea de frontera
	var border_width = 0.05  # Ancho de la línea (más delgado)
	var border_height = 1  # Altura del muro de frontera
	var base_elevation = 0.0  # Sin elevación extra en la geometría
	
	# Asumiendo tiles hexagonales, definir los vértices de cada borde
	var hex_vertices = get_hex_vertices()
	
	for border_index in border_indices:
		if border_index >= hex_vertices.size():
			continue
		
		var start_vertex = hex_vertices[border_index]
		var end_vertex = hex_vertices[(border_index + 1) % hex_vertices.size()]
		
		# Crear un quad vertical para cada borde (un "muro")
		var dir = (end_vertex - start_vertex).normalized()
		var perp = Vector3(-dir.z, 0, dir.x) * border_width
		var normal_out = Vector3(-dir.z, 0, dir.x).normalized()
		var normal_in = -normal_out
		
		# 8 vértices del quad vertical (4 abajo + 4 arriba)
		# Base
		vertices.append(start_vertex - perp + Vector3(0, base_elevation, 0))
		vertices.append(start_vertex + perp + Vector3(0, base_elevation, 0))
		vertices.append(end_vertex + perp + Vector3(0, base_elevation, 0))
		vertices.append(end_vertex - perp + Vector3(0, base_elevation, 0))
		
		# Arriba
		vertices.append(start_vertex - perp + Vector3(0, base_elevation + border_height, 0))
		vertices.append(start_vertex + perp + Vector3(0, base_elevation + border_height, 0))
		vertices.append(end_vertex + perp + Vector3(0, base_elevation + border_height, 0))
		vertices.append(end_vertex - perp + Vector3(0, base_elevation + border_height, 0))
		
		# Colores para todos los vértices
		for i in range(8):
			colors.append(border_color)
		
		# Normales para iluminación correcta
		for i in range(2):
			normals.append(normal_out)  # Cara exterior
		for i in range(2):
			normals.append(normal_in)   # Cara interior
		for i in range(2):
			normals.append(normal_out)
		for i in range(2):
			normals.append(normal_in)
	
	# Crear índices para los triángulos
	var indices = PackedInt32Array()
	for i in range(border_indices.size()):
		var base = i * 8
		
		# Cara frontal (exterior)
		indices.append(base + 0)
		indices.append(base + 4)
		indices.append(base + 5)
		indices.append(base + 0)
		indices.append(base + 5)
		indices.append(base + 1)
		
		# Cara trasera (interior)
		indices.append(base + 3)
		indices.append(base + 2)
		indices.append(base + 6)
		indices.append(base + 3)
		indices.append(base + 6)
		indices.append(base + 7)
		
		# Cara izquierda
		indices.append(base + 0)
		indices.append(base + 3)
		indices.append(base + 7)
		indices.append(base + 0)
		indices.append(base + 7)
		indices.append(base + 4)
		
		# Cara derecha
		indices.append(base + 1)
		indices.append(base + 5)
		indices.append(base + 6)
		indices.append(base + 1)
		indices.append(base + 6)
		indices.append(base + 2)
		
		# Cara superior
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
	
	# Crear y aplicar material para las fronteras
	var border_material = StandardMaterial3D.new()
	border_material.vertex_color_use_as_albedo = true
	border_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	border_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	border_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	border_material.no_depth_test = false
	border_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	
	# Aplicar el material a la superficie del mesh
	array_mesh.surface_set_material(0, border_material)
	
	# Asignar el mesh al MeshInstance3D
	border_mesh.mesh = array_mesh

func get_hex_vertices() -> Array:

	var radius = 1
	var vertices = []
	
	var start_angle = 60.0
	
	for i in range(6):
		var angle = deg_to_rad(start_angle - 60.0 * i)
		vertices.append(Vector3(
			radius * cos(angle),
			0,
			radius * sin(angle)
		))
	
	return vertices
