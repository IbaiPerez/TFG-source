extends Node
class_name BattleFrontManager

## Gestiona todos los frentes de batalla activos de un imperio.
## Se instancia como hijo de cada EmpireController.

var stats: Stats
var active_fronts: Array[BattleFront] = []

## Configuración base (modificable por eventos/edificios)
var base_max_fronts: int = 1
var extra_max_fronts: int = 0
var tiles_per_extra_front: int = 5


func _ready() -> void:
	# Suscripcion al bus global: cuando CUALQUIER frente se resuelve, este
	# manager comprueba si su imperio era el DEFENSOR y, en ese caso,
	# devuelve las tropas defensoras supervivientes a su pool. La
	# conexion directa `front.front_resolved.connect(_on_front_resolved)`
	# que se hace en `open_front` solo cubre al atacante: el defensor
	# nunca abrio el frente, asi que sin esta suscripcion sus tropas
	# supervivientes se evaporaban (el `if defender_empire == stats.empire`
	# dentro de `_return_surviving_troops` jamas se cumplia porque `stats`
	# era el del atacante).
	if not Events.battle_front_resolved.is_connected(_on_global_front_resolved):
		Events.battle_front_resolved.connect(_on_global_front_resolved)


func _exit_tree() -> void:
	if Events.battle_front_resolved.is_connected(_on_global_front_resolved):
		Events.battle_front_resolved.disconnect(_on_global_front_resolved)


## Número máximo de frentes que este imperio puede tener abiertos.
func get_max_fronts() -> int:
	var from_tiles := int(stats.empire.controlled_tiles.size() / tiles_per_extra_front)
	return base_max_fronts + from_tiles + extra_max_fronts


## Verifica si se puede abrir un nuevo frente.
func can_open_front() -> bool:
	return active_fronts.size() < get_max_fronts()


## Abre un nuevo frente entre una tile propia (atacante) y una tile enemiga (defensora).
func open_front(attacker_tile: Tile, defender_tile: Tile) -> BattleFront:
	if not can_open_front():
		return null

	# Verificar adyacencia
	if defender_tile not in attacker_tile.neighbors:
		return null

	# Una tile sólo puede estar en un frente a la vez (regla global, cubre
	# tanto los frentes propios como los de otros imperios). Bloquea
	# implícitamente también el caso "abrir el mismo frente dos veces".
	if BattleFront.is_tile_in_active_front(attacker_tile):
		return null
	if BattleFront.is_tile_in_active_front(defender_tile):
		return null

	var front := BattleFront.new(
		attacker_tile,
		defender_tile,
		attacker_tile.controller,
		defender_tile.controller
	)

	front.front_resolved.connect(_on_front_resolved)
	front.marker_changed.connect(_on_marker_changed)
	active_fronts.append(front)

	Events.battle_front_opened.emit(front)
	return front


## Procesa todos los frentes activos (llamar cada turno).
func tick_all_fronts() -> void:
	# Iteramos una copia porque tick() puede resolver y modificar el array
	var fronts_copy := active_fronts.duplicate()
	for front in fronts_copy:
		if not front.is_resolved:
			front.tick()


## Asigna una tropa del pool a un frente.
##
## Acepta tanto frentes propios (los abiertos por este imperio, presentes
## en `active_fronts`) como ajenos donde este imperio actua de defensor.
## Los frentes se registran solo en el manager del atacante, asi que el
## defensor llega aqui con `front not in active_fronts` aunque legitima-
## mente participe. Para admitir ambos casos validamos por participacion
## y por coherencia `empire ↔ side`.
func assign_troop_to_front(front: BattleFront, troop: Troop, side: BattleFront.Side) -> bool:
	if front.is_resolved:
		return false

	# Coherencia: el imperio del manager debe ser el bando que se le pide
	# rellenar. Esto bloquea, p.ej., a un atacante que intentara meter
	# tropas como `defender` en un frente donde es el agresor.
	var is_valid_participant: bool = (
		(side == BattleFront.Side.ATTACKER and front.attacker_empire == stats.empire)
		or (side == BattleFront.Side.DEFENDER and front.defender_empire == stats.empire)
	)
	if not is_valid_participant:
		return false

	# Verificar que la tropa está en el pool
	var idx := stats.troop_pool.find(troop)
	if idx < 0:
		return false

	# Sacar del pool y asignar al frente
	stats.troop_pool.remove_at(idx)
	front.assign_troop(troop, side)

	Events.troop_assigned_to_front.emit(front, troop, side)
	return true


## Aplica un bonus de carta táctica a un frente.
## Acepta un TacticBonus o un Dictionary (compatibilidad legacy).
func apply_bonus_to_front(front: BattleFront, side: BattleFront.Side, bonus: Variant) -> void:
	if front.is_resolved:
		return
	front.add_bonus(side, bonus)
	Events.battle_front_bonus_applied.emit(front, side)


## Obtiene el coste total de mantenimiento extra por tropas en frentes.
## Retorna { "gold": int, "food": int }.
func get_total_front_maintenance(side: BattleFront.Side) -> Dictionary:
	var total_gold: int = 0
	var total_food: int = 0
	for front in active_fronts:
		var maint := front.get_front_maintenance(side)
		total_gold += maint["gold"]
		total_food += maint["food"]
	return { "gold": total_gold, "food": total_food }


## Busca un frente activo que involucre una tile específica.
func get_front_for_tile(tile: Tile) -> BattleFront:
	for front in active_fronts:
		if front.attacker_tile == tile or front.defender_tile == tile:
			return front
	return null


## Obtiene todos los frentes donde este imperio participa como un bando específico.
func get_fronts_as(side: BattleFront.Side) -> Array[BattleFront]:
	var result: Array[BattleFront] = []
	for front in active_fronts:
		if side == BattleFront.Side.ATTACKER and front.attacker_empire == stats.empire:
			result.append(front)
		elif side == BattleFront.Side.DEFENDER and front.defender_empire == stats.empire:
			result.append(front)
	return result


## --- Callbacks ---

func _on_front_resolved(front: BattleFront, attacker_won: bool) -> void:
	# Usar las bajas calculadas al resolver (snapshot inmutable)
	var casualties := front.get_resolved_casualties()

	# Aplicar conquista
	if attacker_won:
		_apply_conquest(front.defender_tile, front.attacker_empire, front.defender_empire)
	else:
		_apply_conquest(front.attacker_tile, front.defender_empire, front.attacker_empire)

	# Devolver tropas supervivientes al pool de cada bando
	_return_surviving_troops(front, casualties)

	# Limpiar
	active_fronts.erase(front)
	Events.battle_front_resolved.emit(front, attacker_won)


func _on_marker_changed(front: BattleFront, new_value: float) -> void:
	Events.battle_front_marker_changed.emit(front, new_value)


## Handler del bus global de resolucion. Responsable de recuperar las
## tropas supervivientes del DEFENSOR; el atacante ya las recupera por
## su propio callback directo (`_on_front_resolved`).
##
## Filtro en tres pasos:
##   1. Si soy el atacante, early return: el callback directo ya hizo
##      conquista + erase + return de mis supervivientes + emit global.
##   2. Si no soy ni atacante ni defensor, early return: frente ajeno.
##   3. En otro caso soy el defensor: recalculo casualties (determinista
##      sobre el frente ya resuelto) y reuso `_return_surviving_troops`
##      que filtra por `defender_empire == stats.empire` para meter mis
##      defensoras en mi pool.
func _on_global_front_resolved(front: BattleFront, _attacker_won: bool) -> void:
	if stats == null or stats.empire == null:
		return
	if front == null:
		return
	if front.attacker_empire == stats.empire:
		return  # Atacante: ya gestionado por callback directo
	if front.defender_empire != stats.empire:
		return  # Ni atacante ni defensor: frente ajeno

	var casualties := front.get_resolved_casualties()
	_return_surviving_troops(front, casualties)


## Aplica la conquista de una tile: cambio de controlador + destrucción de edificios.
func _apply_conquest(conquered_tile: Tile, winner: Empire, loser: Empire) -> void:
	# Destruir edificios exclusivos del imperio perdedor
	var buildings_to_destroy: Array[Building] = []
	for building in conquered_tile.buildings:
		# TODO: verificar si el edificio es exclusivo del imperio perdedor
		# De momento se marca como placeholder
		pass

	# Destruir 1 edificio adicional (el criterio exacto se definirá luego)
	if conquered_tile.buildings.size() > 0:
		# Por ahora: destruir el último edificio (placeholder)
		buildings_to_destroy.append(conquered_tile.buildings.back())

	for building in buildings_to_destroy:
		conquered_tile.demolish(building, stats)

	# Cambiar controlador
	Events.change_tile_controller.emit(conquered_tile, winner)


## Devuelve tropas supervivientes al pool correspondiente.
func _return_surviving_troops(front: BattleFront, casualties: Dictionary) -> void:
	var atk_losses: int = casualties["attacker_losses"]
	var def_losses: int = casualties["defender_losses"]

	# Eliminar bajas del atacante (desde el final)
	var atk_survivors := front.attacker_troops.duplicate()
	for i in range(mini(atk_losses, atk_survivors.size())):
		atk_survivors.pop_back()

	# Eliminar bajas del defensor
	var def_survivors := front.defender_troops.duplicate()
	for i in range(mini(def_losses, def_survivors.size())):
		def_survivors.pop_back()

	# Devolver supervivientes al pool (nota: las tropas del otro imperio
	# se devuelven a su propio pool a través de su BattleFrontManager)
	for troop in atk_survivors:
		if front.attacker_empire == stats.empire:
			stats.troop_pool.append(troop)
	for troop in def_survivors:
		if front.defender_empire == stats.empire:
			stats.troop_pool.append(troop)


