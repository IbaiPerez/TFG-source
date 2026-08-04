extends RefCounted
class_name AIRealSimulator

## Motor de simulación headless sobre AIRealState.
##
## Reimplementa, como funciones PURAS, los efectos reales de las cartas que en
## el juego viven acoplados a escena/señales (ColonizeEffect, Tile.build,
## Tile.upgrade, ChangeLocationTypeEffect…). Cada función muta el estado que
## recibe IN-PLACE; el llamante (árbol MCTS) clona antes si quiere conservar el
## original.
##
## Principio de paridad: tras aplicar una secuencia de efectos y un
## advance_turn, la economía resultante (gpt, food, total_gold) debe coincidir
## con la del juego real tras las mismas jugadas + _process_turn_start. Por eso
## la economía NO se acumula a mano efecto a efecto, sino que se RECALCULA desde
## las casillas (espejo de ProductionCalculator), igual que hace el juego al
## inicio de cada turno.
##
## ALCANCE actual: efectos de carta (colonize / build / direct_build / upgrade /
## change_location / generate_gold / recruit / open_front / tactic) y advance_turn
## completo — ingresos, modificadores y habilidad de imperio, mantenimiento y
## recargo de tropas, asignación a frentes, tick de combate y evento de fin de turno.


# ---------------------------------------------------------------------------
# Recálculo de economía (espejo de ProductionCalculator)
# ---------------------------------------------------------------------------

## Recalcula gold_per_turn, food y combat_multiplier de un imperio (espejo
## completo de ProductionCalculator + EmpireController._update_combat_multiplier,
## incluidos modificadores y habilidad de imperio):
##   1. base = Σ (producción de casilla + bonus de modifier por recurso) + flat
##   2. percent (solo sobre la parte positiva)
##   3. − mantenimiento base de tropas del pool (con descuento % clampeado)
##   4. − recargo progresivo de frentes (sin descuento)
##   5. combat_multiplier = clamp(1 − déficit/mantenimiento_total, 0.1, 1.0)
## Los modifiers del rival no se modelan (ocultos); para él Σmodifiers = ∅, que
## reproduce el comportamiento base de F2.
static func recompute_economy(state: AIRealState, p_owner: int) -> void:
	var emp := state.empire(p_owner)
	if emp == null:
		return
	var mods := emp.modifiers

	# 1. Producción base de las casillas + bonus de recurso por modifier + flat.
	var base_gold := 0
	var base_food := 0
	for id in state.tiles:
		var t := state.tiles[id] as AIRealState.TileSnap
		if t.owner == p_owner:
			base_gold += t.gold_production() + ModifierQuery.tile_gold_bonus(mods, t.natural_resource)
			base_food += t.food_production() + ModifierQuery.tile_food_bonus(mods, t.natural_resource)
	base_gold += ModifierQuery.flat_gold(mods)
	base_food += ModifierQuery.flat_food(mods)

	# 2. Modificadores porcentuales: solo sobre la producción positiva (misma
	#    aritmética que ProductionCalculator, vía ProductionMath).
	var prod_gold := ProductionMath.apply_percent(base_gold, ModifierQuery.percent_gold(mods))
	var prod_food := ProductionMath.apply_percent(base_food, ModifierQuery.percent_food(mods))

	# 3. Mantenimiento base de las tropas del pool, con descuento porcentual
	#    clampeado (misma aritmética que ProductionCalculator, vía ProductionMath).
	var maint_gold := 0
	var maint_food := 0
	for troop in emp.troop_pool:
		var percent := ModifierQuery.troop_maintenance_percent(mods, troop)
		var multiplier := ProductionMath.maintenance_multiplier(percent)
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
		if side == BattleFront.Side.NONE:
			continue
		var troops := front.attacker_troops if side == BattleFront.Side.ATTACKER else front.defender_troops
		for i in range(troops.size()):
			var sc := (i + 1) * GameBalance.FRONT_SURCHARGE_PER_TROOP
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
	var emp := state.empire(p_owner)
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
	var emp := state.empire(p_owner)
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
	var emp := state.empire(p_owner)
	if emp != null:
		emp.gold += amount


# ---------------------------------------------------------------------------
# Efectos militares
# ---------------------------------------------------------------------------

## Recruit: añade `count` tropas del tipo `troop` al pool, descontando
## `recruitment_cost_gold` por tropa (espejo de Stats.recruit_troop, que se
## detiene si el oro no alcanza). El llamante calcula `count` con
## RecruitCard.get_effective_troops_per_play; sin modifiers es 1.
static func apply_recruit(state: AIRealState, troop: Troop, count: int = 1,
		p_owner: int = AIRealState.OWNER_SELF) -> void:
	var emp := state.empire(p_owner)
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
	if side == BattleFront.Side.NONE:
		return

	# Biomas relevantes: ATK mira la tile contraria, DEF la propia.
	var own_tile_id := front.attacker_tile_id if side == BattleFront.Side.ATTACKER else front.defender_tile_id
	var enemy_tile_id := front.defender_tile_id if side == BattleFront.Side.ATTACKER else front.attacker_tile_id
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
	if side == BattleFront.Side.ATTACKER:
		front.attacker_bonuses.append(bonus)
	else:
		front.defender_bonuses.append(bonus)


# ---------------------------------------------------------------------------
# Asignación de tropas a frentes (espejo de AIController._assign_troops_to_fronts)
# ---------------------------------------------------------------------------

## Reparte las tropas del pool de `p_owner` entre sus frentes usando la política
## compartida TroopAssignmentPolicy (misma urgencia y dos pasadas que el juego
## real); aquí solo construimos los slots sobre los FrontSnap del estado.
static func assign_troops_to_fronts(state: AIRealState,
		p_owner: int = AIRealState.OWNER_SELF) -> void:
	var emp := state.empire(p_owner)
	if emp == null or emp.troop_pool.is_empty():
		return

	var slots: Array = []
	for f in state.fronts:
		var front := f as AIRealState.FrontSnap
		if front.is_resolved:
			continue
		var side := front.side_of(p_owner)
		if side == BattleFront.Side.NONE:
			continue
		var own_marker := front.marker if side == BattleFront.Side.ATTACKER else -front.marker
		var slot := _SnapFrontSlot.new(emp, front, side)
		slot.base_urgency = TroopAssignmentPolicy.base_urgency(
			own_marker, front.current_threshold())
		slots.append(slot)

	TroopAssignmentPolicy.assign(slots)


## Slot de asignación sobre un FrontSnap (ver TroopAssignmentPolicy). Extrae la
## mejor tropa del pool del EmpireSnap y la añade al bando correspondiente.
class _SnapFrontSlot extends RefCounted:
	var emp: AIRealState.EmpireSnap
	var front: AIRealState.FrontSnap
	var side: BattleFront.Side
	var base_urgency: float = 0.0

	func _init(p_emp: AIRealState.EmpireSnap, p_front: AIRealState.FrontSnap,
			p_side: BattleFront.Side) -> void:
		emp = p_emp
		front = p_front
		side = p_side

	func troop_count() -> int:
		var troops := front.attacker_troops if side == BattleFront.Side.ATTACKER \
			else front.defender_troops
		return troops.size()

	func assign_best() -> bool:
		if emp.troop_pool.is_empty():
			return false
		var sorted_pool := emp.troop_pool.duplicate()
		if side == BattleFront.Side.DEFENDER:
			sorted_pool.sort_custom(func(a: Troop, b: Troop) -> bool: return a.defense > b.defense)
		else:
			sorted_pool.sort_custom(func(a: Troop, b: Troop) -> bool: return a.attack > b.attack)
		var best: Troop = sorted_pool[0]
		var idx := emp.troop_pool.find(best)
		if idx < 0:
			return false
		emp.troop_pool.remove_at(idx)
		if side == BattleFront.Side.ATTACKER:
			front.attacker_troops.append(best)
		else:
			front.defender_troops.append(best)
		return true


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
## Incluye el chance node de eventos de fin de turno (propio). El rival no juega
## aquí su mano determinizada ni sus eventos (su información es oculta): solo
## percibe ingresos y participa en sus frentes.
##
## `rng` permite determinismo por iteración del MCTS; si es null se crea uno
## local (los tests de F1/F2 que no configuran eventos no disparan nada).
## `process_events`: si false, omite el chance node de evento (optimización para
## el rollout profundo del MCTS — los eventos son caros y el rollout es una
## estimación; el árbol sí los modela en sus transiciones de ronda).
static func advance_turn(state: AIRealState, rng: RandomNumberGenerator = null,
		process_events: bool = true, w: HeuristicWeights = null) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()

	# Evento de fin de turno (chance node): se resuelve antes del arranque del
	# siguiente turno, igual que AIController evalúa el evento al final de _run_turn.
	# `w` alimenta el valorador de carta de la tienda.
	if process_events:
		AIRealEvents.process_turn_event(state, AIRealState.OWNER_SELF, rng, w)

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
# Resolución de frentes (espejo de BattleFront)
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
	var atk_pressure := _front_pressure(state, front, BattleFront.Side.ATTACKER)
	var def_pressure := _front_pressure(state, front, BattleFront.Side.DEFENDER)
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


## Presión de un bando (delega en CombatMath.pressure).
static func _front_pressure(state: AIRealState, front: AIRealState.FrontSnap,
		side: BattleFront.Side) -> float:
	var atk: float
	var enemy_def: float
	if side == BattleFront.Side.ATTACKER:
		atk = _front_total_attack(state, front, BattleFront.Side.ATTACKER)
		enemy_def = _front_total_defense(state, front, BattleFront.Side.DEFENDER)
	else:
		atk = _front_total_attack(state, front, BattleFront.Side.DEFENDER)
		enemy_def = _front_total_defense(state, front, BattleFront.Side.ATTACKER)
	return CombatMath.pressure(atk, enemy_def)


## Ataque total de un bando: resuelve bioma/combat_mult desde el snapshot y delega
## el cálculo en CombatMath (mismo motor que el juego real). Edificios de ataque: 0.
static func _front_total_attack(state: AIRealState, front: AIRealState.FrontSnap,
		side: BattleFront.Side) -> float:
	var troops: Array[Troop]
	var enemy_troops: Array[Troop]
	var enemy_tile_id: int
	var bonuses: Array[TacticBonus]
	var owner: int
	if side == BattleFront.Side.ATTACKER:
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

	return CombatMath.total_attack(troops, enemy_troops, bonuses,
		_biome().get_attack_multiplier(_biome_of(state, enemy_tile_id)),
		_combat_multiplier_of(state, owner))


## Defensa total de un bando: resuelve edificios/bioma/combat_mult desde el
## snapshot y delega el cálculo en CombatMath.
static func _front_total_defense(state: AIRealState, front: AIRealState.FrontSnap,
		side: BattleFront.Side) -> float:
	var troops: Array[Troop]
	var own_tile_id: int
	var bonuses: Array[TacticBonus]
	var owner: int
	if side == BattleFront.Side.ATTACKER:
		troops = front.attacker_troops
		own_tile_id = front.attacker_tile_id
		bonuses = front.attacker_bonuses
		owner = front.attacker_owner
	else:
		troops = front.defender_troops
		own_tile_id = front.defender_tile_id
		bonuses = front.defender_bonuses
		owner = front.defender_owner

	return CombatMath.total_defense(troops, bonuses,
		_biome().get_defense_multiplier(_biome_of(state, own_tile_id)),
		_combat_multiplier_of(state, owner),
		_building_defense_of(state, own_tile_id))


## Resuelve un frente (espejo de BattleFront._resolve +
## BattleFrontManager._on_front_resolved): determina ganador, conquista la tile
## del perdedor,
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


## Bajas al resolver el frente: computa las presiones desde el snapshot y delega
## en CombatMath.casualties (mismo motor que el juego real).
static func _calculate_casualties(state: AIRealState,
		front: AIRealState.FrontSnap) -> Dictionary:
	var effective_threshold := front.current_threshold()
	var atk_pressure := _front_pressure(state, front, BattleFront.Side.ATTACKER)
	var def_pressure := _front_pressure(state, front, BattleFront.Side.DEFENDER)
	return CombatMath.casualties(front.marker, effective_threshold,
		front.attacker_troops.size(), front.defender_troops.size(),
		atk_pressure, def_pressure)


## Aplica la conquista de una casilla (espejo de BattleFrontManager._apply_conquest):
## demuele el último edificio (placeholder del juego) y cambia el propietario.
## Las casillas colonizadas conservan su location/edificios restantes al conquistarse.
static func _apply_conquest(state: AIRealState, tile_id: int, winner_owner: int) -> void:
	if not state.tiles.has(tile_id):
		return
	var t := _writable(state, tile_id)   # COW antes de mutar
	# Misma regla que el juego: la comparte ConquestResolver, así que lo que
	# el MCTS predice al conquistar es lo que ocurrirá de verdad.
	for b in ConquestResolver.buildings_to_destroy(t.buildings):
		t.buildings.erase(b)
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

	var atk_emp := state.empire(front.attacker_owner)
	if atk_emp != null:
		atk_emp.troop_pool.append_array(atk_survivors)
	var def_emp := state.empire(front.defender_owner)
	if def_emp != null:
		def_emp.troop_pool.append_array(def_survivors)


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## Copy-on-write: devuelve una copia PRIVADA de la casilla en este estado, lista
## para mutar sin afectar a los clones que comparten el TileSnap (ver
## AIRealState.clone). Toda mutación de tile debe pasar por aquí.
static func _writable(state: AIRealState, tile_id: int) -> AIRealState.TileSnap:
	var t := (state.tiles[tile_id] as AIRealState.TileSnap).clone()
	state.tiles[tile_id] = t
	return t


## combat_multiplier del imperio dueño de un bando (1.0 si no hay imperio).
static func _combat_multiplier_of(state: AIRealState, p_owner: int) -> float:
	var emp := state.empire(p_owner)
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


## Instancia compartida de BiomeConfig (multiplicadores inmutables).
static func _biome() -> BiomeConfig:
	return BiomeConfig.shared()


## Elimina las tácticas activas (bonus con tactic_name no vacío) de un bando
## (espejo de BattleFront.clear_tactics_for_side).
static func _clear_tactics_for_side(front: AIRealState.FrontSnap, side: BattleFront.Side) -> void:
	var bonuses: Array[TacticBonus] = front.attacker_bonuses if side == BattleFront.Side.ATTACKER \
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
	return GameBalance.MAX_FRONTS_BASE \
		+ int(state.count_tiles(p_owner) / GameBalance.TILES_PER_EXTRA_FRONT)


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
# Consultas de modificadores
# ---------------------------------------------------------------------------
# La agregación de modifiers vive en ModifierQuery (compartida con el juego real
# vía ModifierManager). Aquí solo quedan el coste de construcción efectivo y el
# tick de duración, específicos del snapshot.

## Coste de construcción efectivo de un edificio para un imperio, aplicando el
## multiplicador de BuildCostModifier (espejo de Building.get_effective_construction_cost).
static func _effective_build_cost(building: Building, emp: AIRealState.EmpireSnap) -> int:
	return int(building.construction_cost * ModifierQuery.build_cost_multiplier(emp.modifiers))


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
