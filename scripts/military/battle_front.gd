extends RefCounted
class_name BattleFront

## Representa un frente de batalla activo entre dos tiles adyacentes.
## El marcador empieza en 0.0 y se mueve hacia +umbral (gana atacante)
## o -umbral (gana defensor).

## Bando de un frente. Sustituye a los antiguos marcadores StringName de texto
## por un enum con seguridad de tipos. El orden de la API se conserva: el
## atacante primero. `NONE` es el centinela para "no participa en este frente"
## (antes se representaba con la cadena vacía).
enum Side { ATTACKER, DEFENDER, NONE }

signal front_resolved(front: BattleFront, attacker_won: bool)
signal marker_changed(front: BattleFront, new_value: float)
## Emitida cuando la lista de bonuses de un bando cambia (añadido o eliminado).
## Permite que la UI y los visuales 3D refresquen sin polling.
signal bonuses_changed(side: BattleFront.Side)

## Tiles enfrentadas
var attacker_tile: Tile
var defender_tile: Tile

## Imperios involucrados
var attacker_empire: Empire
var defender_empire: Empire

## Marcador de tira y afloja (positivo = ventaja atacante)
var marker: float = 0.0

## Control de tiempo
var turns_elapsed: int = 0
var min_duration: int = GameBalance.FRONT_MIN_DURATION

## Umbral inicial del frente. El umbral efectivo se calcula con
## `get_current_threshold()` y va decreciendo desde `threshold` (default 10)
## hasta `MIN_THRESHOLD` (5) de forma lineal en `THRESHOLD_DECAY_TURNS` (10)
## turnos transcurridos en el frente.
##
## Why: frentes con ejercitos simetricos oscilaban cerca de cero y nunca
## se resolvian. Bajando el techo a 10 y el minimo a 5 con decay de 10
## turnos, los frentes estancados se resuelven antes del turno 15 en la
## mayoria de casos, evitando LATE games bloqueados.
var threshold: float = GameBalance.FRONT_INITIAL_THRESHOLD
const MIN_THRESHOLD: float = GameBalance.FRONT_MIN_THRESHOLD
const THRESHOLD_DECAY_TURNS: int = GameBalance.FRONT_THRESHOLD_DECAY_TURNS

## Tropas asignadas por bando (arrays de Troop)
var attacker_troops: Array[Troop] = []
var defender_troops: Array[Troop] = []

## Bonus temporales de cartas tácticas activas.
## En runtime SIEMPRE contienen instancias TacticBonus: `add_bonus` convierte los
## Dictionaries legacy y `BattleFrontSerializer._restore_bonuses` reconstruye
## TacticBonus al cargar. Aun así el Array se declara SIN TIPO a propósito: hay
## código (y tests) que asignan un array de Dictionaries directamente a estos
## campos —p.ej. test_battle_front_serializer, que valida el saneado de la ruta
## legacy—. `_as_tactic_bonus()` garantiza acceso tipado en cada operación, así
## que ambos formatos conviven de forma segura.
var attacker_bonuses: Array = []
var defender_bonuses: Array = []

## Estado
var is_resolved: bool = false

## Bajas calculadas al resolver (snapshot inmutable)
var _calculated_casualties: Dictionary = {}

## Configuración de multiplicadores de bioma (instanciada una sola vez).
var biome_config: BiomeConfig = BiomeConfig.new()


func _init(p_atk_tile: Tile, p_def_tile: Tile, p_atk_empire: Empire, p_def_empire: Empire) -> void:
	attacker_tile = p_atk_tile
	defender_tile = p_def_tile
	attacker_empire = p_atk_empire
	defender_empire = p_def_empire
	BattleFrontRegistry.register(self)


## Comprueba si una tile está participando ahora mismo en algún frente
## activo (atacante o defensora, en cualquier imperio).
static func is_tile_in_active_front(tile: Tile) -> bool:
	return BattleFrontRegistry.is_tile_in_active_front(tile)


## Devuelve una copia de la lista global de frentes activos.
static func get_active_instances() -> Array[BattleFront]:
	return BattleFrontRegistry.get_active_instances()


## Vacía el registro global. Pensado para limpiar entre tests o al cerrar
## la partida; en juego, los frentes se desregistran solos al resolverse.
static func clear_active_instances() -> void:
	BattleFrontRegistry.clear()


## Calcula el ataque total de un bando (tropas + bioma + edificios + bonuses de cartas).
##
## El ataque base de las tropas se pasa por TroopEffectiveness para aplicar
## el multiplicador piedra-papel-tijera contra la composición enemiga, y
## después se escala por el modificador de bioma de la tile **contraria**
## (atacar un bosque/montaña es más difícil que asaltar una pradera). Los
## edificios y los bonuses de cartas tácticas no se ven afectados por el
## bioma base — los bonuses tienen su propio modificador capturado al jugar
## la carta.
func get_total_attack(side: BattleFront.Side) -> float:
	var own_tile: Tile
	var enemy_tile: Tile
	var troops: Array[Troop]
	var enemy_troops: Array[Troop]
	var bonuses: Array

	if side == BattleFront.Side.ATTACKER:
		own_tile = attacker_tile
		enemy_tile = defender_tile
		troops = attacker_troops
		enemy_troops = defender_troops
		bonuses = attacker_bonuses
	else:
		own_tile = defender_tile
		enemy_tile = attacker_tile
		troops = defender_troops
		enemy_troops = attacker_troops
		bonuses = defender_bonuses

	# El bioma escala el ATK efectivo por la tile CONTRARIA; combat_mult es la
	# penalización económica del imperio del bando. Edificios y bonuses no pasan
	# por esos multiplicadores (ver CombatMath.total_attack).
	return CombatMath.total_attack(troops, enemy_troops, bonuses,
		_get_biome_attack_multiplier(enemy_tile),
		_get_side_combat_multiplier(side),
		_get_building_attack(own_tile))


## Calcula la defensa total de un bando.
##
## La defensa de las tropas se escala por el modificador de bioma de la tile
## **propia** (defender en bosque/montaña refuerza a las tropas; defender en
## pradera/desierto las debilita). Los edificios y bonuses tácticos no pasan
## por este multiplicador — los bonuses tienen su propio modificador de bioma.
func get_total_defense(side: BattleFront.Side) -> float:
	var own_tile: Tile
	var troops: Array[Troop]
	var bonuses: Array

	if side == BattleFront.Side.ATTACKER:
		own_tile = attacker_tile
		troops = attacker_troops
		bonuses = attacker_bonuses
	else:
		own_tile = defender_tile
		troops = defender_troops
		bonuses = defender_bonuses

	# El bioma escala la DEF de tropas por la tile PROPIA; combat_mult es la
	# penalización económica. Edificios y bonuses no pasan por esos multiplicadores.
	return CombatMath.total_defense(troops, bonuses,
		_get_biome_defense_multiplier(own_tile),
		_get_side_combat_multiplier(side),
		_get_building_defense(own_tile))


## Suma el ataque base de las tropas asignadas a un bando (sin bioma,
## edificios ni bonuses). Útil para informar al jugador de cuánta fuerza
## ha comprometido en el frente.
func get_assigned_troops_attack(side: BattleFront.Side) -> int:
	var total: int = 0
	var troops: Array[Troop] = attacker_troops if side == BattleFront.Side.ATTACKER else defender_troops
	for troop in troops:
		total += troop.attack
	return total


## Suma la defensa base de las tropas asignadas a un bando (sin bioma,
## edificios ni bonuses).
func get_assigned_troops_defense(side: BattleFront.Side) -> int:
	var total: int = 0
	var troops: Array[Troop] = attacker_troops if side == BattleFront.Side.ATTACKER else defender_troops
	for troop in troops:
		total += troop.defense
	return total


## Calcula la presión de un bando: atk / (1 + def_enemiga).
func get_pressure(side: BattleFront.Side) -> float:
	var atk: float
	var enemy_def: float
	if side == BattleFront.Side.ATTACKER:
		atk = get_total_attack(BattleFront.Side.ATTACKER)
		enemy_def = get_total_defense(BattleFront.Side.DEFENDER)
	else:
		atk = get_total_attack(BattleFront.Side.DEFENDER)
		enemy_def = get_total_defense(BattleFront.Side.ATTACKER)
	return CombatMath.pressure(atk, enemy_def)


## Procesa un turno del frente. Retorna true si el frente se resuelve.
func tick() -> bool:
	if is_resolved:
		return false

	turns_elapsed += 1

	# Calcular movimiento del marcador
	var atk_pressure := get_pressure(BattleFront.Side.ATTACKER)
	var def_pressure := get_pressure(BattleFront.Side.DEFENDER)
	var movement := atk_pressure - def_pressure
	marker += movement
	marker_changed.emit(self, marker)

	# Decrementar duración de bonuses temporales
	_tick_bonuses(attacker_bonuses)
	_tick_bonuses(defender_bonuses)

	# Comprobar resolución
	if can_resolve():
		_resolve()
		return true

	return false


## Verifica si el frente puede resolverse (duración mínima cumplida + umbral superado).
func can_resolve() -> bool:
	if is_resolved:
		return false
	if turns_elapsed < min_duration:
		return false
	return absf(marker) >= get_current_threshold()


## Umbral efectivo en el turno actual. Decae linealmente desde `threshold`
## (umbral inicial, por defecto 10) hasta `MIN_THRESHOLD` (5) durante los primeros
## `THRESHOLD_DECAY_TURNS` (10) turnos del frente. A partir de ahi se queda
## clavado en `MIN_THRESHOLD`.
##
## How to apply: usar este metodo en cualquier comparacion contra el umbral
## (can_resolve, calculate_casualties, _resolve, UI/visuales). Acceder
## directamente a `threshold` solo es valido para inicializacion, persistencia
## (save/load) o cuando se quiere el valor de configuracion, no el efectivo.
func get_current_threshold() -> float:
	return CombatMath.current_threshold(threshold, turns_elapsed)


## Asigna una tropa a un bando. Las tropas quedan comprometidas.
func assign_troop(troop: Troop, side: BattleFront.Side) -> void:
	if side == BattleFront.Side.ATTACKER:
		attacker_troops.append(troop)
	else:
		defender_troops.append(troop)


## Añade un bonus a un bando (de carta táctica, evento, edificio, etc.).
## Acepta un TacticBonus o un Dictionary (compatibilidad legacy para tests y
## código existente). Los Dictionaries se convierten internamente a TacticBonus.
## Emite `bonuses_changed` para que UI y visuales puedan refrescar.
func add_bonus(side: BattleFront.Side, bonus: Variant) -> void:
	var typed_bonus: TacticBonus
	if bonus is TacticBonus:
		typed_bonus = bonus
	else:
		typed_bonus = TacticBonus.from_dict(bonus as Dictionary)
	if side == BattleFront.Side.ATTACKER:
		attacker_bonuses.append(typed_bonus)
	else:
		defender_bonuses.append(typed_bonus)
	bonuses_changed.emit(side)


## Elimina todas las tácticas activas (bonuses con tactic_name no vacío) de
## un bando. NO toca otros bonuses (planos manuales, eventos, edificios).
##
## Política de diseño: cada frente sólo puede tener UNA táctica activa por
## bando. Las cartas tácticas llaman a este método antes de aplicarse para
## sustituir cualquier táctica anterior.
##
## Devuelve cuántas tácticas se eliminaron (0 si no había). Sólo emite
## `bonuses_changed` si hubo cambios reales.
func clear_tactics_for_side(side: BattleFront.Side) -> int:
	var bonuses: Array = attacker_bonuses if side == BattleFront.Side.ATTACKER else defender_bonuses
	var removed: int = 0
	var i := bonuses.size() - 1
	while i >= 0:
		var b := _as_tactic_bonus(bonuses[i])
		if b.tactic_name != "":
			bonuses.remove_at(i)
			removed += 1
		i -= 1
	if removed > 0:
		bonuses_changed.emit(side)
	return removed


## Indica si el bando tiene alguna táctica activa (bonus con tactic_name no vacío).
func has_active_tactic_on_side(side: BattleFront.Side) -> bool:
	var bonuses: Array = attacker_bonuses if side == BattleFront.Side.ATTACKER else defender_bonuses
	for raw_b in bonuses:
		var b := _as_tactic_bonus(raw_b)
		if b.tactic_name != "":
			return true
	return false


## Indica si alguno de los dos bandos tiene una táctica activa.
## Útil para el indicador visual del frente en el mapa 3D.
func has_any_active_tactic() -> bool:
	return has_active_tactic_on_side(BattleFront.Side.ATTACKER) or has_active_tactic_on_side(BattleFront.Side.DEFENDER)


## Calcula el coste de mantenimiento extra por frente (escalado progresivo).
## Retorna { "gold": int, "food": int } para un bando.
func get_front_maintenance(side: BattleFront.Side) -> Dictionary:
	var troops: Array[Troop]
	if side == BattleFront.Side.ATTACKER:
		troops = attacker_troops
	else:
		troops = defender_troops

	var extra_gold: int = 0
	var extra_food: int = 0
	for i in range(troops.size()):
		# Recargo progresivo: +5, +10, +15... por cada tropa adicional
		var surcharge: int = (i + 1) * GameBalance.FRONT_SURCHARGE_PER_TROOP
		extra_gold += surcharge
		extra_food += surcharge
	return { "gold": extra_gold, "food": extra_food }


## Calcula las bajas proporcionales tras resolución.
## Devuelve las bajas calculadas al resolver (snapshot inmutable).
## Solo disponible después de _resolve().
func get_resolved_casualties() -> Dictionary:
	return _calculated_casualties


## Retorna { "attacker_losses": int, "defender_losses": int } (indices a eliminar).
func calculate_casualties() -> Dictionary:
	if not is_resolved:
		return { "attacker_losses": 0, "defender_losses": 0 }
	# Usamos el umbral del turno en que se resolvio. Como `_resolve` se llama en el
	# mismo tick que detecta la resolucion, `get_current_threshold()` devuelve el
	# valor decaido apropiado para escalar la dominancia.
	var effective_threshold := get_current_threshold()
	var atk_pressure := get_pressure(BattleFront.Side.ATTACKER)
	var def_pressure := get_pressure(BattleFront.Side.DEFENDER)
	return CombatMath.casualties(marker, effective_threshold,
		attacker_troops.size(), defender_troops.size(),
		atk_pressure, def_pressure)


## --- Métodos privados ---

func _resolve() -> void:
	is_resolved = true
	# Mismo criterio que can_resolve: ganador determinado por el signo del
	# marker contra el umbral efectivo del turno. Con threshold decaido, un
	# marker positivo cualquiera >= umbral hace ganar al atacante.
	var attacker_won := marker >= get_current_threshold()
	# Calcular bajas una sola vez, antes de emitir la señal
	_calculated_casualties = calculate_casualties()
	BattleFrontRegistry.unregister(self)
	front_resolved.emit(self, attacker_won)


func _tick_bonuses(bonuses: Array) -> void:
	var i := bonuses.size() - 1
	while i >= 0:
		var raw: Variant = bonuses[i]
		if raw is TacticBonus:
			var b := raw as TacticBonus
			if b.duration >= 0:
				b.duration -= 1
				if b.duration <= 0:
					bonuses.remove_at(i)
		elif raw is Dictionary:
			# Compatibilidad legacy: bonuses asignados directamente como Dictionary.
			var d := raw as Dictionary
			if d.has("duration"):
				d["duration"] = int(d["duration"]) - 1
				if int(d["duration"]) <= 0:
					bonuses.remove_at(i)
		i -= 1


## Convierte un bonus (TacticBonus o Dictionary) en TacticBonus tipado.
## Llamada en cada acceso para mantener compatibilidad con ambos formatos.
func _as_tactic_bonus(raw: Variant) -> TacticBonus:
	return CombatMath.as_tactic_bonus(raw)


## Multiplicador que aplica al ATK efectivo del bando que ATACA esta tile.
## Delega en BiomeConfig para evitar duplicación con otras partes del código.
func _get_biome_attack_multiplier(tile: Tile) -> float:
	if tile == null or tile.mesh_data == null:
		return 1.0
	return biome_config.get_attack_multiplier(tile.mesh_data.type)


## Multiplicador que aplica a la DEF de las tropas del bando que DEFIENDE en
## esta tile. Delega en BiomeConfig.
func _get_biome_defense_multiplier(tile: Tile) -> float:
	if tile == null or tile.mesh_data == null:
		return 1.0
	return biome_config.get_defense_multiplier(tile.mesh_data.type)


## Devuelve el `combat_multiplier` del imperio del bando indicado.
## Si por algun motivo el empire es null (tests aislados, frente
## construido a mano sin imperio), devolvemos 1.0 — sin penalizacion.
func _get_side_combat_multiplier(side: BattleFront.Side) -> float:
	var empire: Empire = attacker_empire if side == BattleFront.Side.ATTACKER else defender_empire
	if empire == null:
		return 1.0
	return empire.combat_multiplier


## Suma el flat_defense_bonus de todos los edificios militares de la tile.
func _get_building_defense(tile: Tile) -> float:
	if tile == null:
		return 0.0
	var total: float = 0.0
	for building in tile.buildings:
		total += float(building.flat_defense_bonus)
	return total


## Reservado para futuros edificios con bonus de ataque.
func _get_building_attack(_tile: Tile) -> float:
	return 0.0
