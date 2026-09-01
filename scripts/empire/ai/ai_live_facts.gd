extends RefCounted
class_name AILiveFacts

## Recorridos sobre el mundo VIVO (Stats / Tile / BattleFront) que alimentan la
## heurística: cuántos huecos de construcción quedan, qué edificios se
## desbloquean al urbanizar, cuánto abre una casilla la frontera…
##
## Es el contrapunto exacto del backend que AIRealEvalStrong es para el
## snapshot: LiveStateView responde a los métodos del puerto llamando aquí, y
## las fórmulas puras que consumen estos datos viven en scoring/ (AITerritory,
## AIEconomy, AIMilitary…), escritas una sola vez para los dos mundos.
##
## Lo que hay aquí, por tanto, es la mitad "cómo se lee este mundo" — la que no
## se puede compartir porque el snapshot no tiene nodos ni escena.


## Número total de cartas en el mazo activo (draw + discard pile).
## No incluye played_pile ni la mano corriente (drawn_cards).
static func _current_deck_size(ctx: AITurnContext) -> int:
	if ctx.stats == null:
		return 0
	var n := 0
	if ctx.stats.draw_pile:
		n += ctx.stats.draw_pile.cards.size()
	if ctx.stats.discard_pile:
		n += ctx.stats.discard_pile.cards.size()
	return n


## Cuenta cuántas cartas del mismo tipo (misma clase GDScript) hay en el mazo
## activo (draw + discard). Devuelve al menos 1 para que el factor nunca sea 0.
static func _card_type_count(card: Card, ctx: AITurnContext) -> int:
	if ctx.stats == null:
		return 1
	var script: Script = card.get_script() as Script
	var count := 0
	if ctx.stats.draw_pile:
		for c in ctx.stats.draw_pile.cards:
			if c != null and c.get_script() == script:
				count += 1
	if ctx.stats.discard_pile:
		for c in ctx.stats.discard_pile.cards:
			if c != null and c.get_script() == script:
				count += 1
	return maxi(count, 1)


## Factor de excedente económico [1.0, surplus_max].
## Cuando el empire tiene oro y comida muy por encima de sus umbrales, el coste
## de oportunidad de reclutar o abrir frentes es mínimo y estas acciones se
## potencian. Los dos ejes rampan igual: neutro en el umbral, pleno al doblarlo
## (ver AIEconomy.resource_surplus_factor).
static func _resource_surplus_factor(ctx: AITurnContext, phase: AIGamePhase.Phase) -> float:
	if ctx.stats == null:
		return 1.0
	return AIEconomy.resource_surplus_factor(
		ctx.stats.food, ctx.stats.gold_per_turn, phase, ctx.get_weights())


## Factor de presión expansionista [0.0, 1.0] basado en tiles colonizables
## adyacentes al territorio actual. Independiente de la fase (turno).
## 1.0 = muchas tiles libres alrededor (expansión plena)
## 0.0 = sin tiles colonizables (mapa saturado)
## Cuando colonizable_tiles_count == -1 (tests sin mapa) → 0.5 neutro.
static func _expansion_factor(ctx: AITurnContext) -> float:
	# El vivo usa el conteo precomputado del contexto (puede ser -1 en tests sin mapa).
	return AITerritory.expansion_factor(ctx.colonizable_tiles_count, ctx.get_weights())



## Valor de adelgazar el mazo en una carta, proporcional al tamaño del mazo.
## Mazo pequeño (≤DECK_SMALL): el ciclo ya es rápido, purgar aporta poco.
## Mazo grande (≥DECK_LARGE): el ciclo es lento, purgar acelera las cartas clave.
## Umbral dinámico de puntuación mínima para purgar una carta del mazo en tienda.
## Mazo pequeño: umbral bajo → solo eliminar cartas casi inútiles.
## Mazo grande/saturado: umbral alto → eliminar hasta cartas de utilidad moderada
## para acelerar el ciclo de las más valiosas.
## Es public porque lo usa también AIEventResolver.
static func dynamic_purge_threshold(ctx: AITurnContext) -> float:
	# Política compartida con el snapshot.
	return AIShopPolicy.purge_threshold(LiveStateView.new(ctx))


## Número total de huecos de edificio vacíos en las tiles controladas.
## Un hueco es un slot donde se puede construir (tile.max_buildings - tile.buildings.size()).
## Usado para escalar BuildCard: si no hay huecos la carta es inútil.
static func _buildable_slots(ctx: AITurnContext) -> int:
	if ctx.stats == null or ctx.stats.empire == null:
		return 0
	var total := 0
	for tile in ctx.stats.empire.controlled_tiles:
		total += maxi(0, tile.max_buildings - tile.buildings.size())
	return total


## Número de edificios construidos que tienen al menos una mejora disponible
## (upgrades_to no vacío). Usado para escalar UpgradeBuildingCard.
static func _upgradeable_buildings(ctx: AITurnContext) -> int:
	if ctx.stats == null or ctx.stats.empire == null:
		return 0
	var count := 0
	for tile in ctx.stats.empire.controlled_tiles:
		for building in tile.buildings:
			if building != null and not building.upgrades_to.is_empty():
				count += 1
	return count


## Devuelve true si un edificio quedará demolido al asignar new_loc a la tile.
## Replica la lógica de ChangeLocationTypeEffect: se destruye si
## allowed_location_type no está vacío y no contiene new_loc (comparando por
## valor de enum, no por referencia, para robustez en la heurística).
static func _building_demolished_by(building: Building, new_loc: LocationType) -> bool:
	if building.allowed_location_type.is_empty():
		return false          # sin restricción de location → sobrevive siempre
	for allowed in building.allowed_location_type:
		if allowed.type == new_loc.type:
			return false      # el nuevo tipo está en la lista → sobrevive
	return true               # new_loc no está → se demolerá


## Devuelve true si el edificio explota el recurso natural de la tile
## Y es una versión mejorada (no el edificio base): algún edificio en
## stats.possible_buildings lo tiene en su lista upgrades_to.
static func _is_upgraded_resource_building(building: Building, tile: Tile,
		ctx: AITurnContext) -> bool:
	if building.required_natural_resource == null:
		return false
	if building.required_natural_resource != tile.natural_resource:
		return false
	if ctx.stats == null or ctx.stats.possible_buildings == null:
		return false
	for possible in ctx.stats.possible_buildings:
		if building in possible.upgrades_to:
			return true   # `building` es el resultado de un upgrade → está mejorado
	return false


## Puntúa los edificios que se DESBLOQUEAN al pasar de old_loc a new_loc
## en una tile concreta. Solo se cuentan edificios que:
##  - requieren new_loc (su allowed_location_type lo incluye)
##  - NO podían construirse en old_loc (nuevo con este tier)
##  - son compatibles con el bioma y el recurso natural de la tile
##  - aún no están construidos en la tile
## Devuelve la suma de su valor económico, topada en 15.0 para evitar dominancia.
static func _score_unlocked_buildings(tile: Tile, old_loc: LocationType,
		new_loc: LocationType, ctx: AITurnContext,
		gu: float, fu: float, mu: float) -> float:
	if ctx.stats == null or ctx.stats.possible_buildings == null:
		return 0.0
	var w := ctx.get_weights()
	var total := 0.0
	for b in ctx.stats.possible_buildings:
		if b == null or b.allowed_location_type.is_empty():
			continue
		# El edificio debe encajar en new_loc pero NO en old_loc.
		var fits_new := false
		var fits_old := false
		for allowed in b.allowed_location_type:
			if allowed.type == new_loc.type: fits_new = true
			if allowed.type == old_loc.type: fits_old = true
		if not fits_new or fits_old:
			continue
		# Compatibilidad de bioma.
		if not b.allowed_biomes.is_empty() \
				and tile.mesh_data.type not in b.allowed_biomes:
			continue
		# Compatibilidad de recurso natural.
		if b.required_natural_resource != null \
				and b.required_natural_resource != tile.natural_resource:
			continue
		# Ya construido: no aporta desbloqueado nuevo.
		if b in tile.buildings:
			continue
		total += b.gold_produced * w.unlock_gold * gu \
			   + b.food_produced * w.unlock_food * fu \
			   + b.flat_defense_bonus * w.unlock_defense * mu
	return minf(total, w.unlock_cap)


## Bonus de complementariedad: favorece tropas que equilibran el pool actual
## y además contrarrestan la composición visible del rival en frentes activos.
## ctx puede ser null (tests o llamadas sin info de rival → solo balance interno).
static func _complement_bonus(troop: Troop, pool: Array[Troop],
		ctx: AITurnContext = null) -> float:
	var w := ctx.get_weights() if ctx != null else HeuristicWeights.get_default()
	# D7: recolectar tipos de tropa del rival visibles en frentes activos. Sin
	# world_view/rival (tests) → lista vacía → counter neutro. La fórmula del
	# complemento y del counter viven en AIMilitary (compartidas con el snapshot).
	var rival_types: Array[int] = []
	if ctx != null and ctx.world_view != null:
		var rival := ctx.world_view.get_rival_view()
		if rival != null and rival.empire != null:
			var all_fronts := ctx._cache_active_fronts if ctx._cache_valid \
				else ctx.get_front_registry().get_active_instances()
			for front in all_fronts:
				if front.is_resolved:
					continue
				var rival_side_troops: Array[Troop] = front.attacker_troops \
					if front.attacker_empire == rival.empire else front.defender_troops
				if front.attacker_empire != rival.empire \
						and front.defender_empire != rival.empire:
					continue
				for t in rival_side_troops:
					if t.type not in rival_types:
						rival_types.append(t.type)

	return AIMilitary.complement_bonus(troop, pool, w) \
		* AIMilitary.counter_bonus(troop.type, rival_types, w)



## Tiles nuevas que se volverían colonizables exclusivamente gracias a colonizar
## `tile`. Una vecina libre cuenta como "nueva" solo si ningún otro tile del
## territorio actual ya la hace accesible. Cuanto mayor, más abre esta tile
## rutas de expansión hacia espacio libre (difícil de rodear).
static func _frontier_value(tile: Tile, ctx: AITurnContext) -> int:
	if ctx.stats == null or ctx.stats.empire == null:
		return 0
	var count := 0
	for nb in tile.neighbors:
		var t := nb as Tile
		if t == null or t.controller != null:
			continue
		var already_reachable := false
		for nn in t.neighbors:
			var nt := nn as Tile
			if nt == null or nt == tile:
				continue
			if nt.controller == ctx.stats.empire:
				already_reachable = true
				break
		if not already_reachable:
			count += 1
	return count


## Multiplicador del bonus de frontera según el grado de encierro.
## Ratio = tiles_colonizables / tiles_controladas.
## Ratio bajo → la IA está quedando rodeada → escalar el incentivo de escapar.
static func _encirclement_pressure(ctx: AITurnContext) -> float:
	var w := ctx.get_weights()
	# Sin empire o sin conteo de mapa (tests): valor neutro. La fórmula por ratio
	# vive en AITerritory.encirclement_pressure (compartida con el snapshot).
	if ctx.stats == null or ctx.stats.empire == null:
		return w.encircle_default
	var avail := ctx.colonizable_tiles_count
	if avail < 0:
		return w.encircle_default
	var controlled := maxi(ctx.stats.empire.controlled_tiles.size(), 1)
	return AITerritory.encirclement_pressure(avail, controlled, w)


## Village→Town: +5 food_consumption y +2 building slots.
## Town→Megalópolis: +5 food_consumption adicional y +2 building slots más.


## Suma el bonus TROOPS_PER_RECRUIT ya activo en los edificios construidos del empire.
## Usado para calcular el rendimiento decreciente al valorar un nuevo cuartel.
static func _current_troops_per_recruit_bonus(ctx: AITurnContext) -> int:
	if ctx.stats == null or ctx.stats.empire == null:
		return 0
	var total := 0
	for tile in ctx.stats.empire.controlled_tiles:
		for building in tile.buildings:
			if building == null:
				continue
			for effect in building.effects:
				if effect is AddStatModifierEffect:
					var sme := effect as AddStatModifierEffect
					if sme.stat_type == StatModifier.StatType.TROOPS_PER_RECRUIT:
						total += int(sme.value)
	return total


## Factor de carrera territorial [0.5, 2.0] basado en la distribución de tiles.
## mode &"colonize"/"open_front": amplifica acciones expansivas cuando la carrera
## es ajustada o el rival se acerca al 55% del territorio conocido.
## mode &"economy": reduce el valor de mejoras económicas cuando ya dominamos.
## Devuelve 1.0 si world_view es null (tests sin info de rival).
static func _territory_race_factor(ctx: AITurnContext,
		mode: StringName = &"colonize") -> float:
	if ctx.world_view == null:
		return 1.0
	var rival := ctx.world_view.get_rival_view()
	if rival == null or rival.empire == null:
		return 1.0
	var my_tiles := ctx.stats.empire.controlled_tiles.size() \
		if ctx.stats.empire != null else 0
	var rival_tiles := rival.empire.controlled_tiles.size()
	# Cuota sobre el MAPA, no sobre las casillas en disputa: ver AITerritory.
	return AITerritory.territory_race_factor(
		my_tiles, rival_tiles, ctx.total_map_tiles, mode, ctx.get_weights())


## Factor de coste-eficiencia: coste por unidad de valor del edificio, acotado a
## [build_cost_min, 1.0]. Solo aplica el default de pesos y delega en AIEconomy.
##
## OJO: no tiene ningún llamante de producción — score_build y score_upgrade van
## directos a AIEconomy.apply_build_cost. Sobrevive solo porque lo usan tests.
static func _build_cost_factor(cost: int, value: float,
		w: HeuristicWeights = null) -> float:
	if w == null: w = HeuristicWeights.get_default()
	return AIEconomy.build_cost_factor(cost, value, w)


## Multiplicador de dificultad de ataque según el bioma de la tile enemiga.


## Montaña 0.60, Pantano 0.70, Bosque 0.80 … Pradera 1.20.
static func _attack_biome_factor(tile: Tile) -> float:
	if tile == null or tile.mesh_data == null:
		return 1.0
	return BiomeConfig.shared().get_attack_multiplier(tile.mesh_data.type)
