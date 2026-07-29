extends RefCounted
class_name AIStateView

## Puerto de dominio para la heurística (refactor C4 §1.3.g). Abstrae el estado del
## juego para que los scorers de jugada (AIMoveScorer) se escriban UNA sola vez y
## valgan sobre los dos mundos:
##   - LiveStateView   → estado vivo (Stats / Tile / BattleFront), camino frío
##                       (priors de la raíz, una vez por decisión).
##   - SnapshotStateView → snapshot puro (AIRealState), camino CALIENTE del MCTS
##                       (prior/rollout, miles de veces por decisión).
##
## Sustituye la duplicación espejo AIHeuristic ↔ AIRealEvalStrong. Los datos de la
## JUGADA (edificio, tropa, cantidad, tile objetivo) NO pasan por el puerto: se
## pasan aparte a cada scorer, porque Building/Troop son clases compartidas y el
## tile se maneja como handle opaco (para no asignar wrappers por-tile en el hot
## path). La clase base declara el contrato; cada método hace push_error si una
## implementación olvida sobrescribirlo.

# --- economía propia ---
func weights() -> HeuristicWeights:
	push_error("AIStateView.weights() sin implementar"); return null

func gold_per_turn() -> int:
	push_error("AIStateView.gold_per_turn() sin implementar"); return 0

func food() -> int:
	push_error("AIStateView.food() sin implementar"); return 0

# --- fase de partida ---
func phase() -> AIGamePhase.Phase:
	push_error("AIStateView.phase() sin implementar"); return AIGamePhase.Phase.EARLY

## Turno actual, para los efectos escalados por turno (ScaledValue). C6 §1.6.3.
func turn_number() -> int:
	push_error("AIStateView.turn_number() sin implementar"); return 0

# --- mazo ---
## Tamaño de mazo que alimenta la urgencia de robar. Cada mundo usa su medida
## histórica: el vivo el draw_pile; el snapshot el mazo combinado (draw+discard).
func deck_urgency_size() -> int:
	push_error("AIStateView.deck_urgency_size() sin implementar"); return 0

# --- urgencias derivadas (el vivo puede devolver el valor cacheado de la decisión) ---
func gold_urgency() -> float:
	push_error("AIStateView.gold_urgency() sin implementar"); return 1.0

func food_urgency() -> float:
	push_error("AIStateView.food_urgency() sin implementar"); return 1.0

# --- territorio ---
func expansion_factor() -> float:
	push_error("AIStateView.expansion_factor() sin implementar"); return 0.0

func encirclement_pressure() -> float:
	push_error("AIStateView.encirclement_pressure() sin implementar"); return 1.0

func territory_race_factor(_mode: StringName) -> float:
	push_error("AIStateView.territory_race_factor() sin implementar"); return 1.0

# --- casillas (handle opaco: Tile en el vivo, TileSnap en el snapshot) ---
## Casillas libres que colonizar `tile` desbloquearía por primera vez.
func frontier_value(_tile) -> int:
	push_error("AIStateView.frontier_value() sin implementar"); return 0

## True si `tile` es adyacente a alguna casilla del rival (bonus de negación).
func tile_adjacent_to_rival(_tile) -> bool:
	push_error("AIStateView.tile_adjacent_to_rival() sin implementar"); return false

func tile_gold_production(_tile) -> int:
	push_error("AIStateView.tile_gold_production() sin implementar"); return 0

func tile_food_production(_tile) -> int:
	push_error("AIStateView.tile_food_production() sin implementar"); return 0

# --- militar ---
func military_urgency() -> float:
	push_error("AIStateView.military_urgency() sin implementar"); return 1.0

# --- construcción ---
func gold() -> int:
	push_error("AIStateView.gold() sin implementar"); return 0

func effective_build_cost(_b: Building) -> int:
	push_error("AIStateView.effective_build_cost() sin implementar"); return 0

## Puntúa los efectos de un edificio con las urgencias ya calculadas. Delega en el
## valorador de cada mundo (difieren en la rama AddCardToDeckEffect: el valorador de
## carta no es el mismo en vivo y en snapshot).
func score_building_effects(_effects: Array[BuildingEffect], _gu: float, _fu: float, _mu: float) -> float:
	push_error("AIStateView.score_building_effects() sin implementar"); return 0.0

# --- casillas (desempates de construcción) ---
## Recurso natural de la casilla (para el micro-bonus si el edificio lo explota).
func tile_natural_resource(_tile):
	push_error("AIStateView.tile_natural_resource() sin implementar"); return null

## True si `tile` linda con territorio de OTRO imperio (posición fronteriza).
func tile_adjacent_to_enemy(_tile) -> bool:
	push_error("AIStateView.tile_adjacent_to_enemy() sin implementar"); return false

# --- reclutamiento ---
## Tropas libres del imperio (no asignadas a frentes activos).
func troop_pool() -> Array[Troop]:
	push_error("AIStateView.troop_pool() sin implementar"); return []

## Factor de excedente económico (el vivo puede devolver el valor cacheado).
func resource_surplus_factor() -> float:
	push_error("AIStateView.resource_surplus_factor() sin implementar"); return 1.0

## Complementariedad + counter de la tropa respecto al pool propio y al rival visible.
func complement_bonus(_troop: Troop) -> float:
	push_error("AIStateView.complement_bonus() sin implementar"); return 1.0

## Máximo de tropas propias en un frente activo, para proyectar el recargo cuadrático.
## Devuelve -1 si no aplica el veto de recargo (cada mundo define su condición de gate).
func recruit_front_max_troops() -> int:
	push_error("AIStateView.recruit_front_max_troops() sin implementar"); return -1

## Bonus de tropas-por-reclutamiento de los modifiers activos (para el per_play de
## la enumeración de RECRUIT). Espejo del cálculo de ModifierQuery en ambos mundos.
func troops_per_recruit_bonus(_troop: Troop) -> int:
	push_error("AIStateView.troops_per_recruit_bonus() sin implementar"); return 0

# --- enumeración de construcción / mejora (legalidad) ---
## Casillas propias, en el orden nativo de cada mundo (handles opacos).
func owned_tiles() -> Array:
	push_error("AIStateView.owned_tiles() sin implementar"); return []

func can_build(_tile, _building: Building) -> bool:
	push_error("AIStateView.can_build() sin implementar"); return false

func tile_buildings(_tile) -> Array[Building]:
	push_error("AIStateView.tile_buildings() sin implementar"); return []

## True si el edificio puede mejorarse en absoluto (guarda del mundo vivo; el
## snapshot no lo comprueba → siempre true).
func can_be_upgraded(_old_building: Building) -> bool:
	push_error("AIStateView.can_be_upgraded() sin implementar"); return true

func can_upgrade(_tile, _old_building: Building, _new_building: Building) -> bool:
	push_error("AIStateView.can_upgrade() sin implementar"); return false

# --- enumeración de colonización / cambio de ubicación ---
## Casillas libres colonizables (adyacentes a territorio propio), en el orden nativo
## de cada mundo. COLONIZE usa dos mecanismos distintos (vivo: AdjacentRule; snapshot:
## recorrido propio→vecinos-libres), por eso vive en la vista y no en AILegality.
func colonizable_tiles() -> Array:
	push_error("AIStateView.colonizable_tiles() sin implementar"); return []

## Tipo de ubicación (enum) de la casilla, para el gating de CHANGE_LOCATION.
func tile_location_type(_tile) -> int:
	push_error("AIStateView.tile_location_type() sin implementar"); return 0

# --- enumeración de apertura de frente / táctica ---
## Pares (casilla propia origen, casilla enemiga destino) para abrir frente, como
## diccionarios {"source", "def"} de handles. Vacío si no se puede abrir frente.
## Dos mecanismos por mundo (vivo: EnemyAdjacentRule enemiga→propia; snapshot:
## propia→enemiga), por eso vive en la vista.
func open_front_pairs(_card) -> Array:
	push_error("AIStateView.open_front_pairs() sin implementar"); return []

## Frentes activos donde participamos, para jugar tácticas. El vivo devuelve los
## BattleFront; el snapshot los ÍNDICES en state.fronts (cada enumerador interpreta).
func tactic_targets() -> Array:
	push_error("AIStateView.tactic_targets() sin implementar"); return []

# --- apertura de frente ---
## Producción de oro/comida del RECURSO natural de la casilla (0 si no tiene). Es
## distinto de tile_gold_production (producción total de la casilla).
func tile_resource_gold(_tile) -> int:
	push_error("AIStateView.tile_resource_gold() sin implementar"); return 0

func tile_resource_food(_tile) -> int:
	push_error("AIStateView.tile_resource_food() sin implementar"); return 0

## Multiplicador de ataque por bioma de la casilla (1.0 si se desconoce el bioma).
func tile_attack_biome_factor(_tile) -> float:
	push_error("AIStateView.tile_attack_biome_factor() sin implementar"); return 1.0

## Ganabilidad estimada del frente [win_min, win_max] con info pública del rival.
## Aísla las divergencias de cada mundo (el vivo omite el cálculo sin world_view;
## el guarda del multiplicador de bioma defensivo también difiere).
func open_front_win_factor(_enemy_tile, _biome_factor: float) -> float:
	push_error("AIStateView.open_front_win_factor() sin implementar"); return 1.0

## Valor de la casilla origen (edificios + recurso). Per-mundo porque el ORDEN de
## suma difiere (vivo: a+(b+c) con guarda de recurso; snapshot: (a+b)+c). null → 0.
func open_front_source_value(_source_tile) -> float:
	push_error("AIStateView.open_front_source_value() sin implementar"); return 0.0

# --- cambio de ubicación ---
func tile_food_consumption(_tile) -> int:
	push_error("AIStateView.tile_food_consumption() sin implementar"); return 0

func tile_max_buildings(_tile) -> int:
	push_error("AIStateView.tile_max_buildings() sin implementar"); return 0

## Ajuste final del score de cambio de ubicación sobre `base`: penalización por
## edificios demolidos (+ bonos de recurso/desbloqueo SOLO en el mundo vivo; el
## snapshot usa una aproximación-suelo). Per-mundo: fórmula y asociatividad exactas.
func change_location_adjust(_base: float, _tile, _new_loc, _gu: float, _fu: float, _mu: float) -> float:
	push_error("AIStateView.change_location_adjust() sin implementar"); return _base

# --- valoración de carta para el mazo (score_card_for_deck, C6 §1.6.5) ---
## Copias de la misma clase de carta en el mazo activo (≥1). Base de la saturación
## por tipo. El vivo cuenta draw+discard; el snapshot su mazo combinado.
func same_type_card_count(_card: Card) -> int:
	push_error("AIStateView.same_type_card_count() sin implementar"); return 1

## Casillas colonizables (para ColonizeCard). El vivo usa el conteo cacheado del
## contexto (puede ser -1 en tests sin mapa); el snapshot su recorrido propio.
func colonizable_count() -> int:
	push_error("AIStateView.colonizable_count() sin implementar"); return 0

## Edificios construidos con al menos una mejora disponible (para UpgradeBuildingCard).
func upgradeable_count() -> int:
	push_error("AIStateView.upgradeable_count() sin implementar"); return 0

## Huecos de edificio libres sumados sobre las casillas propias (para BuildCard).
func buildable_slots() -> int:
	push_error("AIStateView.buildable_slots() sin implementar"); return 0

## Casillas propias que un ChangeLocationTypeCard a `target_type` podría urbanizar
## (su tipo actual es exactamente el anterior: location.type + 1 == target_type).
func change_location_target_count(_target_type: int) -> int:
	push_error("AIStateView.change_location_target_count() sin implementar"); return 0

## Tamaño del mazo activo (draw+discard en el vivo, mazo combinado en el snapshot)
## que alimenta la urgencia de CardDrawCard. Distinto de deck_urgency_size (draw).
func deck_size() -> int:
	push_error("AIStateView.deck_size() sin implementar"); return 0

## Cartas recuperables por un RecoverCard (draw+discard en el vivo). El scorer filtra
## nulls y RecoverCards y puntúa la mejor recursivamente.
func recoverable_cards() -> Array[Card]:
	push_error("AIStateView.recoverable_cards() sin implementar"); return []
