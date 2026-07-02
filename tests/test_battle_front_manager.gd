extends GutTest

## Tests para BattleFrontManager: apertura, límites, asignación.

var manager: BattleFrontManager
var stats: Stats
var atk_empire: Empire
var def_empire: Empire
var atk_tile: Tile
var def_tile: Tile
var isolated_tile: Tile


func _create_tile(biome: Tile.biome_type, empire: Empire) -> Tile:
	var tile := Tile.new()
	tile.mesh_data = TileMeshData.new()
	tile.mesh_data.type = biome
	tile.natural_resource = NaturalResource.new()
	tile.buildings = []
	tile.controller = empire
	return tile


func _create_troop(atk: int = 3, def: int = 3) -> Troop:
	var troop := Troop.new()
	troop.name = "Test"
	troop.attack = atk
	troop.defense = def
	troop.recruitment_cost_gold = 10
	troop.maintenance_gold = 2
	troop.maintenance_food = 1
	return troop


func before_each() -> void:
	# Limpiar el registro global de frentes para evitar interferencias entre tests
	BattleFront.clear_active_instances()

	atk_empire = Empire.new()
	atk_empire.name = "Atacante"
	def_empire = Empire.new()
	def_empire.name = "Defensor"

	atk_tile = _create_tile(Tile.biome_type.Grassland, atk_empire)
	def_tile = _create_tile(Tile.biome_type.Grassland, def_empire)
	atk_tile.neighbors = [def_tile]
	def_tile.neighbors = [atk_tile]

	isolated_tile = _create_tile(Tile.biome_type.Forest, def_empire)
	isolated_tile.neighbors = []

	atk_empire.controlled_tiles = [atk_tile]

	stats = Stats.new()
	stats.total_gold = 100
	stats.food = 50
	stats.troop_pool = []
	stats.empire = atk_empire

	manager = BattleFrontManager.new()
	manager.stats = stats
	manager.base_max_fronts = 1
	manager.tiles_per_extra_front = 5
	add_child(manager)


func after_each() -> void:
	BattleFront.clear_active_instances()
	if is_instance_valid(manager):
		manager.queue_free()
	for tile in [atk_tile, def_tile, isolated_tile]:
		if is_instance_valid(tile):
			tile.free()


# --- Tests de apertura de frentes ---

func test_open_front_success() -> void:
	var front := manager.open_front(atk_tile, def_tile)
	assert_not_null(front, "Debe poder abrir frente entre tiles adyacentes")
	assert_eq(manager.active_fronts.size(), 1)
	assert_eq(front.attacker_tile, atk_tile)
	assert_eq(front.defender_tile, def_tile)


func test_open_front_not_adjacent() -> void:
	var front := manager.open_front(atk_tile, isolated_tile)
	assert_null(front, "No debe abrir frente entre tiles no adyacentes")
	assert_eq(manager.active_fronts.size(), 0)


func test_open_front_duplicate_rejected() -> void:
	manager.open_front(atk_tile, def_tile)
	var duplicate := manager.open_front(atk_tile, def_tile)
	assert_null(duplicate, "No debe abrir frente duplicado entre mismas tiles")
	assert_eq(manager.active_fronts.size(), 1)


# --- Tests de exclusividad de tiles entre frentes ---

func test_cannot_open_front_with_attacker_tile_already_in_other_front() -> void:
	# El atacante ya tiene atk_tile metida en un frente
	manager.base_max_fronts = 5  # Asegurar que no es el límite quien rechaza
	manager.open_front(atk_tile, def_tile)

	# Otra tile defensora adyacente a atk_tile
	var other_def_tile := _create_tile(Tile.biome_type.Grassland, def_empire)
	atk_tile.neighbors.append(other_def_tile)
	other_def_tile.neighbors = [atk_tile]
	autofree(other_def_tile)

	var second := manager.open_front(atk_tile, other_def_tile)
	assert_null(second, "No debe permitir reusar atk_tile en otro frente")
	assert_eq(manager.active_fronts.size(), 1)


func test_cannot_open_front_with_defender_tile_already_in_other_front() -> void:
	# Imperio externo abre un frente sobre def_tile (frente fuera del manager local)
	var other_atk_empire := Empire.new()
	other_atk_empire.name = "Otro atacante"
	var other_atk_tile := _create_tile(Tile.biome_type.Grassland, other_atk_empire)
	other_atk_tile.neighbors = [def_tile]
	def_tile.neighbors.append(other_atk_tile)
	other_atk_empire.controlled_tiles = [other_atk_tile]
	autofree(other_atk_tile)

	var other_stats := Stats.new()
	other_stats.empire = other_atk_empire
	other_stats.troop_pool = []

	var other_manager := BattleFrontManager.new()
	other_manager.stats = other_stats
	other_manager.base_max_fronts = 1
	add_child(other_manager)
	# Frente externo: atk_tile_externo vs def_tile
	other_manager.open_front(other_atk_tile, def_tile)

	# Nuestro manager intenta abrir un frente que reusa def_tile
	var result := manager.open_front(atk_tile, def_tile)
	assert_null(result, "No debe permitir abrir un frente sobre una tile que otro imperio ya está atacando")
	assert_eq(manager.active_fronts.size(), 0)

	other_manager.queue_free()


# --- Tests de límite de frentes ---

func test_max_fronts_base() -> void:
	assert_eq(manager.get_max_fronts(), 1, "Con 1 tile y base_max=1: max=1")


func test_max_fronts_scales_with_tiles() -> void:
	# Añadimos tiles para que sumen 6 (1 base + 5 extra = +1)
	for i in range(5):
		var t := _create_tile(Tile.biome_type.Grassland, atk_empire)
		autofree(t)
		atk_empire.controlled_tiles.append(t)
	# 6 tiles / 5 per extra = 1 extra
	assert_eq(manager.get_max_fronts(), 2, "Con 6 tiles: 1 base + 1 extra = 2")


func test_cannot_open_beyond_limit() -> void:
	manager.base_max_fronts = 1
	manager.extra_max_fronts = 0

	manager.open_front(atk_tile, def_tile)
	assert_false(manager.can_open_front(), "Ya no debe poder abrir más frentes")


func test_extra_max_fronts_modifier() -> void:
	manager.extra_max_fronts = 2
	assert_eq(manager.get_max_fronts(), 3, "1 base + 0 tiles + 2 extra = 3")


# --- Tests de asignación de tropas ---

func test_assign_troop_to_front() -> void:
	var front := manager.open_front(atk_tile, def_tile)
	var troop := _create_troop()
	stats.troop_pool.append(troop)

	var success := manager.assign_troop_to_front(front, troop, BattleFront.Side.ATTACKER)
	assert_true(success)
	assert_eq(front.attacker_troops.size(), 1)
	assert_eq(stats.troop_pool.size(), 0, "Tropa debe salir del pool")


func test_assign_troop_not_in_pool() -> void:
	var front := manager.open_front(atk_tile, def_tile)
	var troop := _create_troop()  # No está en el pool

	var success := manager.assign_troop_to_front(front, troop, BattleFront.Side.ATTACKER)
	assert_false(success, "No debe asignar tropa que no está en el pool")


func test_assign_troop_to_resolved_front() -> void:
	var front := manager.open_front(atk_tile, def_tile)
	front.is_resolved = true
	var troop := _create_troop()
	stats.troop_pool.append(troop)

	var success := manager.assign_troop_to_front(front, troop, BattleFront.Side.ATTACKER)
	assert_false(success, "No debe asignar a frente resuelto")


func test_assign_as_defender_to_external_front_works() -> void:
	# Frente abierto por un atacante con OTRO manager. Aqui simulamos al
	# defensor: stats.empire es def_empire, el manager local NO contiene el
	# frente en active_fronts, pero el imperio sigue siendo el defensor
	# legitimo y debe poder reforzar.
	#
	# Reseteamos el manager local para que stats.empire = def_empire, asi
	# probamos exactamente el caso del defensor.
	BattleFront.clear_active_instances()
	var def_stats := Stats.new()
	def_stats.troop_pool = []
	def_stats.empire = def_empire
	var def_manager := BattleFrontManager.new()
	def_manager.stats = def_stats
	add_child_autofree(def_manager)

	# Frente externo: creado por el atacante, no esta en def_manager.active_fronts.
	var external_front := BattleFront.new(atk_tile, def_tile, atk_empire, def_empire)
	# Por contrato, este es el escenario de produccion: solo el atacante lo
	# tiene en su active_fronts (aqui ni siquiera lo añadimos). El defensor
	# lo descubre via BattleFront.get_active_instances().

	var troop := _create_troop()
	def_stats.troop_pool.append(troop)

	var success := def_manager.assign_troop_to_front(external_front, troop, BattleFront.Side.DEFENDER)
	assert_true(success,
		"Defensor legitimo debe poder asignar a frente externo (no en su manager)")
	assert_eq(external_front.defender_troops.size(), 1)
	assert_eq(def_stats.troop_pool.size(), 0, "Tropa debe salir del pool del defensor")
	BattleFront.clear_active_instances()


func test_assign_rejects_wrong_side_for_participant() -> void:
	# El atacante intenta meter tropas en el bando defensor: rechazo. La
	# coherencia empire ↔ side evita que un manager "robe" el otro bando.
	var front := manager.open_front(atk_tile, def_tile)
	var troop := _create_troop()
	stats.troop_pool.append(troop)

	var success := manager.assign_troop_to_front(front, troop, BattleFront.Side.DEFENDER)
	assert_false(success,
		"Atacante no puede asignar tropas como defensor de su propio frente")
	assert_eq(front.defender_troops.size(), 0)
	assert_eq(stats.troop_pool.size(), 1, "Pool debe quedar intacto")


func test_assign_rejects_non_participant() -> void:
	# Imperio totalmente ajeno al frente: rechazo en cualquier side.
	var third_empire := Empire.new()
	third_empire.name = "Third"
	var third_stats := Stats.new()
	third_stats.troop_pool = []
	third_stats.empire = third_empire
	var third_manager := BattleFrontManager.new()
	third_manager.stats = third_stats
	add_child_autofree(third_manager)

	var front := BattleFront.new(atk_tile, def_tile, atk_empire, def_empire)
	var troop := _create_troop()
	third_stats.troop_pool.append(troop)

	assert_false(third_manager.assign_troop_to_front(front, troop, BattleFront.Side.ATTACKER),
		"Un imperio ajeno no debe poder asignar como atacante")
	assert_false(third_manager.assign_troop_to_front(front, troop, BattleFront.Side.DEFENDER),
		"Un imperio ajeno no debe poder asignar como defensor")
	assert_eq(third_stats.troop_pool.size(), 1)
	BattleFront.clear_active_instances()


# --- Tests de búsqueda ---

func test_get_front_for_tile() -> void:
	manager.open_front(atk_tile, def_tile)
	var found := manager.get_front_for_tile(atk_tile)
	assert_not_null(found)
	assert_eq(found.attacker_tile, atk_tile)


func test_get_front_for_tile_not_found() -> void:
	var found := manager.get_front_for_tile(isolated_tile)
	assert_null(found)


# --- Retorno de supervivientes al pool del defensor (bus global) ---
#
# Regresion del bug "tropas defensoras supervivientes desaparecen": el
# callback directo _on_front_resolved solo se conectaba al manager del
# atacante (en `open_front`). Dentro de _return_surviving_troops el
# filtro `defender_empire == stats.empire` siempre era falso (stats =
# atacante), asi que las defensoras supervivientes se evaporaban. El
# fix conecta cada BFM al bus global Events.battle_front_resolved en
# `_ready` y el handler `_on_global_front_resolved` solo procesa el
# caso "soy el defensor" para devolver mis supervivientes.

func test_defender_pool_receives_survivors_via_global_bus() -> void:
	BattleFront.clear_active_instances()
	var def_stats := Stats.new()
	def_stats.troop_pool = []
	def_stats.empire = def_empire
	var def_manager := BattleFrontManager.new()
	def_manager.stats = def_stats
	add_child_autofree(def_manager)

	# Frente con 10 atacantes y 10 defensores. Manipulamos los arrays
	# directamente para aislar el handler bajo prueba.
	#
	# Eleccion numerica: con marker = threshold (dominance = 1.0 exacto)
	# la formula de calculate_casualties da `loser_loss_ratio = 0.8`.
	# Con 10 defensoras → ceilf(10 * 0.8) = 8 bajas → 2 supervivientes.
	# Usar 10 nos da margen frente a posibles ajustes futuros en la
	# formula sin tener que retocar el test.
	var front := BattleFront.new(atk_tile, def_tile, atk_empire, def_empire)
	for i in 10:
		front.attacker_troops.append(_create_troop())
		front.defender_troops.append(_create_troop())

	front.is_resolved = true
	front.marker = front.threshold  # dominance = 1.0 exacto

	# Calcular las bayas (normalamente done en _resolve())
	front._calculated_casualties = front.calculate_casualties()

	# Disparo del bus global, replicando lo que hace el callback directo
	# del atacante al final de su _on_front_resolved.
	Events.battle_front_resolved.emit(front, true)

	assert_gt(def_stats.troop_pool.size(), 0,
		"Tropas defensoras supervivientes deben volver al pool del defensor")
	BattleFront.clear_active_instances()


func test_attacker_does_not_double_receive_on_global_bus() -> void:
	# El atacante recibe el bus global al emitirlo el mismo en su callback
	# directo. El handler global debe early-return para no duplicar el
	# return de tropas (ya hecho por _on_front_resolved directo).
	BattleFront.clear_active_instances()
	var front := BattleFront.new(atk_tile, def_tile, atk_empire, def_empire)
	manager.active_fronts.append(front)
	for i in 5:
		front.attacker_troops.append(_create_troop())
	front.is_resolved = true
	front.marker = front.threshold + 0.001

	var pool_before: int = stats.troop_pool.size()
	Events.battle_front_resolved.emit(front, true)

	assert_eq(stats.troop_pool.size(), pool_before,
		"El handler del bus global no debe añadir tropas al pool del atacante")
	BattleFront.clear_active_instances()


func test_third_party_manager_ignores_global_bus() -> void:
	# Manager de un imperio sin participacion en el frente: el handler
	# global debe ignorar el evento sin tocar su pool.
	BattleFront.clear_active_instances()
	var third := Empire.new()
	third.name = "Tercero"
	var third_stats := Stats.new()
	third_stats.troop_pool = []
	third_stats.empire = third
	var third_manager := BattleFrontManager.new()
	third_manager.stats = third_stats
	add_child_autofree(third_manager)

	var front := BattleFront.new(atk_tile, def_tile, atk_empire, def_empire)
	front.is_resolved = true
	front.marker = front.threshold + 0.001
	Events.battle_front_resolved.emit(front, true)

	assert_eq(third_stats.troop_pool.size(), 0,
		"Manager de un imperio ajeno no debe recibir tropas del frente")
	BattleFront.clear_active_instances()
