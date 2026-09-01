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

var province_name: String = ""

var debug_label : Label3D
var material:StandardMaterial3D
var highlight_material: StandardMaterial3D
var natural_resource_image: Sprite3D
var border_mesh:MeshInstance3D

var max_buildings: int = 0 
var food_production: int = 0
var gold_production: int = 0

signal building_completed(building:Building)
signal building_demolished(building:Building)


## Clave de traducción del bioma. Sustituye a `"TILE_" + biome_type.keys()[b].to_upper()`,
## que estaba repetido en varios sitios y ROMPE EN SILENCIO al renombrar un valor del
## enum: la clave deja de existir en el CSV y `tr()` devuelve la propia clave sin avisar.
## El `match` explícito hace que la correspondencia sea revisable, y test_i18n_keys
## comprueba que todas las claves existen en las traducciones.
static func biome_key(biome_value: int) -> String:
	match biome_value:
		biome_type.Grassland: return "TILE_GRASSLAND"
		biome_type.Forest:    return "TILE_FOREST"
		biome_type.Desert:    return "TILE_DESERT"
		biome_type.Swamp:     return "TILE_SWAMP"
		biome_type.Tundra:    return "TILE_TUNDRA"
		biome_type.Ocean:     return "TILE_OCEAN"
		biome_type.Mountain:  return "TILE_MOUNTAIN"
		_: return ""


## Clave de traducción del nivel de desarrollo de la casilla. Ver [method biome_key].
static func location_key(location_value: int) -> String:
	match location_value:
		location_type.Uncolonized: return "LOC_UNCOLONIZED"
		location_type.Village:     return "LOC_VILLAGE"
		location_type.Town:        return "LOC_TOWN"
		location_type.Megalopolis: return "LOC_MEGALOPOLIS"
		_: return ""


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
	var natural_food := natural_resource.food_produced if natural_resource else 0
	food_production = natural_food - (location.food_consumption if location else 0)
	gold_production = natural_resource.gold_produced if natural_resource else 0
	var food_percent_total := 0.0
	for b in buildings:
		gold_production += b.gold_produced
		food_production += b.food_produced
		food_percent_total += b.food_percent_bonus
	var incoming := incoming_neighbor_bonus()
	gold_production += incoming["gold"]
	food_production += incoming["food"]
	food_percent_total += incoming["percent"]
	if food_percent_total != 0.0:
		food_production += int(natural_food * food_percent_total / 100.0)


## Suma de las bonificaciones que ESTA casilla recibe de los edificios de sus
## vecinas (ver [NeighborBonus]). Espejo de `AIRealState.incoming_neighbor_bonus`.
##
## Lee a las vecinas pero NO las recalcula: si lo hiciera, cada recálculo
## dispararía el de al lado y el de al lado el de esta, sin fin. La propagación
## se hace explícita en `recalculate_with_neighbors`, un solo nivel.
func incoming_neighbor_bonus() -> Dictionary:
	var out := {"gold": 0, "food": 0, "percent": 0.0}
	if location == null:
		return out
	var biome: int = mesh_data.type if mesh_data != null else -1
	for n in neighbors:
		var nb := n as Tile
		if nb == null:
			continue
		for b in nb.buildings:
			for bonus in b.neighbor_bonuses:
				if bonus == null or bonus.is_empty():
					continue
				if not bonus.applies_to(controller != null and nb.controller == controller,
						location.type, biome, natural_resource):
					continue
				out["gold"] += bonus.gold
				out["food"] += bonus.food
				out["percent"] += bonus.food_percent
	return out


## Recalcula esta casilla Y sus vecinas.
##
## Un edificio con `neighbor_bonuses` cambia la producción de las casillas de al
## lado, así que construirlo, demolerlo, conquistar la casilla o urbanizarla no
## puede limitarse a recalcular la propia: las vecinas se quedarían con la cifra
## vieja hasta que algo las tocara. No es recursivo — cada `recalculate_modifiers`
## ya lee a sus vecinas, así que un nivel basta.
func recalculate_with_neighbors() -> void:
	recalculate_modifiers()
	for n in neighbors:
		var nb := n as Tile
		if nb != null:
			nb.recalculate_modifiers()

func can_build(building: Building) -> bool:
	if buildings.size() >= max_buildings:
		return false

	if buildings.any(func(b): return b.name == building.name):
		return false

	if building.required_natural_resource != null:
		if natural_resource != building.required_natural_resource:
			return false

	if building.allowed_location_type.size() > 0:
		if location not in building.allowed_location_type:
			return false

	if building.allowed_biomes.size() > 0:
		if mesh_data.type not in building.allowed_biomes:
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
	# Coste efectivo: aplica BuildCostModifier (Banca Florentina, eventos
	# de crisis, etc.) con clamp MIN_COST_MULTIPLIER. Si stats no tiene
	# modifier_manager (tests aislados), el helper devuelve el coste raw.
	stats.total_gold -= building.get_effective_construction_cost(stats)
	recalculate_with_neighbors()
	building_completed.emit(building)

func can_upgrade(old_building: Building, new_building: Building) -> bool:
	if old_building not in buildings:
		return false
	if new_building not in old_building.upgrades_to:
		return false
	if new_building.allowed_biomes.size() > 0:
		if mesh_data.type not in new_building.allowed_biomes:
			return false
	if new_building.required_natural_resource != null:
		if natural_resource != new_building.required_natural_resource:
			return false
	if new_building.allowed_location_type.size() > 0:
		if location not in new_building.allowed_location_type:
			return false
	return true

func get_valid_upgrades(old_building:Building) -> Array[Building]:
	var res:Array[Building] = []
	for building in old_building.upgrades_to:
		if can_upgrade(old_building, building):
			res.append(building)
	return res

func has_upgradable_buildings(stats:Stats) -> bool:
	for building in buildings:
		if building.can_be_upgraded(stats):
			return true
	return false

func get_upgradable_buildings(stats) -> Array[Building]:
	var res := []
	for building in buildings:
		if building.can_be_upgraded(stats):
			res.append(building)
	return res

func upgrade(old_building: Building, new_building: Building, stats: Stats) -> void:
	if not can_upgrade(old_building, new_building):
		return
	var old_index = buildings.find(old_building)
	if old_index == -1:
		return
	buildings.remove_at(old_index)
	for e in old_building.effects:
		e.remove_effect(self, stats)
	var instance := new_building.duplicate(true)
	buildings.insert(old_index, instance)
	for e in instance.effects:
		e.apply_effect(self, stats)
	# Coste efectivo (con descuento de Banca Florentina, eventos, etc.).
	stats.total_gold -= new_building.get_effective_construction_cost(stats)
	recalculate_with_neighbors()
	building_demolished.emit(old_building)
	building_completed.emit(new_building)

func demolish(building:Building, stats:Stats) -> void:
	if building not in buildings:
		return
	
	buildings.erase(building)
	for e in building.effects:
		e.remove_effect(self,stats)
	recalculate_with_neighbors()
	building_demolished.emit(building)

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
		# Conquistar una casilla activa o apaga las bonificaciones de vecindad
		# marcadas `only_same_owner`, en los dos sentidos: las que esta casilla
		# recibe y las que sus edificios reparten.
		recalculate_with_neighbors()

func set_location_type(new_location:LocationType):
	if location != new_location:
		location = new_location
	# Urbanizar cambia si la casilla CUMPLE las condiciones de sus vecinas (el
	# molino alimenta pueblos, no ciudades), así que hay que repasar el vecindario.
	# Durante la generación del mapa las vecinas aún no están enlazadas y esto
	# equivale a `recalculate_modifiers()`.
	recalculate_with_neighbors()

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

	# En mapas escalonados (rectangle/diamond/circle) las columnas impares
	# tienen sus vecinos desplazados un paso respecto a los índices de arista
	# del hexágono: neighbor[i] apunta geométricamente a edge[(i+1)%6].
	var col = int(pos_data.grid_position.x)
	var is_odd_staggered_col = WorldMap.is_map_staggered and (col % 2 + 2) % 2 == 1

	for i in range(neighbors.size()):
		var neighbor = neighbors[i]
		if neighbor == null or neighbor.controller != controller:
			var edge_index = (i + 1) % 6 if is_odd_staggered_col else i
			borders_to_draw.append(edge_index)

	if borders_to_draw.size() > 0:
		var border_color = controller.color if controller else Color.WHITE
		border_mesh.mesh = TileBorderMesh.build(borders_to_draw, border_color)
	else:
		border_mesh.mesh = null

## Vértices del hexágono unidad. Delega en TileBorderMesh (la geometría es
## stateless); se mantiene aquí como accesor público del tile.
func get_hex_vertices() -> Array:
	return TileBorderMesh.hex_vertices()

func set_highlight(active: bool) -> void:
	var mesh_instance: MeshInstance3D = get_child(0) as MeshInstance3D
	if not mesh_instance:
		return
		
	if active:
		mesh_instance.material_overlay = highlight_material
	else:
		mesh_instance.material_overlay = null
