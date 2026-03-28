extends Node3D
class_name Tile

enum biome_type {Grassland, Forest, Desert, Swamp, Tundra, Ocean, Mountain}
enum location_type {Uncolonized, Village,Town,Megalopolis}
var biome : String
var mesh_data : TileMeshData
var pos_data : PositionData
var natural_resource:NaturalResource
var controller:Empire
var location:LocationType:set = set_location_type
var buildings:Array[Building] = []

var neighbors = []

var debug_label : Label3D
var material:StandardMaterial3D
var highlight_material: StandardMaterial3D
var natural_resource_image: Sprite3D
var border_mesh:MeshInstance3D

var max_buildings: int = 0 
var food_production: int = 0
var gold_production: int = 0

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
	
	highlight_material = StandardMaterial3D.new()
	highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	highlight_material.albedo_color = Color(1.0, 1.0, 0.2, 0.3) 
	highlight_material.emission_enabled = true
	highlight_material.emission = Color(1.0, 1.0, 0.0) 
	highlight_material.emission_energy_multiplier = 1.5
	recalculate_modifiers()

func recalculate_modifiers() -> void:
	max_buildings = location.max_building if location else 0
	food_production = natural_resource.food_produced if natural_resource else 0
	gold_production = natural_resource.gold_produced if natural_resource else 0
	for b in buildings:
		gold_production += b.gold_produced
		food_production += b.food_produced

func can_build(building: Building) -> bool:
	if buildings.size() >= max_buildings:
		return false

	if building in buildings:
		return false

	if building.required_natural_resource != null:
		if natural_resource != building.required_natural_resource:
			return false

	if building.allowed_location_type.size() > 0:
		if location not in building.allowed_location_type:
			return false

	if building.allowed_biomes.size() > 0:
		if mesh_data.biome_type not in building.allowed_biomes:
			return false

	return true

func get_valid_buildings(options:Array[Building]) -> Array[Building]:
	var res:Array[Building] = []
	
	for building in options:
		if can_build(building):
			res.append(building)
	
	return res

func build(building:Building, stats:Stats) -> void:
	if not can_build(building):
		return
	
	var instance := building.duplicate(true)
	buildings.append(instance)
	for e in instance.effects:
		e.apply_effect(self,stats)
	recalculate_modifiers()
	stats.total_gold -= building.construction_cost

func demolish(building:Building, stats:Stats) -> void:
	if building not in buildings:
		return
	
	buildings.erase(building)
	for e in building.effects:
		e.remove_effect(self,stats)
	recalculate_modifiers()

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
	recalculate_modifiers()

func update_neighbors_borders() -> void:
	for neighbor in neighbors:
		if neighbor != null:
			neighbor.update_borders()

func update_borders() -> void:
	if not border_mesh:
		return
	
	if controller == null:
		border_mesh.mesh = null
		return
	
	var borders_to_draw = []
	
	for i in range(neighbors.size()):
		var neighbor = neighbors[i]
		if neighbor == null or neighbor.controller != controller:
			borders_to_draw.append(i)
	
	if borders_to_draw.size() > 0:
		create_border_mesh(borders_to_draw)
	else:
		border_mesh.mesh = null

func create_border_mesh(border_indices: Array) -> void:
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices = PackedVector3Array()
	var colors = PackedColorArray()
	var normals = PackedVector3Array()
	
	var border_color = controller.color if controller else Color.WHITE
	
	var border_width = 0.05  
	var border_height = 1  
	var base_elevation = 0.0 
	
	var hex_vertices = get_hex_vertices()
	
	for border_index in border_indices:
		if border_index >= hex_vertices.size():
			continue
		
		var start_vertex = hex_vertices[border_index]
		var end_vertex = hex_vertices[(border_index + 1) % hex_vertices.size()]
		
		var dir = (end_vertex - start_vertex).normalized()
		var perp = Vector3(-dir.z, 0, dir.x) * border_width
		var normal_out = Vector3(-dir.z, 0, dir.x).normalized()
		var normal_in = -normal_out
		

		vertices.append(start_vertex - perp + Vector3(0, base_elevation, 0))
		vertices.append(start_vertex + perp + Vector3(0, base_elevation, 0))
		vertices.append(end_vertex + perp + Vector3(0, base_elevation, 0))
		vertices.append(end_vertex - perp + Vector3(0, base_elevation, 0))
		
		vertices.append(start_vertex - perp + Vector3(0, base_elevation + border_height, 0))
		vertices.append(start_vertex + perp + Vector3(0, base_elevation + border_height, 0))
		vertices.append(end_vertex + perp + Vector3(0, base_elevation + border_height, 0))
		vertices.append(end_vertex - perp + Vector3(0, base_elevation + border_height, 0))
		
		for i in range(8):
			colors.append(border_color)
		
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

func set_highlight(active: bool) -> void:
	var mesh_instance: MeshInstance3D = get_child(0) as MeshInstance3D
	if not mesh_instance:
		return
		
	if active:
		mesh_instance.material_overlay = highlight_material
	else:
		mesh_instance.material_overlay = null
