extends RefCounted
class_name AIRealSimulator

## Motor de simulación headless sobre AIRealState (Fase C v2).
##
## Reimplementa, como funciones PURAS, los efectos reales de las cartas que en
## el juego viven acoplados a escena/señales (ColonizeEffect, Tile.build,
## Tile.upgrade, ChangeLocationTypeEffect…). Cada función muta el estado que
## recibe IN-PLACE; el llamante (árbol MCTS) clona antes si quiere conservar el
## original — mismo contrato que AISimulator de v1.
##
## Principio de paridad (PLAN §6): tras aplicar una secuencia de efectos y un
## advance_turn, la economía resultante (gpt, food, total_gold) debe coincidir
## con la del juego real tras las mismas jugadas + _process_turn_start. Por eso
## la economía NO se acumula a mano efecto a efecto, sino que se RECALCULA desde
## las casillas (espejo de ProductionCalculator), igual que hace el juego al
## inicio de cada turno.
##
## ALCANCE F1: colonize / build / direct_build / upgrade / change_location /
## generate_gold + advance_turn (ingresos). SIN frentes, SIN tropas, SIN
## modificadores, SIN habilidad de imperio (todo eso entra en F2/F2.5). La
## economía recalculada asume por tanto: gpt = Σ producción de oro de las
## casillas propias; food = Σ producción de comida neta de las casillas propias.


# ---------------------------------------------------------------------------
# Recálculo de economía (espejo de ProductionCalculator base, sin extras F2.5)
# ---------------------------------------------------------------------------

## Recalcula gold_per_turn, food y combat_multiplier de un imperio (espejo
## completo de ProductionCalculator + EmpireController._update_combat_multiplier,
## F2.5a incluye modificadores y habilidad de imperio):
##   1. base = Σ (producción de casilla + bonus de modifier por recurso) + flat
##   2. percent (solo sobre la parte positiva)
##   3. − mantenimiento base de tropas del pool (con descuento % clampeado)
##   4. − recargo progresivo de frentes (sin descuento)
##   5. combat_multiplier = clamp(1 − déficit/mantenimiento_total, 0.1, 1.0)
## Los modifiers del rival no se modelan (ocultos); para él Σmodifiers = ∅, que
## reproduce el comportamiento base de F2.
static func recompute_economy(state: AIRealState, p_owner: int) -> void:
	var emp := _empire_of(state, p_owner)
	if emp == null:
		return
	var mods := emp.modifiers

	# 1. Producción base de las casillas + bonus de recurso por modifier + flat.
	var base_gold := 0
	var base_food := 0
	for id in state.tiles:
		var t := state.tiles[id] as AIRealState.TileSnap
		if t.owner == p_owner:
			base_gold += t.gold_production() + _tile_gold_bonus(mods, t)
			base_food += t.food_production() + _tile_food_bonus(mods, t)
	base_gold += _flat_gold(mods)
	base_food += _flat_food(mods)

	# 2. Modificadores porcentuales: solo sobre la producción positiva (espejo de
	#    ProductionCalculator._calculate_base_production).
	var gold_positive := maxi(base_gold, 0)
	var gold_negative := mini(base_gold, 0)
	var food_positive := maxi(base_food, 0)
	var food_negative := mini(base_food, 0)
	var prod_gold := int(gold_positive * (1.0 + _percent_gold(mods) / 100.0)) + gold_negative
	var prod_food := int(food_positive * (1.0 + _percent_food(mods) / 100.0)) + food_negative

	# 3. Mantenimiento base de las tropas del pool, con descuento porcentual
	#    clampeado (espejo de ProductionCalculator._calculate_troop_maintenance).
	var maint_gold := 0
	var maint_food := 0
	for troop in emp.troop_pool:
		var percent := _troop_maintenance_percent(mods, troop)
		var multiplier := ModifierManager.clamp_cost_multiplier(1.0 + percent / 100.0)
		maint_gold += int(troop.maintenance_gold * multiplier)
		maint_food += int(troop.maintenance_food * multiplier)

	# 4. Recargo progresivo por tropas asignadas a frentes (sin descuento).
	var surcharge_gold := 0
	var surcharge_food := 0
	for f in state.fronts:
		var front := f as AIRealState.FrontSnap
		if front.is_resolved:
			continue
		var side := front.side_of(p_owner)
		if side == &"":
			continue
		var troops := front.attacker_troops if side == &"attacker" else front.defender_troops
		for i in range(troops.size()):
			var sc := (i + 1) * 5
			surcharge_gold += sc
			surcharge_food += sc

	emp.gold_per_turn = prod_gold - maint_gold - surcharge_gold
	emp.food = prod_food - maint_food - surcharge_food

	# 5. Penalización de combate por déficit (Opción 3 del rebalanceo).
	var total_maint := maint_gold + maint_food + surcharge_gold + surcharge_food
	if total_maint <= 0:
		emp.combat_multiplier = 1.0
	else:
		var deficit := maxi(0, -emp.gold_per_turn) + maxi(0, -emp.food)
		emp.combat_multiplier = clampf(1.0 - float(deficit) / float(total_maint), 0.1, 1.0)


static func recompute_own_economy(state: AIRealState) -> void:
	recompute_economy(state, AIRealState.OWNER_SELF)


# ---------------------------------------------------------------------------
# Efectos puros de carta (mutan el estado in-place)
# ---------------------------------------------------------------------------

## Colonize: una casilla sin colonizar pasa a manos de `p_owner` y, por la
## lógica del juego (TilesTracker._on_change_tile_controller), si estaba
## Uncolonized se urbaniza a Village. Recalcula la economía del propietario.
static func apply_colonize(state: AIRealState, tile_id: int,
		p_owner: int = AIRealState.OWNER_SELF) -> void:
	if not state.tiles.has(tile_id):
		return
	var t := _writable(state, tile_id)
	t.owner = p_owner
	if t.location_type == Tile.location_type.Uncolonized:
		_set_village(t)
	recompute_economy(state, p_owner)


## Build: construye `building` en la casilla (espejo de Tile.build). Descuenta
## el coste de construcción del oro del propietario y recalcula su economía.
## Asume coste efectivo == construction_cost (sin modificadores en F1).
static func apply_build(state: AIRealState, tile_id: int, building: Building,
		p_owner: int = AIRealState.OWNER_SELF) -> void:
	var t := state.tiles.get(tile_id) as AIRealState.TileSnap
	if t == null or building == null:
		return
	if not t.can_build(building):
		return
	t = _writable(state, tile_id)   # COW antes de mutar
	t.buildings.append(building)
	var emp := _empire_of(state, p_owner)
	if emp != null:
		emp.gold -= _effective_build_cost(building, emp)
	recompute_economy(state, p_owner)


## DirectBuild: idéntico a Build pero el edificio viene fijado por la carta.
static func apply_direct_build(state: AIRealState, tile_id: int, building: Building,
		p_owner: int = AIRealState.OWNER_SELF) -> void:
	apply_build(state, tile_id, building, p_owner)


## Upgrade: sustituye `old_building` por `new_building` en la casilla (espejo de
## Tile.upgrade). Descuenta el coste del nuevo edificio y recalcula la economía.
static func apply_upgrade(state: AIRealState, tile_id: int,
		old_building: Building, new_building: Building,
		p_owner: int = AIRealState.OWNER_SELF) -> void:
	var t := state.tiles.get(tile_id) as AIRealState.TileSnap
	if t == null or old_building == null or new_building == null:
		return
	var idx := t.buildings.find(old_building)
	if idx == -1:
		return
	t = _writable(state, tile_id)   # COW antes de mutar (el índice se conserva)
	t.buildings.remove_at(idx)
	t.buildings.insert(idx, new_building)
	var emp := _empire_of(state, p_owner)
	if emp != null:
		emp.gold -= _effective_build_cost(new_building, emp)
	recompute_economy(state, p_owner)


## ChangeLocation: sube el tipo de localización de la casilla (Village→Town→
## Megalópolis). Aplica el nuevo max_building y food_consumption, y demuele los
## edificios incompatibles con la nueva localización (espejo de
## ChangeLocationTypeEffect). Recalcula la economía del propietario.
static func apply_change_location(state: AIRealState, tile_id: int,
		new_location: LocationType, p_owner: int = AIRealState.OWNER_SELF) -> void:
	var t := state.tiles.get(tile_id) as AIRealState.TileSnap
	if t == null or new_location == null:
		return
	t = _writable(state, tile_id)   # COW antes de mutar
	t.location_type = new_location.type
	t.max_buildings = new_location.max_building
	t.food_consumption = new_location.food_consumption
	# Demoler edificios cuya allowed_location_type no incluye el nuevo tipo.
	var survivors: Array[Building] = []
	for b in t.buildings:
		if b == null:
			continue
		if _building_survives(b, new_location.type):
			survivors.append(b)
	t.buildings = survivors
	recompute_economy(state, p_owner)


## GenerateGold: oro inmediato one-shot (espejo de GenerateGoldCard). No afecta
## a la producción por turno.
static func apply_generate_gold(state: AIRealState, amount: int,
		p_owner: int = AIRealState.OWNER_SELF) -> void:
	var emp := _empire_of(state, p_owner)
	if emp != null:
		emp.gold += amount


# ---------------------------------------------------------------------------
# Efectos militares (F2)
# ---------------------------------------------------------------------------

## Recruit: añade `count` tropas del tipo `troop` al pool, descontando
## `recruitment_cost_gold` por tropa (espejo de Stats.recruit_troop, que se
## detiene si el oro no alcanza). El llamante calcula `count` con
## RecruitCard.get_effective_troops_per_play; sin modifiers es 1.
static func apply_recruit(state: AIRealState, troop: Troop, count: int = 1,
		p_owner: int = AIRealState.OWNER_SELF) -> void:
	var emp := _empire_of(state, p_owner)
	if emp == null or troop == null:
		return
	for _i in range(count):
		if emp.gold < troop.recruitment_cost_gold:
			break   # como recruit_troop: deja de reclutar si no hay oro
		emp.gold -= troop.recruitment_cost_gold
		emp.troop_pool.append(troop)
	recompute_economy(state, p_owner)


## OpenFront: abre un frente entre una casilla propia (atacante) y una enemiga
## adyacente (defensora). Espejo de BattleFrontManager.open_front: valida
## adyacencia, que ninguna de las dos casillas esté ya en un frente, y el límite
## de frentes simultáneos (get_max_fronts). Devuelve el FrontSnap creado o null.
static func apply_open_front(state: AIRealState, attacker_tile_id: int,
		defender_tile_id: int, p_owner: int = AIRealState.OWNER_SELF) -> AIRealState.FrontSnap:
	var atk := state.tiles.get(attacker_tile_id) as AIRealState.TileSnap
	var def := state.tiles.get(defender_tile_id) as AIRealState.TileSnap
	if atk == null or def == null:
		return null
	if atk.owner != p_owner:
		return null
	# Adyacencia.
	if defender_tile_id not in atk.neighbor_ids:
		return null
	# Límite de frentes simultáneos para este imperio.
	if _active_front_count(state, p_owner) >= _get_max_fronts(state, p_owner):
		return null
	# Una casilla solo puede estar en un frente a la vez (regla global).
	if _tile_in_active_front(state, attacker_tile_id) \
			or _tile_in_active_front(state, defender_tile_id):
		return null

	var fs := AIRealState.FrontSnap.new()
	fs.attacker_owner = p_owner
	fs.defender_owner = def.owner
	fs.attacker_tile_id = attacker_tile_id
	fs.defender_tile_id = defender_tile_id
	state.fronts.append(fs)
	return fs


## Tactic: aplica una carta táctica a un frente desde el bando de `p_owner`
## (espejo de TacticCard.apply_to_front: sustituye cualquier táctica previa del
## bando y añade el TacticBonus con los modificadores de bioma congelados).
static func apply_tactic(state: AIRealState, front: AIRealState.FrontSnap,
		card: TacticCard, p_owner: int = AIRealState.OWNER_SELF) -> void:
	if front == null or card == null or front.is_resolved:
		return
	var side := front.side_of(p_owner)
	if side == &"":
		return

	# Biomas relevantes: ATK mira la tile contraria, DEF la propia.
	var own_tile_id := front.attacker_tile_id if side == &"attacker" else front.defender_tile_id
	var enemy_tile_id := front.defender_tile_id if side == &"attacker" else front.attacker_tile_id
	var atk_biome_mod := _tactic_biome_modifier(state, card, enemy_tile_id)
	var def_biome_mod := _tactic_biome_modifier(state, card, own_tile_id)

	# Política exclusiva: una sola táctica activa por bando.
	_clear_tactics_for_side(front, side)

	var bonus := TacticBonus.new()
	bonus.tactic_name = card.tactic_name
	bonus.troop_types = card.affected_troop_types.duplicate()
	bonus.attack_percent_per_type = card.attack_percent_per_type
	bonus.defense_percent_per_type = card.defense_percent_per_type
	bonus.attack_per_troop = card.attack_per_troop
	bonus.defense_per_troop = card.defense_per_troop
	bonus.attack_biome_modifier = atk_biome_mod
	bonus.defense_biome_modifier = def_biome_mod
	if side == &"attacker":
		front.attacker_bonuses.append(bonus)
	else:
		front.defender_bonuses.append(bonus)


# ---------------------------------------------------------------------------
# Asignación de tropas a frentes (espejo de AIController._assign_troops_to_fronts)
# ---------------------------------------------------------------------------

## Reparte las tropas del pool de `p_owner` entre sus frentes, priorizando por
## urgencia (espejo de AIController._assign_troops_to_fronts v2): primera pasada
## hasta MIN_TROOPS_PER_FRONT (3); segunda pasada hasta MIN+2 en frentes que se
## pierden activamente. Defensor → max defensa; atacante → max ataque.
static func assign_troops_to_fronts(state: AIRealState,
		p_owner: int = AIRealState.OWNER_SELF) -> void:
	var emp := _empire_of(state, p_owner)
	if emp == null or emp.troop_pool.is_empty():
		return

	var entries: Array = []
	for f in state.fronts:
		var front := f as AIRealState.FrontSnap
		if front.is_resolved:
			continue
		var side := front.side_of(p_owner)
		if side == &"":
			continue
		var base_urg := _front_base_urgency(front, side)
		var cur := front.attacker_troops if side == &"attacker" else front.defender_troops
		var full_urg := base_urg * (2.0 if cur.is_empty() else 1.0)
		entries.append({"front": front, "side": side, "base_urgency": base_urg, "urgency": full_urg})
	if entries.is_empty():
		return
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.urgency > b.urgency)

	# Primera pasada: llenar hasta MIN_TROOPS_PER_FRONT.
	for entry in entries:
		if emp.troop_pool.is_empty():
			return
		var front: AIRealState.FrontSnap = entry.front
		var side: StringName = entry.side
		var troops := front.attacker_troops if side == &"attacker" else front.defender_troops
		while troops.size() < MIN_TROOPS_PER_FRONT and not emp.troop_pool.is_empty():
			if not _assign_best_troop(emp, front, side):
				break

	# Segunda pasada: reforzar frentes que se pierden activamente.
	for entry in entries:
		if emp.troop_pool.is_empty():
			return
		if entry.base_urgency <= 1.5:
			continue
		var front: AIRealState.FrontSnap = entry.front
		var side: StringName = entry.side
		var troops := front.attacker_troops if side == &"attacker" else front.defender_troops
		while troops.size() < MIN_TROOPS_PER_FRONT + 2 and not emp.troop_pool.is_empty():
			if not _assign_best_troop(emp, front, side):
				break


## Mínimo de tropas por frente en la primera pasada (espejo de
## AIController.MIN_TROOPS_PER_FRONT).
const MIN_TROOPS_PER_FRONT: int = 3


# ---------------------------------------------------------------------------
# Transición de turno
# ---------------------------------------------------------------------------

## Cierra el turno (espejo del flujo de EmpireController/AIController):
##   1. Asignar tropas del pool a los frentes (las reclutadas este turno se
##      reparten antes del siguiente tick — espejo de _assign_troops_to_fronts).
##   2. Recalcular economía + combat_multiplier (process_turn_start) y acumular
##      el ingreso (total_gold += gold_per_turn).
##   3. Tickear los frentes activos (process_battle_fronts): mover marcador,
##      decaer umbral y resolver los que superan el umbral (conquista + bajas).
##   4. Incrementar el contador de turno.
##
## F2.5b: incluye el chance node de eventos de fin de turno (propio). El rival
## aún no juega su mano determinizada ni sus eventos (F3; su info es oculta);
## aquí solo percibe ingresos y participa en sus frentes.
##
## `rng` permite determinismo por iteración del MCTS; si es null se crea uno
## local (los tests de F1/F2 que no configuran eventos no disparan nada).
## `process_events`: si false, omite el chance node de evento (optimización para
## el rollout profundo del MCTS — los eventos son caros y el rollout es una
## estimación; el árbol sí los modela en sus transiciones de ronda).
static func advance_turn(state: AIRealState, rng: RandomNumberGenerator = null,
		process_events: bool = true) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()

	# Evento de fin de turno (chance node): se resuelve antes del arranque del
	# siguiente turno, igual que AIController evalúa el evento al final de _run_turn.
	if process_events:
		AIRealEvents.process_turn_event(state, AIRealState.OWNER_SELF, rng)

	# Decrementar la duración de los modifiers y expirar los agotados (espejo de
	# ModifierManager.tick, que corre en process_turn_start).
	_tick_modifiers(state.own)
	_tick_modifiers(state.rival)

	assign_troops_to_fronts(state, AIRealState.OWNER_SELF)
	assign_troops_to_fronts(state, AIRealState.OWNER_RIVAL)

	recompute_economy(state, AIRealState.OWNER_SELF)
	recompute_economy(state, AIRealState.OWNER_RIVAL)
	state.own.gold += state.own.gold_per_turn
	state.rival.gold += state.rival.gold_per_turn

	_tick_all_fronts(state)
	state.turn_number += 1


# ---------------------------------------------------------------------------
# Resolución de frentes (espejo de BattleFront — riesgo #1 del plan, §6.1)
# ---------------------------------------------------------------------------

## Tickea todos los frentes activos y purga los resueltos del estado
## (espejo de BattleFrontManager.tick_all_fronts + erase al resolverse).
static func _tick_all_fronts(state: AIRealState) -> void:
	for f in state.fronts.duplicate():
		var front := f as AIRealState.FrontSnap
		if not front.is_resolved:
			_tick_front(state, front)
	var survivors: Array = []
	for f in state.fronts:
		if not (f as AIRealState.FrontSnap).is_resolved:
			survivors.append(f)
	state.fronts = survivors


## Procesa un turno del frente (espejo de BattleFront.tick): mueve el marcador
## por presión, decrementa la duración de los bonuses y resuelve si procede.
## Devuelve true si el frente se resolvió.
static func _tick_front(state: AIRealState, front: AIRealState.FrontSnap) -> bool:
	if front.is_resolved:
		return false
	front.turns_elapsed += 1
	var atk_pressure := _front_pressure(state, front, &"attacker")
	var def_pressure := _front_pressure(state, front, &"defender")
	front.marker += atk_pressure - def_pressure
	_tick_bonuses(front.attacker_bonuses)
	_tick_bonuses(front.defender_bonuses)
	if _front_can_resolve(front):
		_resolve_front(state, front)
		return true
	return false


## Decrementa la duración de los bonuses temporales y elimina los expirados
## (espejo de BattleFront._tick_bonuses).
static func _tick_bonuses(bonuses: Array) -> void:
	var i := bonuses.size() - 1
	while i >= 0:
		var b := bonuses[i] as TacticBonus
		if b != null and b.duration >= 0:
			b.duration -= 1
			if b.duration <= 0:
				bonuses.remove_at(i)
		i -= 1


## Espejo de BattleFront.can_resolve: duración mínima cumplida + |marker| ≥ umbral.
static func _front_can_resolve(front: AIRealState.FrontSnap) -> bool:
	if front.is_resolved:
		return false
	if front.turns_elapsed < front.min_duration:
		return false
	return absf(front.marker) >= front.current_threshold()


## Presión de un bando (espejo de BattleFront.get_pressure): atk / (1 + def_enemiga).
static func _front_pressure(state: AIRealState, front: AIRealState.FrontSnap,
		side: StringName) -> float:
	var atk: float
	var enemy_def: float
	if side == &"attacker":
		atk = _front_total_attack(state, front, &"attacker")
		enemy_def = _front_total_defense(state, front, &"defender")
	else:
		atk = _front_total_attack(state, front, &"defender")
		enemy_def = _front_total_defense(state, front, &"attacker")
	return atk / (1.0 + enemy_def)


## Ataque total de un bando (espejo de BattleFront.get_total_attack): tropas con
## efectividad por tipo, escaladas por bioma de la tile contraria y combat
## multiplier, más bonuses tácticos. Edificios de ataque: 0 (reservado en el juego).
static func _front_total_attack(state: AIRealState, front: AIRealState.FrontSnap,
		side: StringName) -> float:
	var troops: Array[Troop]
	var enemy_troops: Array[Troop]
	var enemy_tile_id: int
	var bonuses: Array[TacticBonus]
	var owner: int
	if side == &"attacker":
		troops = front.attacker_troops
		enemy_troops = front.defender_troops
		enemy_tile_id = front.defender_tile_id
		bonuses = front.attacker_bonuses
		owner = front.attacker_owner
	else:
		troops = front.defender_troops
		enemy_troops = front.attacker_troops
		enemy_tile_id = front.attacker_tile_id
		bonuses = front.defender_bonuses
		owner = front.defender_owner

	var total := 0.0
	var troops_attack := TroopEffectiveness.get_effective_attack(troops, enemy_troops)
	var combat_mult := _combat_multiplier_of(state, owner)
	var biome_atk_mult := _biome().get_attack_multiplier(_biome_of(state, enemy_tile_id))
	total += troops_attack * biome_atk_mult * combat_mult

	var flat_bonus := 0.0
	var percent_bonus := 0.0
	for bonus in bonuses:
		flat_bonus += bonus.attack
		percent_bonus += bonus.attack_percent
		if bonus.attack_per_troop != 0.0:
			flat_bonus += bonus.attack_per_troop * _count_bonus_targets(troops, bonus)
		if bonus.attack_percent_per_type != 0.0:
			var pct := bonus.attack_percent_per_type / 100.0
			var biome_mod := bonus.attack_biome_modifier
			var affected := _sum_effective_attack_of_targeted(troops, enemy_troops, bonus)
			flat_bonus += affected * pct * biome_mod
	total += flat_bonus
	if percent_bonus != 0.0:
		total *= (1.0 + percent_bonus / 100.0)
	return maxf(total, 0.0)


## Defensa total de un bando (espejo de BattleFront.get_total_defense): edificios
## defensivos de la tile propia + defensa de tropas escalada por bioma propio y
## combat multiplier, más bonuses tácticos.
static func _front_total_defense(state: AIRealState, front: AIRealState.FrontSnap,
		side: StringName) -> float:
	var troops: Array[Troop]
	var own_tile_id: int
	var bonuses: Array[TacticBonus]
	var owner: int
	if side == &"attacker":
		troops = front.attacker_troops
		own_tile_id = front.attacker_tile_id
		bonuses = front.attacker_bonuses
		owner = front.attacker_owner
	else:
		troops = front.defender_troops
		own_tile_id = front.defender_tile_id
		bonuses = front.defender_bonuses
		owner = front.defender_owner

	var total := _building_defense_of(state, own_tile_id)
	var troops_defense := 0.0
	for troop in troops:
		troops_defense += troop.defense
	var combat_mult := _combat_multiplier_of(state, owner)
	var biome_def_mult := _biome().get_defense_multiplier(_biome_of(state, own_tile_id))
	total += troops_defense * biome_def_mult * combat_mult

	var flat_bonus := 0.0
	var percent_bonus := 0.0
	for bonus in bonuses:
		flat_bonus += bonus.defense
		percent_bonus += bonus.defense_percent
		if bonus.defense_per_troop != 0.0:
			flat_bonus += bonus.defense_per_troop * _count_bonus_targets(troops, bonus)
		if bonus.defense_percent_per_type != 0.0:
			var pct := bonus.defense_percent_per_type / 100.0
			var biome_mod := bonus.defense_biome_modifier
			var affected := _sum_defense_of_targeted(troops, bonus)
			flat_bonus += affected * pct * biome_mod
	total += flat_bonus
	if percent_bonus != 0.0:
		total *= (1.0 + percent_bonus / 100.0)
	return maxf(total, 0.0)


## Resuelve un frente (espejo de BattleFront._resolve + BattleFrontManager
## ._on_front_resolved): determina ganador, conquista la tile del perdedor,
## calcula bajas y devuelve los supervivientes al pool de cada imperio.
static func _resolve_front(state: AIRealState, front: AIRealState.FrontSnap) -> void:
	front.is_resolved = true
	var attacker_won := front.marker >= front.current_threshold()
	var casualties := _calculate_casualties(state, front)

	if attacker_won:
		_apply_conquest(state, front.defender_tile_id, front.attacker_owner)
	else:
		_apply_conquest(state, front.attacker_tile_id, front.defender_owner)

	_return_surviving_troops(state, front, casualties)


## Espejo de BattleFront.calculate_casualties: ratio de bajas según dominancia
## del marcador sobre el umbral efectivo.
static func _calculate_casualties(state: AIRealState,
		front: AIRealState.FrontSnap) -> Dictionary:
	var effective_threshold := front.current_threshold()
	var attacker_won := front.marker >= effective_threshold
	var atk_total := float(front.attacker_troops.size())
	var def_total := float(front.defender_troops.size())
	if atk_total == 0.0 and def_total == 0.0:
		return {"attacker_losses": 0, "defender_losses": 0}
	var atk_pressure := _front_pressure(state, front, &"attacker")
	var def_pressure := _front_pressure(state, front, &"defender")
	if atk_pressure + def_pressure == 0.0:
		return {"attacker_losses": 0, "defender_losses": 0}

	var dominance := absf(front.marker) / effective_threshold
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


## Aplica la conquista de una casilla (espejo de BattleFrontManager._apply_conquest):
## demuele el último edificio (placeholder del juego) y cambia el propietario.
## Las casillas colonizadas conservan su location/edificios restantes al conquistarse.
static func _apply_conquest(state: AIRealState, tile_id: int, winner_owner: int) -> void:
	if not state.tiles.has(tile_id):
		return
	var t := _writable(state, tile_id)   # COW antes de mutar
	if not t.buildings.is_empty():
		t.buildings.pop_back()
	t.owner = winner_owner


## Devuelve las tropas supervivientes al pool de cada imperio (espejo de
## BattleFrontManager._return_surviving_troops: elimina las bajas desde el final).
static func _return_surviving_troops(state: AIRealState,
		front: AIRealState.FrontSnap, casualties: Dictionary) -> void:
	var atk_losses: int = casualties["attacker_losses"]
	var def_losses: int = casualties["defender_losses"]

	var atk_survivors := front.attacker_troops.duplicate()
	for _i in range(mini(atk_losses, atk_survivors.size())):
		atk_survivors.pop_back()
	var def_survivors := front.defender_troops.duplicate()
	for _i in range(mini(def_losses, def_survivors.size())):
		def_survivors.pop_back()

	var atk_emp := _empire_of(state, front.attacker_owner)
	if atk_emp != null:
		atk_emp.troop_pool.append_array(atk_survivors)
	var def_emp := _empire_of(state, front.defender_owner)
	if def_emp != null:
		def_emp.troop_pool.append_array(def_survivors)


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

static func _empire_of(state: AIRealState, p_owner: int) -> AIRealState.EmpireSnap:
	if p_owner == AIRealState.OWNER_SELF:
		return state.own
	if p_owner == AIRealState.OWNER_RIVAL:
		return state.rival
	return null


## Copy-on-write: devuelve una copia PRIVADA de la casilla en este estado, lista
## para mutar sin afectar a los clones que comparten el TileSnap (ver
## AIRealState.clone). Toda mutación de tile debe pasar por aquí.
static func _writable(state: AIRealState, tile_id: int) -> AIRealState.TileSnap:
	var t := (state.tiles[tile_id] as AIRealState.TileSnap).clone()
	state.tiles[tile_id] = t
	return t


## combat_multiplier del imperio dueño de un bando (1.0 si no hay imperio).
static func _combat_multiplier_of(state: AIRealState, p_owner: int) -> float:
	var emp := _empire_of(state, p_owner)
	return emp.combat_multiplier if emp != null else 1.0


## Bioma de una casilla (Grassland=0 por defecto si no existe).
static func _biome_of(state: AIRealState, tile_id: int) -> int:
	var t := state.tiles.get(tile_id) as AIRealState.TileSnap
	return t.biome if t != null else 0


## Suma del flat_defense_bonus de los edificios de una casilla.
static func _building_defense_of(state: AIRealState, tile_id: int) -> float:
	var t := state.tiles.get(tile_id) as AIRealState.TileSnap
	if t == null:
		return 0.0
	var total := 0.0
	for b in t.buildings:
		total += float(b.flat_defense_bonus)
	return total


## Instancia compartida de BiomeConfig (multiplicadores inmutables). Lazy.
static var _biome_config: BiomeConfig = null
static func _biome() -> BiomeConfig:
	if _biome_config == null:
		_biome_config = BiomeConfig.new()
	return _biome_config


## Cuenta cuántas tropas del bando son objetivo de un bonus (espejo de
## BattleFront._count_bonus_targets: troop_types > troop_type > troop_name).
static func _count_bonus_targets(troops: Array[Troop], bonus: TacticBonus) -> int:
	if not bonus.troop_types.is_empty():
		var count := 0
		for troop in troops:
			if troop.type in bonus.troop_types:
				count += 1
		return count
	if bonus.troop_type >= 0:
		var count := 0
		for troop in troops:
			if troop.type == bonus.troop_type:
				count += 1
		return count
	if bonus.troop_name != "":
		var count := 0
		for troop in troops:
			if troop.name == bonus.troop_name:
				count += 1
		return count
	return 0


static func _is_troop_targeted_by_bonus(troop: Troop, bonus: TacticBonus) -> bool:
	if not bonus.troop_types.is_empty():
		return troop.type in bonus.troop_types
	if bonus.troop_type >= 0:
		return troop.type == bonus.troop_type
	if bonus.troop_name != "":
		return troop.name == bonus.troop_name
	return false


static func _sum_effective_attack_of_targeted(troops: Array[Troop],
		enemy_troops: Array[Troop], bonus: TacticBonus) -> float:
	var total := 0.0
	for troop in troops:
		if _is_troop_targeted_by_bonus(troop, bonus):
			total += TroopEffectiveness.get_effective_attack_for_troop(troop, enemy_troops)
	return total


static func _sum_defense_of_targeted(troops: Array[Troop], bonus: TacticBonus) -> float:
	var total := 0.0
	for troop in troops:
		if _is_troop_targeted_by_bonus(troop, bonus):
			total += float(troop.defense)
	return total


## Elimina las tácticas activas (bonus con tactic_name no vacío) de un bando
## (espejo de BattleFront.clear_tactics_for_side).
static func _clear_tactics_for_side(front: AIRealState.FrontSnap, side: StringName) -> void:
	var bonuses: Array[TacticBonus] = front.attacker_bonuses if side == &"attacker" \
		else front.defender_bonuses
	var i := bonuses.size() - 1
	while i >= 0:
		if bonuses[i].tactic_name != "":
			bonuses.remove_at(i)
		i -= 1


## Modificador de bioma de una carta táctica para una casilla (espejo de
## TacticCard.get_biome_modifier_for_tile: neutro si no listado, clamp a 0).
static func _tactic_biome_modifier(state: AIRealState, card: TacticCard,
		tile_id: int) -> float:
	if tile_id < 0:
		return 1.0
	var t := state.tiles.get(tile_id) as AIRealState.TileSnap
	if t == null:
		return 1.0
	if not card.biome_modifiers.has(t.biome):
		return 1.0
	return maxf(0.0, float(card.biome_modifiers[t.biome]))


## Número de frentes que `p_owner` tiene ABIERTOS como atacante (espejo de
## BattleFrontManager.active_fronts, que solo registra los frentes propios).
static func _active_front_count(state: AIRealState, p_owner: int) -> int:
	var n := 0
	for f in state.fronts:
		var front := f as AIRealState.FrontSnap
		if not front.is_resolved and front.attacker_owner == p_owner:
			n += 1
	return n


## Máximo de frentes simultáneos (espejo de BattleFrontManager.get_max_fronts:
## base 1 + tiles/5 + extra 0).
static func _get_max_fronts(state: AIRealState, p_owner: int) -> int:
	return 1 + int(state.count_tiles(p_owner) / 5)


## True si la casilla participa en algún frente activo (regla global, espejo de
## BattleFront.is_tile_in_active_front).
static func _tile_in_active_front(state: AIRealState, tile_id: int) -> bool:
	for f in state.fronts:
		var front := f as AIRealState.FrontSnap
		if front.is_resolved:
			continue
		if front.attacker_tile_id == tile_id or front.defender_tile_id == tile_id:
			return true
	return false


## Urgencia base de un frente para un bando (espejo de
## AIController._front_base_urgency).
static func _front_base_urgency(front: AIRealState.FrontSnap, side: StringName) -> float:
	var ai_marker := front.marker if side == &"attacker" else -front.marker
	var thr := front.current_threshold()
	if ai_marker < -thr * 0.5: return 3.0
	if ai_marker < 0.0:         return 2.0
	if ai_marker < thr * 0.4:   return 1.5
	if ai_marker < thr * 0.7:   return 0.8
	return 0.3


## Elige la mejor tropa del pool para el rol y la asigna al frente (espejo de
## AIController._assign_best_troop: defensor → max defensa; atacante → max ataque).
static func _assign_best_troop(emp: AIRealState.EmpireSnap,
		front: AIRealState.FrontSnap, side: StringName) -> bool:
	if emp.troop_pool.is_empty():
		return false
	var sorted_pool := emp.troop_pool.duplicate()
	if side == &"defender":
		sorted_pool.sort_custom(func(a: Troop, b: Troop) -> bool: return a.defense > b.defense)
	else:
		sorted_pool.sort_custom(func(a: Troop, b: Troop) -> bool: return a.attack > b.attack)
	var best: Troop = sorted_pool[0]
	var idx := emp.troop_pool.find(best)
	if idx < 0:
		return false
	emp.troop_pool.remove_at(idx)
	if side == &"attacker":
		front.attacker_troops.append(best)
	else:
		front.defender_troops.append(best)
	return true


## Recurso real de la localización Village (mismo que usa TilesTracker al
## colonizar). Preargarlo garantiza paridad de max_building/food_consumption
## sin hardcodear valores que podrían divergir del juego.
const VILLAGE: LocationType = preload("uid://dg0go8h0lbyaw")


## Aplica los parámetros de Village a una casilla recién colonizada, leyendo el
## recurso real (espejo de TilesTracker._on_change_tile_controller, que urbaniza
## a Village toda casilla Uncolonized recién adquirida).
static func _set_village(t: AIRealState.TileSnap) -> void:
	t.location_type = VILLAGE.type
	t.max_buildings = VILLAGE.max_building
	t.food_consumption = VILLAGE.food_consumption


## True si un edificio sobrevive a un cambio de localización a `new_loc_type`
## (espejo de ChangeLocationTypeEffect: sobrevive si no tiene restricción de
## location o si su lista la incluye, comparando por valor de enum).
static func _building_survives(building: Building, new_loc_type: int) -> bool:
	if building.allowed_location_type.is_empty():
		return true
	for allowed in building.allowed_location_type:
		if allowed.type == new_loc_type:
			return true
	return false


# ---------------------------------------------------------------------------
# Consultas de modificadores (F2.5a — espejo de ModifierManager)
# ---------------------------------------------------------------------------

## Coste de construcción efectivo de un edificio para un imperio, aplicando el
## multiplicador de BuildCostModifier (espejo de Building.get_effective_construction_cost).
static func _effective_build_cost(building: Building, emp: AIRealState.EmpireSnap) -> int:
	return int(building.construction_cost * _build_cost_multiplier(emp.modifiers))


## Decrementa la duración de los modifiers y elimina los expirados (espejo de
## ModifierManager.tick: los permanentes tienen duration <= 0 y no expiran).
static func _tick_modifiers(emp: AIRealState.EmpireSnap) -> void:
	var i := emp.modifiers.size() - 1
	while i >= 0:
		var mod := emp.modifiers[i]
		if mod.duration > 0:
			mod.duration -= 1
			if mod.duration == 0:
				emp.modifiers.remove_at(i)
		i -= 1


static func _flat_gold(mods: Array[Modifier]) -> int:
	var total := 0
	for mod in mods:
		if mod is StatModifier and mod.type == StatModifier.StatType.FLAT_GOLD:
			total += int(mod.value)
	return total


static func _flat_food(mods: Array[Modifier]) -> int:
	var total := 0
	for mod in mods:
		if mod is StatModifier and mod.type == StatModifier.StatType.FLAT_FOOD:
			total += int(mod.value)
	return total


static func _percent_gold(mods: Array[Modifier]) -> float:
	var total := 0.0
	for mod in mods:
		if mod is StatModifier and mod.type == StatModifier.StatType.PERCENT_GOLD:
			total += mod.value
	return total


static func _percent_food(mods: Array[Modifier]) -> float:
	var total := 0.0
	for mod in mods:
		if mod is StatModifier and mod.type == StatModifier.StatType.PERCENT_FOOD:
			total += mod.value
	return total


## Bonus de oro por recurso natural de una casilla (espejo de
## ModifierManager.get_tile_gold_bonus: TILE_RESOURCE_GOLD con target_resource
## igual al recurso de la casilla).
static func _tile_gold_bonus(mods: Array[Modifier], t: AIRealState.TileSnap) -> int:
	var total := 0
	for mod in mods:
		if mod is StatModifier and mod.type == StatModifier.StatType.TILE_RESOURCE_GOLD:
			if t.natural_resource == mod.target_resource:
				total += int(mod.value)
	return total


static func _tile_food_bonus(mods: Array[Modifier], t: AIRealState.TileSnap) -> int:
	var total := 0
	for mod in mods:
		if mod is StatModifier and mod.type == StatModifier.StatType.TILE_RESOURCE_FOOD:
			if t.natural_resource == mod.target_resource:
				total += int(mod.value)
	return total


## Descuento porcentual de mantenimiento aplicable a una tropa (espejo de
## ModifierManager.get_troop_maintenance_percent: respeta el troop_type_filter).
static func _troop_maintenance_percent(mods: Array[Modifier], troop: Troop) -> float:
	var total := 0.0
	for mod in mods:
		if mod is StatModifier and mod.type == StatModifier.StatType.TROOP_MAINTENANCE_PERCENT:
			if mod.applies_to_troop(troop):
				total += mod.value
	return total


## Multiplicador de coste de construcción (espejo de
## ModifierManager.get_build_cost_multiplier: 1 − Σ% descuento, clampeado).
static func _build_cost_multiplier(mods: Array[Modifier]) -> float:
	var total_percent := 0.0
	for mod in mods:
		if mod is BuildCostModifier:
			total_percent += mod.percent
	return ModifierManager.clamp_cost_multiplier(1.0 - total_percent / 100.0)


## Bonus de cartas por turno de los modifiers (espejo de
## ModifierManager.get_cards_per_turn_bonus). Lo usará la fase de robo en F3.
static func _cards_per_turn_bonus(mods: Array[Modifier]) -> int:
	var total := 0
	for mod in mods:
		if mod is StatModifier and mod.type == StatModifier.StatType.CARDS_PER_TURN:
			total += int(mod.value)
	return total
