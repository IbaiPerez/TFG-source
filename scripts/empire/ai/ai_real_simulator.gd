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
		# Espejo de BattleFront.get_front_maintenance: cada tropa paga SU base por la
		# curva del frente Y por el descuento de modifiers, evaluado tropa a tropa
		# (troop_type_filter). Sin esta segunda parte, un modificador de imperio se
		# apagaría al desplegar la tropa y el snapshot divergiría del juego real.
		var front_gold := 0.0
		var front_food := 0.0
		for i in range(troops.size()):
			var discount := ProductionMath.maintenance_multiplier(
				ModifierQuery.troop_maintenance_percent(mods, troops[i]))
			front_gold += float(troops[i].maintenance_gold) \
				* CombatMath.front_gold_upkeep_multiplier(i + 1) * discount
			front_food += float(troops[i].maintenance_food) \
				* CombatMath.front_food_upkeep_multiplier(i + 1) * discount
		surcharge_gold += int(round(front_gold))
		surcharge_food += int(round(front_food))

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

	AIRealCombat.assign_troops_to_fronts(state, AIRealState.OWNER_SELF, w)
	AIRealCombat.assign_troops_to_fronts(state, AIRealState.OWNER_RIVAL, w)

	recompute_economy(state, AIRealState.OWNER_SELF)
	recompute_economy(state, AIRealState.OWNER_RIVAL)
	state.own.gold += state.own.gold_per_turn
	state.rival.gold += state.rival.gold_per_turn

	AIRealCombat._tick_all_fronts(state)
	state.turn_number += 1



# ---------------------------------------------------------------------------
# Consultas de modificadores
# ---------------------------------------------------------------------------
# La agregación de modifiers vive en ModifierQuery (compartida con el juego real
# vía ModifierManager). El coste de construcción efectivo vive con los efectos
# (AIRealEffects), que es quien lo cobra; aquí solo queda el tick de duración,
# que forma parte de la transición de turno.

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
