extends RefCounted
class_name BattleFront

## Representa un frente de batalla activo entre dos tiles adyacentes.
## El marcador empieza en 0.0 y se mueve hacia +umbral (gana atacante)
## o -umbral (gana defensor).

signal front_resolved(front: BattleFront, attacker_won: bool)
signal marker_changed(front: BattleFront, new_value: float)
## Emitida cuando la lista de bonuses de un bando cambia (añadido o eliminado).
## Permite que la UI y los visuales 3D refresquen sin polling.
signal bonuses_changed(side: StringName)

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
var min_duration: int = 3

## Umbral inicial del frente. El umbral efectivo se calcula con
## `get_current_threshold()` y va decreciendo desde `threshold` (default 15)
## hasta `MIN_THRESHOLD` (10) de forma lineal en `THRESHOLD_DECAY_TURNS` (30)
## turnos transcurridos en el frente.
##
## Why: con threshold fijo en 20, los datos de simulacion mostraron que el
## ~50% de los frentes vivos en R100 tenian |marker| < 5 y ninguno alcanzaba
## el umbral. La fuerza simetrica entre bandos hace que el marker oscile
## cerca de 0 y el frente nunca cierre. Bajar el techo a 15 y dejar que el
## tiempo lo erosione hasta 10 evita esos atascos: cuanto mas tiempo lleva
## un frente abierto sin decision, mas facil se vuelve resolverlo.
var threshold: float = 15.0
const MIN_THRESHOLD: float = 10.0
const THRESHOLD_DECAY_TURNS: int = 30

## Tropas asignadas por bando (arrays de Troop)
var attacker_troops: Array[Troop] = []
var defender_troops: Array[Troop] = []

## Bonus temporales de cartas tácticas activas
## Cada entrada: { "attack": float, "defense": float, "duration": int }
var attacker_bonuses: Array[Dictionary] = []
var defender_bonuses: Array[Dictionary] = []

## Estado
var is_resolved: bool = false

## Registro global de frentes activos (sin resolver). Permite consultas
## entre imperios sin acoplar el manager local con managers ajenos.
## Se autoalimenta en _init y se limpia en _resolve.
static var _active_instances: Array[BattleFront] = []


func _init(p_atk_tile: Tile, p_def_tile: Tile, p_atk_empire: Empire, p_def_empire: Empire) -> void:
	attacker_tile = p_atk_tile
	defender_tile = p_def_tile
	attacker_empire = p_atk_empire
	defender_empire = p_def_empire
	_active_instances.append(self)


## Comprueba si una tile está participando ahora mismo en algún frente
## activo (atacante o defensora, en cualquier imperio).
static func is_tile_in_active_front(tile: Tile) -> bool:
	for front in _active_instances:
		if front.attacker_tile == tile or front.defender_tile == tile:
			return true
	return false


## Devuelve una copia de la lista global de frentes activos.
static func get_active_instances() -> Array[BattleFront]:
	return _active_instances.duplicate()


## Vacía el registro global. Pensado para limpiar entre tests o al cerrar
## la partida; en juego, los frentes se desregistran solos al resolverse.
static func clear_active_instances() -> void:
	_active_instances.clear()


## Calcula el ataque total de un bando (tropas + bioma + edificios + bonuses de cartas).
##
## El ataque base de las tropas se pasa por TroopEffectiveness para aplicar
## el multiplicador piedra-papel-tijera contra la composición enemiga, y
## después se escala por el modificador de bioma de la tile **contraria**
## (atacar un bosque/montaña es más difícil que asaltar una pradera). Los
## edificios y los bonuses de cartas tácticas no se ven afectados por el
## bioma base — los bonuses tienen su propio modificador capturado al jugar
## la carta.
func get_total_attack(side: StringName) -> float:
	var total: float = 0.0
	var own_tile: Tile
	var enemy_tile: Tile
	var troops: Array[Troop]
	var enemy_troops: Array[Troop]
	var bonuses: Array[Dictionary]

	if side == &"attacker":
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

	# Bonus de edificios militares (en la tile propia)
	total += _get_building_attack(own_tile)

	# Stats de tropas con efectividad por tipo aplicada (ataque efectivo)
	# escaladas por el modificador de bioma de la tile **contraria** y por
	# el `combat_multiplier` del imperio del bando (penalizacion economica
	# por deficit en oro/comida — Opcion 3 del rebalanceo). Edificios y
	# bonuses tacticos NO se ven afectados por la penalizacion economica.
	var troops_attack := TroopEffectiveness.get_effective_attack(troops, enemy_troops)
	var combat_mult := _get_side_combat_multiplier(side)
	total += troops_attack * _get_biome_attack_multiplier(enemy_tile) * combat_mult

	# Bonuses de cartas tácticas
	var flat_bonus: float = 0.0
	var percent_bonus: float = 0.0
	for bonus in bonuses:
		flat_bonus += bonus.get("attack", 0.0)
		percent_bonus += bonus.get("attack_percent", 0.0)
		# Bonus plano por tipo de tropa: attack_per_troop × tropas afectadas (NO pasa por matriz).
		if bonus.has("attack_per_troop"):
			var count := _count_bonus_targets(troops, bonus)
			flat_bonus += bonus["attack_per_troop"] * count
		# Bonus porcentual por tipo de tropa: % aplicado al ATAQUE EFECTIVO de las
		# tropas afectadas (sí pasa por la matriz piedra-papel-tijera). El modificador
		# de bioma capturado al jugar la carta escala el resultado.
		if bonus.has("attack_percent_per_type"):
			var pct: float = bonus["attack_percent_per_type"] / 100.0
			var biome_mod: float = bonus.get("attack_biome_modifier", 1.0)
			var affected_eff_atk := _sum_effective_attack_of_targeted(troops, enemy_troops, bonus)
			flat_bonus += affected_eff_atk * pct * biome_mod

	total += flat_bonus
	if percent_bonus != 0.0:
		total *= (1.0 + percent_bonus / 100.0)

	return maxf(total, 0.0)


## Calcula la defensa total de un bando.
##
## La defensa de las tropas se escala por el modificador de bioma de la tile
## **propia** (defender en bosque/montaña refuerza a las tropas; defender en
## pradera/desierto las debilita). Los edificios y bonuses tácticos no pasan
## por este multiplicador — los bonuses tienen su propio modificador de bioma.
func get_total_defense(side: StringName) -> float:
	var total: float = 0.0
	var own_tile: Tile
	var troops: Array[Troop]
	var bonuses: Array[Dictionary]

	if side == &"attacker":
		own_tile = attacker_tile
		troops = attacker_troops
		bonuses = attacker_bonuses
	else:
		own_tile = defender_tile
		troops = defender_troops
		bonuses = defender_bonuses

	# Bonus de edificios militares (en la tile propia)
	total += _get_building_defense(own_tile)

	# Stats de tropas escalados por el modificador de bioma de la tile propia
	# y por el `combat_multiplier` del imperio del bando (penalizacion
	# economica por deficit en oro/comida — Opcion 3). Edificios y bonuses
	# tacticos NO se ven afectados.
	var troops_defense: float = 0.0
	for troop in troops:
		troops_defense += troop.defense
	var combat_mult := _get_side_combat_multiplier(side)
	total += troops_defense * _get_biome_defense_multiplier(own_tile) * combat_mult

	# Bonuses de cartas tácticas
	var flat_bonus: float = 0.0
	var percent_bonus: float = 0.0
	for bonus in bonuses:
		flat_bonus += bonus.get("defense", 0.0)
		percent_bonus += bonus.get("defense_percent", 0.0)
		# Bonus plano por tipo de tropa.
		if bonus.has("defense_per_troop"):
			var count := _count_bonus_targets(troops, bonus)
			flat_bonus += bonus["defense_per_troop"] * count
		# Bonus porcentual por tipo de tropa: % aplicado a la DEFENSA BASE de
		# las tropas afectadas. El modificador de bioma capturado al jugar la
		# carta escala el resultado.
		if bonus.has("defense_percent_per_type"):
			var pct: float = bonus["defense_percent_per_type"] / 100.0
			var biome_mod: float = bonus.get("defense_biome_modifier", 1.0)
			var affected_def := _sum_defense_of_targeted(troops, bonus)
			flat_bonus += affected_def * pct * biome_mod

	total += flat_bonus
	if percent_bonus != 0.0:
		total *= (1.0 + percent_bonus / 100.0)

	return maxf(total, 0.0)


## Suma el ataque base de las tropas asignadas a un bando (sin bioma,
## edificios ni bonuses). Útil para informar al jugador de cuánta fuerza
## ha comprometido en el frente.
func get_assigned_troops_attack(side: StringName) -> int:
	var total: int = 0
	var troops: Array[Troop] = attacker_troops if side == &"attacker" else defender_troops
	for troop in troops:
		total += troop.attack
	return total


## Suma la defensa base de las tropas asignadas a un bando (sin bioma,
## edificios ni bonuses).
func get_assigned_troops_defense(side: StringName) -> int:
	var total: int = 0
	var troops: Array[Troop] = attacker_troops if side == &"attacker" else defender_troops
	for troop in troops:
		total += troop.defense
	return total


## Calcula la presión de un bando: atk / (1 + def_enemiga).
func get_pressure(side: StringName) -> float:
	var atk: float
	var enemy_def: float
	if side == &"attacker":
		atk = get_total_attack(&"attacker")
		enemy_def = get_total_defense(&"defender")
	else:
		atk = get_total_attack(&"defender")
		enemy_def = get_total_defense(&"attacker")
	return atk / (1.0 + enemy_def)


## Procesa un turno del frente. Retorna true si el frente se resuelve.
func tick() -> bool:
	if is_resolved:
		return false

	turns_elapsed += 1

	# Calcular movimiento del marcador
	var atk_pressure := get_pressure(&"attacker")
	var def_pressure := get_pressure(&"defender")
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
## (umbral inicial, p.ej. 15) hasta `MIN_THRESHOLD` (10) durante los primeros
## `THRESHOLD_DECAY_TURNS` (30) turnos del frente. A partir de ahi se queda
## clavado en `MIN_THRESHOLD`.
##
## How to apply: usar este metodo en cualquier comparacion contra el umbral
## (can_resolve, calculate_casualties, _resolve, UI/visuales). Acceder
## directamente a `threshold` solo es valido para inicializacion, persistencia
## (save/load) o cuando se quiere el valor de configuracion, no el efectivo.
func get_current_threshold() -> float:
	# Casos triviales: decay desactivado, o el inicial ya es <= MIN_THRESHOLD
	# (configuracion de test con thresholds pequeños). En ambos casos, no
	# decaemos — el threshold solo baja, nunca sube.
	if THRESHOLD_DECAY_TURNS <= 0 or threshold <= MIN_THRESHOLD:
		return threshold
	var t: float = clampf(float(turns_elapsed) / float(THRESHOLD_DECAY_TURNS), 0.0, 1.0)
	return lerpf(threshold, MIN_THRESHOLD, t)


## Asigna una tropa a un bando. Las tropas quedan comprometidas.
func assign_troop(troop: Troop, side: StringName) -> void:
	if side == &"attacker":
		attacker_troops.append(troop)
	else:
		defender_troops.append(troop)


## Añade un bonus a un bando (de carta táctica, evento, edificio, etc.).
## Emite `bonuses_changed` para que UI y visuales puedan refrescar.
func add_bonus(side: StringName, bonus: Dictionary) -> void:
	if side == &"attacker":
		attacker_bonuses.append(bonus)
	else:
		defender_bonuses.append(bonus)
	bonuses_changed.emit(side)


## Elimina todas las tácticas activas (bonuses con clave `tactic_name`) de
## un bando. NO toca otros bonuses (planos manuales, eventos, edificios).
##
## Política de diseño: cada frente sólo puede tener UNA táctica activa por
## bando. Las cartas tácticas llaman a este método antes de aplicarse para
## sustituir cualquier táctica anterior.
##
## Devuelve cuántas tácticas se eliminaron (0 si no había). Sólo emite
## `bonuses_changed` si hubo cambios reales.
func clear_tactics_for_side(side: StringName) -> int:
	var bonuses: Array[Dictionary] = attacker_bonuses if side == &"attacker" else defender_bonuses
	var removed: int = 0
	var i := bonuses.size() - 1
	while i >= 0:
		if bonuses[i].has("tactic_name"):
			bonuses.remove_at(i)
			removed += 1
		i -= 1
	if removed > 0:
		bonuses_changed.emit(side)
	return removed


## Indica si el bando tiene alguna táctica activa (bonus con `tactic_name`).
func has_active_tactic_on_side(side: StringName) -> bool:
	var bonuses: Array[Dictionary] = attacker_bonuses if side == &"attacker" else defender_bonuses
	for b in bonuses:
		if b.has("tactic_name"):
			return true
	return false


## Indica si alguno de los dos bandos tiene una táctica activa.
## Útil para el indicador visual del frente en el mapa 3D.
func has_any_active_tactic() -> bool:
	return has_active_tactic_on_side(&"attacker") or has_active_tactic_on_side(&"defender")


## Calcula el coste de mantenimiento extra por frente (escalado progresivo).
## Retorna { "gold": int, "food": int } para un bando.
func get_front_maintenance(side: StringName) -> Dictionary:
	var troops: Array[Troop]
	if side == &"attacker":
		troops = attacker_troops
	else:
		troops = defender_troops

	var extra_gold: int = 0
	var extra_food: int = 0
	for i in range(troops.size()):
		# Recargo progresivo: +1, +2, +3... por cada tropa adicional
		var surcharge: int = i + 1
		extra_gold += surcharge
		extra_food += surcharge
	return { "gold": extra_gold, "food": extra_food }


## Calcula las bajas proporcionales tras resolución.
## Retorna { "attacker_losses": int, "defender_losses": int } (indices a eliminar).
func calculate_casualties() -> Dictionary:
	if not is_resolved:
		return { "attacker_losses": 0, "defender_losses": 0 }

	# Usamos el umbral del turno en que se resolvio. Como `_resolve` se llama
	# en el mismo tick que detecta la resolucion, `get_current_threshold()`
	# devuelve el valor decaido apropiado para escalar la dominancia.
	var effective_threshold := get_current_threshold()
	var attacker_won := marker >= effective_threshold

	# La presión acumulada recibida determina las bajas
	# El bando que recibió más presión pierde mayor porcentaje
	var atk_total := float(attacker_troops.size())
	var def_total := float(defender_troops.size())

	if atk_total == 0 and def_total == 0:
		return { "attacker_losses": 0, "defender_losses": 0 }

	# Ratio de bajas basado en la presión relativa final
	var atk_pressure := get_pressure(&"attacker")
	var def_pressure := get_pressure(&"defender")
	var total_pressure := atk_pressure + def_pressure

	if total_pressure == 0.0:
		return { "attacker_losses": 0, "defender_losses": 0 }

	# El perdedor pierde entre 60-100% de tropas, el ganador entre 20-50%
	var winner_loss_ratio: float
	var loser_loss_ratio: float

	var dominance := absf(marker) / effective_threshold  # 1.0 = justo en el umbral, >1 = aplastante
	loser_loss_ratio = clampf(0.6 + dominance * 0.2, 0.6, 1.0)
	winner_loss_ratio = clampf(0.5 - dominance * 0.15, 0.2, 0.5)

	var atk_losses: int
	var def_losses: int
	if attacker_won:
		atk_losses = int(ceilf(atk_total * winner_loss_ratio))
		def_losses = int(ceilf(def_total * loser_loss_ratio))
	else:
		atk_losses = int(ceilf(atk_total * loser_loss_ratio))
		def_losses = int(ceilf(def_total * winner_loss_ratio))

	return { "attacker_losses": atk_losses, "defender_losses": def_losses }


## --- Métodos privados ---

func _resolve() -> void:
	is_resolved = true
	# Mismo criterio que can_resolve: ganador determinado por el signo del
	# marker contra el umbral efectivo del turno. Con threshold decaido, un
	# marker positivo cualquiera >= umbral hace ganar al atacante.
	var attacker_won := marker >= get_current_threshold()
	_active_instances.erase(self)
	front_resolved.emit(self, attacker_won)


func _tick_bonuses(bonuses: Array[Dictionary]) -> void:
	var i := bonuses.size() - 1
	while i >= 0:
		if bonuses[i].has("duration"):
			bonuses[i]["duration"] -= 1
			if bonuses[i]["duration"] <= 0:
				bonuses.remove_at(i)
		i -= 1


## Multiplicador que aplica al ATK efectivo del bando que ATACA esta tile.
##
## Se interpreta como "lo difícil que es asaltar el terreno": un bosque o una
## montaña frenan al asaltante, una pradera o un desierto facilitan el avance.
## Coherente con el modificador de bioma que usan las cartas tácticas
## (atributo "atacar a la tile contraria").
##
## Rango ~[0.6, 1.2]. Multiplicadores conservadores; el balance fino se hará
## jugando partidas reales.
func _get_biome_attack_multiplier(tile: Tile) -> float:
	if tile == null or tile.mesh_data == null:
		return 1.0
	match tile.mesh_data.type:
		Tile.biome_type.Grassland:
			return 1.20
		Tile.biome_type.Desert:
			return 1.10
		Tile.biome_type.Tundra:
			return 0.95
		Tile.biome_type.Forest:
			return 0.80
		Tile.biome_type.Swamp:
			return 0.70
		Tile.biome_type.Mountain:
			return 0.60
		Tile.biome_type.Ocean:
			return 1.00
		_:
			return 1.00


## Multiplicador que aplica a la DEF de las tropas del bando que DEFIENDE en
## esta tile. Bioma "fortaleza natural" → >1.0; bioma abierto → <1.0.
##
## Rango ~[0.85, 1.5]. Las montañas son la mejor posición defensiva; los
## desiertos y praderas, las peores. Tundra queda neutra.
func _get_biome_defense_multiplier(tile: Tile) -> float:
	if tile == null or tile.mesh_data == null:
		return 1.0
	match tile.mesh_data.type:
		Tile.biome_type.Mountain:
			return 1.50
		Tile.biome_type.Forest:
			return 1.25
		Tile.biome_type.Swamp:
			return 1.20
		Tile.biome_type.Tundra:
			return 1.00
		Tile.biome_type.Grassland:
			return 0.90
		Tile.biome_type.Desert:
			return 0.85
		Tile.biome_type.Ocean:
			return 1.00
		_:
			return 1.00


## Devuelve el `combat_multiplier` del imperio del bando indicado.
## Si por algun motivo el empire es null (tests aislados, frente
## construido a mano sin imperio), devolvemos 1.0 — sin penalizacion.
func _get_side_combat_multiplier(side: StringName) -> float:
	var empire: Empire = attacker_empire if side == &"attacker" else defender_empire
	if empire == null:
		return 1.0
	return empire.combat_multiplier


## Placeholder: bonus de ataque por edificios militares.
func _get_building_attack(_tile: Tile) -> float:
	# TODO: recorrer buildings y sumar bonus de ataque de edificios militares
	return 0.0


## Placeholder: bonus de defensa por edificios militares.
func _get_building_defense(_tile: Tile) -> float:
	# TODO: recorrer buildings y sumar bonus de defensa de edificios militares
	return 0.0


## Cuenta cuántas tropas de un bando tienen un nombre específico.
func _count_troops_by_name(troops: Array[Troop], troop_name: String) -> int:
	var count := 0
	for troop in troops:
		if troop.name == troop_name:
			count += 1
	return count


## Cuenta cuántas tropas de un bando son de un tipo (Troop.TroopType) concreto.
func _count_troops_by_type(troops: Array[Troop], troop_type: int) -> int:
	var count := 0
	for troop in troops:
		if troop.type == troop_type:
			count += 1
	return count


## Devuelve cuántas tropas del bando son afectadas por un bonus dirigido.
## Acepta tres formas en el diccionario (orden de precedencia):
##   - "troop_types": Array[int]  → lista de Troop.TroopType (cartas multi-tipo, p. ej. Falange).
##   - "troop_type":  int         → un único Troop.TroopType.
##   - "troop_name":  String      → nombre cosmético (legacy).
## Si el bonus no especifica ninguno, devuelve 0 — los bonuses por unidad
## requieren un objetivo explícito; un bonus genérico debería usar las claves
## planas "attack" / "defense" en su lugar.
func _count_bonus_targets(troops: Array[Troop], bonus: Dictionary) -> int:
	if bonus.has("troop_types"):
		var count := 0
		var allowed: Array = bonus["troop_types"]
		for troop in troops:
			if troop.type in allowed:
				count += 1
		return count
	if bonus.has("troop_type"):
		return _count_troops_by_type(troops, int(bonus["troop_type"]))
	if bonus.has("troop_name"):
		return _count_troops_by_name(troops, String(bonus["troop_name"]))
	return 0


## Indica si una tropa concreta es objetivo del bonus dado, siguiendo la
## misma precedencia que `_count_bonus_targets`.
func _is_troop_targeted_by_bonus(troop: Troop, bonus: Dictionary) -> bool:
	if bonus.has("troop_types"):
		var allowed: Array = bonus["troop_types"]
		return troop.type in allowed
	if bonus.has("troop_type"):
		return troop.type == int(bonus["troop_type"])
	if bonus.has("troop_name"):
		return troop.name == String(bonus["troop_name"])
	return false


## Suma el ataque efectivo (después de aplicar la matriz de efectividad
## contra la composición enemiga) de las tropas del bando que son objetivo
## del bonus. Útil para aplicar bonuses porcentuales por tipo que sí deben
## verse afectados por los matchups piedra-papel-tijera.
func _sum_effective_attack_of_targeted(troops: Array[Troop],
		enemy_troops: Array[Troop], bonus: Dictionary) -> float:
	var total: float = 0.0
	for troop in troops:
		if _is_troop_targeted_by_bonus(troop, bonus):
			total += TroopEffectiveness.get_effective_attack_for_troop(troop, enemy_troops)
	return total


## Suma la defensa base de las tropas del bando que son objetivo del bonus.
## La defensa no pasa por la matriz de efectividad (sólo el ataque la usa).
func _sum_defense_of_targeted(troops: Array[Troop], bonus: Dictionary) -> float:
	var total: float = 0.0
	for troop in troops:
		if _is_troop_targeted_by_bonus(troop, bonus):
			total += float(troop.defense)
	return total
