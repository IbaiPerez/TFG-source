extends RefCounted
class_name AISnapshotFacts

## Recorridos sobre el SNAPSHOT (AIRealState) que alimentan la heurística:
## cuántas casillas libres hay alrededor, cuánto abre una casilla la frontera,
## qué tipos de tropa rivales se ven en los frentes, cuánta presión aguanta el
## frente más comprometido…
##
## Es el gemelo de AILiveFacts, que hace lo mismo sobre el mundo vivo. Los dos
## responden a las mismas preguntas de AIStateView; lo que cambia es CÓMO se lee
## cada mundo, que es justo la mitad que no se puede compartir. Las fórmulas que
## consumen estos datos viven en scoring/ (AITerritory, AIEconomy, AIMilitary,
## AIUrgency), escritas una sola vez para ambos.
##
## Camino CALIENTE: se consulta por cada jugada legal en cada expansión y
## rollout del MCTS, así que cualquier coste añadido aquí se multiplica por
## miles en cada decisión.


const OWNER_SELF := AIRealState.OWNER_SELF
const OWNER_RIVAL := AIRealState.OWNER_RIVAL
const OWNER_NONE := AIRealState.OWNER_NONE


# ---------------------------------------------------------------------------
# Territorio
# ---------------------------------------------------------------------------

## Backend de `AIStateView.frontier_value`: tiles libres que colonizar `tile_id`
## haría accesibles por primera vez (no alcanzables ya desde el territorio).
static func _frontier_value(state: AIRealState, tile_id: int, p_owner: int) -> int:
	var t := state.tiles.get(tile_id) as AIRealState.TileSnap
	if t == null:
		return 0
	var count := 0
	for nid in t.neighbor_ids:
		var nt := state.tiles.get(nid) as AIRealState.TileSnap
		if nt == null or nt.owner != OWNER_NONE:
			continue
		var already_reachable := false
		for nnid in nt.neighbor_ids:
			if nnid == tile_id:
				continue
			var nnt := state.tiles.get(nnid) as AIRealState.TileSnap
			if nnt != null and nnt.owner == p_owner:
				already_reachable = true
				break
		if not already_reachable:
			count += 1
	return count


## Backend de `AIStateView.encirclement_pressure`: ratio colonizables/controladas.
## Ratio bajo → la IA se está quedando rodeada → escalar el incentivo de escapar.
static func _encirclement_pressure(state: AIRealState, p_owner: int,
		w: HeuristicWeights) -> float:
	return AITerritory.encirclement_pressure(
		_colonizable_count(state, p_owner), maxi(state.count_tiles(p_owner), 1), w)


## Backend de `AIStateView.expansion_factor`: presión expansionista [0.0, 1.0] por
## número de tiles colonizables adyacentes (REFERENCE = 15 → presión máxima).
static func _expansion_factor(state: AIRealState, p_owner: int,
		w: HeuristicWeights) -> float:
	return AITerritory.expansion_factor(_colonizable_count(state, p_owner), w)


## Backend de `AIStateView.territory_race_factor`: amplifica jugadas que acercan a
## la dominación (o bloquean al rival cerca de su límite de victoria).
static func _territory_race_factor(state: AIRealState, p_owner: int,
		mode: StringName = &"colonize", w: HeuristicWeights = null) -> float:
	if w == null: w = HeuristicWeights.get_default()
	var rival := OWNER_RIVAL if p_owner == OWNER_SELF else OWNER_SELF
	# Cuota sobre el MAPA, no sobre las casillas en disputa: ver AITerritory.
	return AITerritory.territory_race_factor(state.count_tiles(p_owner),
		state.count_tiles(rival), state.total_map_tiles, mode, w)


## Backend de `AIStateView.colonizable_count`: tiles sin colonizar adyacentes al
## territorio de `p_owner`. Debe contar lo mismo que AdjacentRule.valid_targets en
## el mundo vivo, que es de donde sale el colonizable_tiles_count de AIController.
static func _colonizable_count(state: AIRealState, p_owner: int) -> int:
	var seen := {}
	for id in state.tiles:
		var t := state.tiles[id] as AIRealState.TileSnap
		if t.owner != p_owner:
			continue
		for nid in t.neighbor_ids:
			if seen.has(nid):
				continue
			var nb := state.tiles.get(nid) as AIRealState.TileSnap
			if nb != null and nb.owner == OWNER_NONE:
				seen[nid] = true
	return seen.size()



# ---------------------------------------------------------------------------
# Militar y economía
# ---------------------------------------------------------------------------

## Backend de `AIStateView.complement_bonus`: balance atk/def del pool + counter-bonus
## si la tropa es fuerte contra algún tipo visible del rival en los frentes. Lo propio
## del snapshot es el recorrido que recolecta esos tipos rivales; el cálculo lo hace
## AIMilitary.
static func _complement_bonus(troop: Troop, pool: Array[Troop], state: AIRealState,
		p_owner: int, w: HeuristicWeights) -> float:
	# Tipos de tropa del rival visibles en frentes activos.
	var enemy := OWNER_RIVAL if p_owner == OWNER_SELF else OWNER_SELF
	var rival_types: Array[int] = []
	for f in state.fronts:
		var front := f as AIRealState.FrontSnap
		if front.is_resolved:
			continue
		var eside := front.side_of(enemy)
		if eside == BattleFront.Side.NONE:
			continue
		var rtroops := front.attacker_troops if eside == BattleFront.Side.ATTACKER else front.defender_troops
		for t in rtroops:
			if t.type not in rival_types:
				rival_types.append(t.type)
	return AIMilitary.complement_bonus(troop, pool, w) \
		* AIMilitary.counter_bonus(troop.type, rival_types, w)


## Backend de `AIStateView.resource_surplus_factor`: [1.0, 3.0]; potencia lo militar
## cuando el oro/comida están muy por encima del umbral cómodo de la fase.
static func _resource_surplus_factor(emp: AIRealState.EmpireSnap,
		phase: AIGamePhase.Phase, w: HeuristicWeights) -> float:
	return AIEconomy.resource_surplus_factor(emp.food, emp.gold_per_turn, phase, w)



## Backend de `AIStateView.military_urgency`. Lo propio del snapshot son los dos
## recorridos que responden «¿hay frente activo?» y «¿hay enemigo adyacente?»; la
## fórmula (baseline por amenaza interpolado hacia 3.0 según la presión del frente
## más comprometido) la hace AIUrgency.
static func _military_urgency(state: AIRealState, p_owner: int,
		w: HeuristicWeights) -> float:
	var has_active_front := false
	for f in state.fronts:
		var front := f as AIRealState.FrontSnap
		if not front.is_resolved and front.involves(p_owner):
			has_active_front = true
			break

	var has_adjacent_enemy := false
	if not has_active_front:
		var enemy := OWNER_RIVAL if p_owner == OWNER_SELF else OWNER_SELF
		for id in state.tiles:
			var t := state.tiles[id] as AIRealState.TileSnap
			if t.owner != p_owner:
				continue
			for nid in t.neighbor_ids:
				var nb := state.tiles.get(nid) as AIRealState.TileSnap
				if nb != null and nb.owner == enemy:
					has_adjacent_enemy = true
					break
			if has_adjacent_enemy:
				break

	return AIUrgency.military_urgency_from(has_active_front, has_adjacent_enemy,
		_max_front_pressure(state, p_owner), w)


## Presión máxima [0.0, 1.0] de los frentes donde participa p_owner (qué tan cerca
## de perder el más comprometido).
static func _max_front_pressure(state: AIRealState, p_owner: int) -> float:
	var max_p := 0.0
	for f in state.fronts:
		var front := f as AIRealState.FrontSnap
		if front.is_resolved:
			continue
		var side := front.side_of(p_owner)
		if side == BattleFront.Side.NONE:
			continue
		var ai_marker := front.marker if side == BattleFront.Side.ATTACKER else -front.marker
		# Espejo del vivo: umbral EFECTIVO, no el de configuración.
		var pressure := AIUrgency.front_pressure(ai_marker, front.current_threshold())
		max_p = maxf(max_p, pressure)
	return max_p


# ---------------------------------------------------------------------------
# Efectos de edificio ya construidos
# ---------------------------------------------------------------------------

## Suma el bonus TROOPS_PER_RECRUIT ya activo en los edificios propios (para el
## rendimiento decreciente al valorar un nuevo cuartel).
static func _current_troops_per_recruit_bonus(state: AIRealState, p_owner: int) -> int:
	var total := 0
	for id in state.tiles:
		var t := state.tiles[id] as AIRealState.TileSnap
		if t.owner != p_owner:
			continue
		for building in t.buildings:
			if building == null:
				continue
			for effect in building.effects:
				if effect is AddStatModifierEffect:
					var sme := effect as AddStatModifierEffect
					if sme.stat_type == StatModifier.StatType.TROOPS_PER_RECRUIT:
						total += int(sme.value)
	return total


# ---------------------------------------------------------------------------
# Recorridos para la valoración de carta en el mazo
# ---------------------------------------------------------------------------
# Gemelos de AILiveFacts._card_type_count / _buildable_slots / _upgradeable_buildings.
# Vivían inline en SnapshotStateView mientras el mundo vivo ya delegaba aquí: la
# asimetría no era intencional, solo deuda. La diferencia real entre mundos es la
# FUENTE (mazo combinado vs draw+discard, TileSnap vs Tile), no la regla.

## Backend de `AIStateView.same_type_card_count`: copias de la misma clase de carta
## en el mazo del imperio. Devuelve al menos 1 para que el factor nunca sea 0.
static func _card_type_count(card: Card, emp: AIRealState.EmpireSnap) -> int:
	if card == null or emp == null:
		return 1
	var script := card.get_script() as Script
	var count := 0
	for c in emp.deck:
		if c != null and c.get_script() == script:
			count += 1
	return maxi(count, 1)


## Backend de `AIStateView.buildable_slots`: huecos de edificio libres sumados sobre
## las casillas propias. Si no hay huecos, una BuildCard es inútil.
static func _buildable_slots(state: AIRealState, p_owner: int) -> int:
	var total := 0
	for id in state.tiles:
		var t := state.tiles[id] as AIRealState.TileSnap
		if t.owner == p_owner:
			total += maxi(0, t.max_buildings - t.buildings.size())
	return total


## Backend de `AIStateView.upgradeable_count`: edificios propios con al menos una
## mejora disponible. Escala el valor de UpgradeBuildingCard.
static func _upgradeable_buildings(state: AIRealState, p_owner: int) -> int:
	var count := 0
	for id in state.tiles:
		var t := state.tiles[id] as AIRealState.TileSnap
		if t.owner != p_owner:
			continue
		for building in t.buildings:
			if building != null and not building.upgrades_to.is_empty():
				count += 1
	return count


## Backend de `AIStateView.neighbor_bonus_yield` en el SNAPSHOT. Gemelo de
## `AILiveFacts._neighbor_bonus_yield`: misma forma, distinto recorrido del mundo.
static func _neighbor_bonus_yield(state: AIRealState, b: Building,
		t: AIRealState.TileSnap) -> Vector2i:
	if b == null or t == null or not b.has_neighbor_bonuses():
		return Vector2i.ZERO
	var total := Vector2i.ZERO
	for nid in t.neighbor_ids:
		var nb := state.tiles.get(nid) as AIRealState.TileSnap
		if nb == null:
			continue
		var mismo := nb.owner != AIRealState.OWNER_NONE and nb.owner == t.owner
		for bonus in b.neighbor_bonuses:
			if bonus == null or bonus.is_empty():
				continue
			if bonus.applies_to(mismo, nb.location_type, nb.biome, nb.natural_resource):
				total += Vector2i(bonus.gold, bonus.food)
	return total
