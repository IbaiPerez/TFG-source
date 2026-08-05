extends RefCounted
class_name CombatMath

## Matemática PURA de combate de frentes, compartida por BattleFront (juego real,
## nodo con estado y señales) y AIRealSimulator (snapshot del MCTS). Antes cada uno
## reimplementaba estas fórmulas; la divergencia habría descuadrado la resolución de
## combate entre el juego y la simulación de la IA (riesgo de paridad #1).
##
## Opera sobre Troop y TacticBonus (los mismos tipos en ambos mundos) y recibe los
## multiplicadores ya resueltos (bioma, combat_multiplier, ataque de edificios), que
## cada llamante obtiene de su propia fuente de datos (Tile/Empire vs TileSnap/owner).


# ---------------------------------------------------------------------------
# Ataque y defensa totales de un bando
# ---------------------------------------------------------------------------

## Ataque total: (ataque efectivo de tropas × bioma × combat_mult) + ataque de
## edificios + bonuses tácticos (planos, por-tropa y porcentuales). El ataque
## efectivo pasa por la matriz de efectividad contra la composición enemiga; los
## edificios y bonuses no se ven afectados por el bioma base ni por combat_mult.
static func total_attack(troops: Array[Troop], enemy_troops: Array[Troop],
		bonuses: Array, biome_atk_mult: float, combat_mult: float,
		building_attack: float = 0.0) -> float:
	var total := building_attack
	var troops_attack := TroopEffectiveness.get_effective_attack(troops, enemy_troops)
	total += troops_attack * biome_atk_mult * combat_mult

	var flat_bonus := 0.0
	var percent_bonus := 0.0
	for raw in bonuses:
		var bonus := as_tactic_bonus(raw)
		flat_bonus += bonus.attack
		percent_bonus += bonus.attack_percent
		# Bonus plano por tipo de tropa (NO pasa por la matriz).
		if bonus.attack_per_troop != 0.0:
			flat_bonus += bonus.attack_per_troop * count_bonus_targets(troops, bonus)
		# Bonus porcentual por tipo: % del ATAQUE EFECTIVO de las tropas afectadas,
		# escalado por el modificador de bioma capturado al jugar la carta.
		if bonus.attack_percent_per_type != 0.0:
			var pct := bonus.attack_percent_per_type / 100.0
			var affected := sum_effective_attack_of_targeted(troops, enemy_troops, bonus)
			flat_bonus += affected * pct * bonus.attack_biome_modifier
	total += flat_bonus
	if percent_bonus != 0.0:
		total *= (1.0 + percent_bonus / 100.0)
	return maxf(total, 0.0)


## Defensa total: edificios defensivos + (defensa base de tropas × bioma ×
## combat_mult) + bonuses tácticos. La defensa NO pasa por la matriz de efectividad.
static func total_defense(troops: Array[Troop], bonuses: Array,
		biome_def_mult: float, combat_mult: float,
		building_defense: float = 0.0) -> float:
	var total := building_defense
	var troops_defense := 0.0
	for troop in troops:
		troops_defense += troop.defense
	total += troops_defense * biome_def_mult * combat_mult

	var flat_bonus := 0.0
	var percent_bonus := 0.0
	for raw in bonuses:
		var bonus := as_tactic_bonus(raw)
		flat_bonus += bonus.defense
		percent_bonus += bonus.defense_percent
		if bonus.defense_per_troop != 0.0:
			flat_bonus += bonus.defense_per_troop * count_bonus_targets(troops, bonus)
		# Bonus porcentual por tipo: % de la DEFENSA BASE de las tropas afectadas.
		if bonus.defense_percent_per_type != 0.0:
			var pct := bonus.defense_percent_per_type / 100.0
			var affected := sum_defense_of_targeted(troops, bonus)
			flat_bonus += affected * pct * bonus.defense_biome_modifier
	total += flat_bonus
	if percent_bonus != 0.0:
		total *= (1.0 + percent_bonus / 100.0)
	return maxf(total, 0.0)


# ---------------------------------------------------------------------------
# Presión, umbral y bajas
# ---------------------------------------------------------------------------

## Presión de un bando: atk / (1 + def_enemiga).
static func pressure(attack: float, enemy_defense: float) -> float:
	return attack / (1.0 + enemy_defense)


## Umbral efectivo del frente en el turno actual: decae linealmente desde
## `base_threshold` hasta FRONT_MIN_THRESHOLD en FRONT_THRESHOLD_DECAY_TURNS turnos.
## No decae si el decay está desactivado o el inicial ya es <= mínimo.
static func current_threshold(base_threshold: float, turns_elapsed: int) -> float:
	if GameBalance.FRONT_THRESHOLD_DECAY_TURNS <= 0 \
			or base_threshold <= GameBalance.FRONT_MIN_THRESHOLD:
		return base_threshold
	var t := clampf(float(turns_elapsed) / float(GameBalance.FRONT_THRESHOLD_DECAY_TURNS),
		0.0, 1.0)
	return lerpf(base_threshold, GameBalance.FRONT_MIN_THRESHOLD, t)


## Bajas proporcionales tras resolución. El perdedor pierde 60-100 % de sus tropas,
## el ganador 20-50 %, escalado por la dominancia (|marker| / umbral efectivo).
## Devuelve { "attacker_losses": int, "defender_losses": int }.
static func casualties(marker: float, effective_threshold: float,
		atk_count: int, def_count: int,
		atk_pressure: float, def_pressure: float) -> Dictionary:
	var atk_total := float(atk_count)
	var def_total := float(def_count)
	if atk_total == 0.0 and def_total == 0.0:
		return {"attacker_losses": 0, "defender_losses": 0}
	if atk_pressure + def_pressure == 0.0:
		return {"attacker_losses": 0, "defender_losses": 0}

	var attacker_won := marker >= effective_threshold
	var dominance := absf(marker) / effective_threshold  # 1.0 = justo en el umbral
	var loser_loss_ratio := clampf(0.6 + dominance * 0.2, 0.6, 1.0)
	var winner_loss_ratio := clampf(0.5 - dominance * 0.15, 0.2, 0.5)

	var atk_losses: int
	var def_losses: int
	if attacker_won:
		atk_losses = int(ceilf(atk_total * winner_loss_ratio))
		def_losses = int(ceilf(def_total * loser_loss_ratio))
	else:
		atk_losses = int(ceilf(atk_total * loser_loss_ratio))
		def_losses = int(ceilf(def_total * winner_loss_ratio))
	return {"attacker_losses": atk_losses, "defender_losses": def_losses}


# ---------------------------------------------------------------------------
# Bonuses tácticos
# ---------------------------------------------------------------------------

## Normaliza un bonus (TacticBonus o Dictionary legacy) a TacticBonus.
static func as_tactic_bonus(raw: Variant) -> TacticBonus:
	if raw is TacticBonus:
		return raw as TacticBonus
	return TacticBonus.from_dict(raw as Dictionary)


## Decrementa la duración de los bonuses y elimina los agotados. Los de duración
## negativa son permanentes y no expiran.
##
## Tolera el formato Dictionary legacy porque el mundo vivo aún lo admite; en el
## snapshot esa rama nunca se toma (allí los bonuses siempre nacen tipados).
static func tick_bonuses(bonuses: Array) -> void:
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
			var d := raw as Dictionary
			if d.has("duration"):
				d["duration"] = int(d["duration"]) - 1
				if int(d["duration"]) <= 0:
					bonuses.remove_at(i)
		i -= 1


## Elimina las TÁCTICAS de la lista (bonuses con `tactic_name` no vacío) y devuelve
## cuántas quitó. NO toca el resto de bonuses: planos manuales, de evento o de
## edificio. Es la regla que hace que cada bando tenga como mucho UNA táctica
## activa — las cartas tácticas llaman aquí antes de aplicarse.
static func clear_tactics(bonuses: Array) -> int:
	var removed := 0
	var i := bonuses.size() - 1
	while i >= 0:
		if as_tactic_bonus(bonuses[i]).tactic_name != "":
			bonuses.remove_at(i)
			removed += 1
		i -= 1
	return removed


## True si la lista tiene alguna táctica activa (bonus con `tactic_name` no vacío).
static func has_active_tactic(bonuses: Array) -> bool:
	for raw in bonuses:
		if as_tactic_bonus(raw).tactic_name != "":
			return true
	return false


## Cuántas tropas del bando son de un tipo (Troop.TroopType) concreto.
static func count_troops_by_type(troops: Array[Troop], troop_type: int) -> int:
	var count := 0
	for troop in troops:
		if troop.type == troop_type:
			count += 1
	return count


## Cuántas tropas del bando tienen un nombre concreto (matching legacy por nombre).
static func count_troops_by_name(troops: Array[Troop], troop_name: String) -> int:
	var count := 0
	for troop in troops:
		if troop.name == troop_name:
			count += 1
	return count


## Cuántas tropas del bando son objetivo de un bonus dirigido. Precedencia:
## troop_types (array) → troop_type (>=0) → troop_name (no vacío). 0 si no dirige.
static func count_bonus_targets(troops: Array[Troop], bonus: TacticBonus) -> int:
	if not bonus.troop_types.is_empty():
		var count := 0
		var allowed: Array[int] = bonus.troop_types
		for troop in troops:
			if troop.type in allowed:
				count += 1
		return count
	if bonus.troop_type >= 0:
		return count_troops_by_type(troops, bonus.troop_type)
	if bonus.troop_name != "":
		return count_troops_by_name(troops, bonus.troop_name)
	return 0


## True si una tropa concreta es objetivo del bonus.
static func is_troop_targeted_by_bonus(troop: Troop, bonus: TacticBonus) -> bool:
	if not bonus.troop_types.is_empty():
		return troop.type in bonus.troop_types
	if bonus.troop_type >= 0:
		return troop.type == bonus.troop_type
	if bonus.troop_name != "":
		return troop.name == bonus.troop_name
	return false


## Suma del ATAQUE EFECTIVO (tras la matriz de efectividad vs enemigo) de las
## tropas del bando que son objetivo del bonus.
static func sum_effective_attack_of_targeted(troops: Array[Troop],
		enemy_troops: Array[Troop], bonus: TacticBonus) -> float:
	var total := 0.0
	for troop in troops:
		if is_troop_targeted_by_bonus(troop, bonus):
			total += TroopEffectiveness.get_effective_attack_for_troop(troop, enemy_troops)
	return total


## Suma de la DEFENSA BASE de las tropas del bando que son objetivo del bonus.
static func sum_defense_of_targeted(troops: Array[Troop], bonus: TacticBonus) -> float:
	var total := 0.0
	for troop in troops:
		if is_troop_targeted_by_bonus(troop, bonus):
			total += float(troop.defense)
	return total
