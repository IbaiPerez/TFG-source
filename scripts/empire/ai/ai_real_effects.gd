extends RefCounted
class_name AIRealEffects

## Efectos de carta sobre el snapshot (AIRealState), como funciones PURAS.
##
## Reimplementan lo que en el juego vive acoplado a escena y señales
## (ColonizeEffect, Tile.build, Tile.upgrade, ChangeLocationTypeEffect…). Cada
## función muta el estado que recibe IN-PLACE; el llamante (árbol MCTS) clona
## antes si quiere conservar el original.
##
## Toda mutación de casilla pasa por `_writable` (copy-on-write): los clones de
## AIRealState comparten los TileSnap, así que escribir sin copiar corrompería
## las ramas hermanas del árbol.

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
	AIRealSimulator.recompute_economy(state, p_owner)


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
	AIRealSimulator.recompute_economy(state, p_owner)


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
	AIRealSimulator.recompute_economy(state, p_owner)


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
	AIRealSimulator.recompute_economy(state, p_owner)


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
	AIRealSimulator.recompute_economy(state, p_owner)


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



# --- Internals de los efectos ---------------------------------------------

## Copy-on-write: devuelve una copia PRIVADA de la casilla en este estado, lista
## para mutar sin afectar a los clones que comparten el TileSnap (ver
## AIRealState.clone). Toda mutación de tile debe pasar por aquí.
static func _writable(state: AIRealState, tile_id: int) -> AIRealState.TileSnap:
	var t := (state.tiles[tile_id] as AIRealState.TileSnap).clone()
	state.tiles[tile_id] = t
	return t


## Elimina las tácticas activas (bonus con tactic_name no vacío) de un bando
## (espejo de BattleFront.clear_tactics_for_side).
static func _clear_tactics_for_side(front: AIRealState.FrontSnap, side: BattleFront.Side) -> void:
	var bonuses: Array[TacticBonus] = front.attacker_bonuses if side == BattleFront.Side.ATTACKER \
		else front.defender_bonuses
	CombatMath.clear_tactics(bonuses)


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


## Coste de construcción efectivo de un edificio para un imperio, aplicando el
## multiplicador de BuildCostModifier (espejo de Building.get_effective_construction_cost).
static func _effective_build_cost(building: Building, emp: AIRealState.EmpireSnap) -> int:
	return int(building.construction_cost * ModifierQuery.build_cost_multiplier(emp.modifiers))
