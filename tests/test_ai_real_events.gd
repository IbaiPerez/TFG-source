extends GutTest

## Tests para el chance node de eventos de la simulación (Fase C v2 — F2.5b).
## Cubre: PARIDAD de condiciones contra las TurnEventCondition reales (agregadas),
## evaluación de condiciones de tile, disparo del evento (curva + categoría),
## selección de choice, aplicación de cada efecto y costes, y eventos únicos.


# ============================================================
#  Helpers
# ============================================================

func _seeded_rng(s: int = 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _make_card(id: String, type: int = 0) -> Card:
	var c := Card.new()
	c.id = id
	c.type = type
	return c


func _make_event(id: String, category: int, choices: Array[TurnEventChoice],
		conditions: Array[TurnEventCondition] = [], unique: bool = false,
		allow_skip: bool = true, weight: float = 1.0) -> TurnEvent:
	var e := TurnEvent.new()
	e.id = id
	e.category = category
	e.weight = weight
	e.unique = unique
	e.allow_skip = allow_skip
	e.choices = choices
	e.conditions = conditions
	return e


func _choice(effects: Array[TurnEventEffect]) -> TurnEventChoice:
	var ch := TurnEventChoice.new()
	ch.effects = effects
	return ch


func _always_on_weights(chance: float = 1.0) -> EventCategoryWeights:
	var w := EventCategoryWeights.new()
	w.event_chance_curve = null
	w.event_chance_fallback = chance
	return w


func _make_resource(gold: int, food: int) -> NaturalResource:
	var r := NaturalResource.new()
	r.gold_produced = gold
	r.food_produced = food
	return r


func _make_snap(id: int, owner: int, biome: int = 0,
		location: int = Tile.location_type.Village) -> AIRealState.TileSnap:
	var s := AIRealState.TileSnap.new()
	s.id = id
	s.owner = owner
	s.biome = biome
	s.location_type = location
	s.max_buildings = 3
	s.natural_resource = _make_resource(0, 0)
	s.neighbor_ids = []
	return s


# ============================================================
#  PARIDAD de condiciones agregadas vs reales
# ============================================================

func test_gold_threshold_condition_parity() -> void:
	var real := GoldThresholdCondition.new(100, Comparison.Type.GREATER_EQUAL)
	for gold in [50, 100, 200]:
		var ctx := EventContext.new()
		ctx.total_gold = gold
		var s := AIRealState.new()
		s.own.gold = gold
		assert_eq(AIRealEvents._condition_met(real, s, AIRealState.OWNER_SELF),
			real.is_met(ctx), "GoldThreshold paridad para gold=%d" % gold)


func test_turn_number_condition_parity() -> void:
	var real := TurnNumberCondition.new(20, Comparison.Type.GREATER_EQUAL)
	for turn in [10, 20, 30]:
		var ctx := EventContext.new()
		ctx.turn_number = turn
		var s := AIRealState.new()
		s.turn_number = turn
		assert_eq(AIRealEvents._condition_met(real, s, AIRealState.OWNER_SELF),
			real.is_met(ctx), "TurnNumber paridad para turn=%d" % turn)


func test_food_and_gpt_condition_parity() -> void:
	var food_cond := FoodThresholdCondition.new(10, Comparison.Type.GREATER_EQUAL)
	var gpt_cond := GoldGenerationCondition.new(50, Comparison.Type.LESS)
	var ctx := EventContext.new()
	ctx.food = 5
	ctx.gold_per_turn = 30
	var s := AIRealState.new()
	s.own.food = 5
	s.own.gold_per_turn = 30
	assert_eq(AIRealEvents._condition_met(food_cond, s, AIRealState.OWNER_SELF),
		food_cond.is_met(ctx), "FoodThreshold paridad")
	assert_eq(AIRealEvents._condition_met(gpt_cond, s, AIRealState.OWNER_SELF),
		gpt_cond.is_met(ctx), "GoldGeneration paridad")


func test_card_type_count_condition_parity() -> void:
	var real := CardTypeCountCondition.new(0, 2, Comparison.Type.GREATER_EQUAL)
	var cards: Array[Card] = [_make_card("a", 0), _make_card("b", 0), _make_card("c", 1)]
	var ctx := EventContext.new()
	ctx.card_count_by_type = {0: 2, 1: 1}
	var s := AIRealState.new()
	s.own.deck = cards
	assert_eq(AIRealEvents._condition_met(real, s, AIRealState.OWNER_SELF),
		real.is_met(ctx), "CardTypeCount paridad")


func test_unique_event_occurred_condition_parity() -> void:
	var real := UniqueEventOccurredCondition.new("construction_boom")
	var ctx := EventContext.new()
	ctx.stats = Stats.new()
	ctx.stats.used_unique_events = ["construction_boom"]
	var s := AIRealState.new()
	s.own.used_unique_events = ["construction_boom"]
	assert_eq(AIRealEvents._condition_met(real, s, AIRealState.OWNER_SELF),
		real.is_met(ctx), "UniqueEventOccurred paridad (presente)")


# ============================================================
#  Condiciones de tile (verificación directa sobre el snapshot)
# ============================================================

func test_urbanized_tiles_condition() -> void:
	var s := AIRealState.new()
	s.tiles[0] = _make_snap(0, AIRealState.OWNER_SELF, 0, Tile.location_type.Town)
	s.tiles[1] = _make_snap(1, AIRealState.OWNER_SELF, 0, Tile.location_type.Village)
	s.tiles[2] = _make_snap(2, AIRealState.OWNER_SELF, 0, Tile.location_type.Megalopolis)
	var cond := UrbanizedTilesCondition.new(2, Comparison.Type.GREATER_EQUAL)
	assert_true(AIRealEvents._condition_met(cond, s, AIRealState.OWNER_SELF),
		"2 casillas Town+ cumplen >= 2")


func test_has_adjacent_enemy_condition() -> void:
	var s := AIRealState.new()
	s.tiles[0] = _make_snap(0, AIRealState.OWNER_SELF)
	s.tiles[1] = _make_snap(1, AIRealState.OWNER_RIVAL)
	(s.tiles[0] as AIRealState.TileSnap).neighbor_ids = [1]
	var cond := HasAdjacentEnemyCondition.new()
	assert_true(AIRealEvents._condition_met(cond, s, AIRealState.OWNER_SELF),
		"Casilla propia adyacente a rival → enemigo adyacente")


func test_has_adjacent_enemy_turn20_override() -> void:
	var s := AIRealState.new()
	s.tiles[0] = _make_snap(0, AIRealState.OWNER_SELF)
	s.turn_number = 25  # sin rival adyacente, pero turno >= 20 fuerza true
	var cond := HasAdjacentEnemyCondition.new()
	assert_true(AIRealEvents._condition_met(cond, s, AIRealState.OWNER_SELF),
		"Override de progresión: turno >= 20 fuerza enemigo adyacente")


func test_has_recruited_troop_of_type_condition() -> void:
	var s := AIRealState.new()
	s.own.types_ever_recruited = {Troop.TroopType.CABALLERIA: 2}
	var cond := HasRecruitedTroopOfTypeCondition.new(Troop.TroopType.CABALLERIA, 2)
	assert_true(AIRealEvents._condition_met(cond, s, AIRealState.OWNER_SELF))
	var cond3 := HasRecruitedTroopOfTypeCondition.new(Troop.TroopType.CABALLERIA, 3)
	assert_false(AIRealEvents._condition_met(cond3, s, AIRealState.OWNER_SELF))


# ============================================================
#  Disparo del evento (chance node + selección)
# ============================================================

func _state_with_event(event: TurnEvent, chance: float = 1.0) -> AIRealState:
	var s := AIRealState.new()
	s.own.available_events = [event]
	s.own.category_weights = _always_on_weights(chance)
	return s


func test_event_fires_and_applies_effect() -> void:
	var event := _make_event("gold_evt", EventCategory.Type.FLAVOUR,
		[_choice([GoldEventEffect.new(100)] as Array[TurnEventEffect])] as Array[TurnEventChoice],
		[], false, false)
	var s := _state_with_event(event, 1.0)
	s.own.gold = 50
	var fired := AIRealEvents.process_turn_event(s, AIRealState.OWNER_SELF, _seeded_rng())
	assert_eq(fired, event, "El evento dispara con event_chance = 1")
	assert_eq(s.own.gold, 150, "El efecto del choice se aplica (50 + 100)")


func test_event_does_not_fire_with_zero_chance() -> void:
	var event := _make_event("gold_evt", EventCategory.Type.FLAVOUR,
		[_choice([GoldEventEffect.new(100)] as Array[TurnEventEffect])] as Array[TurnEventChoice])
	var s := _state_with_event(event, 0.0)
	s.own.gold = 50
	var fired := AIRealEvents.process_turn_event(s, AIRealState.OWNER_SELF, _seeded_rng())
	assert_null(fired, "Con event_chance = 0 no dispara")
	assert_eq(s.own.gold, 50, "El estado no cambia")


func test_event_skipped_when_condition_unmet() -> void:
	var event := _make_event("evt", EventCategory.Type.FLAVOUR,
		[_choice([GoldEventEffect.new(100)] as Array[TurnEventEffect])] as Array[TurnEventChoice],
		[GoldThresholdCondition.new(1000, Comparison.Type.GREATER_EQUAL)])
	var s := _state_with_event(event, 1.0)
	s.own.gold = 50  # no llega a 1000
	var fired := AIRealEvents.process_turn_event(s, AIRealState.OWNER_SELF, _seeded_rng())
	assert_null(fired, "Condición no cumplida → no hay candidato")


func test_unique_event_marked_and_not_refired() -> void:
	var event := _make_event("uniq", EventCategory.Type.CORE_PROGRESSION,
		[_choice([GoldEventEffect.new(10)] as Array[TurnEventEffect])] as Array[TurnEventChoice],
		[], true, false)
	var s := _state_with_event(event, 1.0)
	AIRealEvents.process_turn_event(s, AIRealState.OWNER_SELF, _seeded_rng())
	assert_true("uniq" in s.own.used_unique_events, "El evento único se marca")
	var fired2 := AIRealEvents.process_turn_event(s, AIRealState.OWNER_SELF, _seeded_rng())
	assert_null(fired2, "Un evento único ya usado no se vuelve a disparar")


func test_choice_selection_picks_highest_value() -> void:
	# Dos choices: ganar oro vs no hacer nada (skip implícito). Debe elegir el oro.
	var gold_choice := _choice([GoldEventEffect.new(200)] as Array[TurnEventEffect])
	var event := _make_event("evt", EventCategory.Type.FLAVOUR,
		[gold_choice] as Array[TurnEventChoice], [], false, true)  # allow_skip añade la opción nula
	var s := _state_with_event(event, 1.0)
	s.own.gold = 0
	AIRealEvents.process_turn_event(s, AIRealState.OWNER_SELF, _seeded_rng())
	assert_eq(s.own.gold, 200, "Elige el choice de oro frente al skip")


# ============================================================
#  Aplicación de efectos (sobre el snapshot)
# ============================================================

func _apply(effect: TurnEventEffect, s: AIRealState) -> void:
	AIRealEvents._apply_effect(effect, s, AIRealState.OWNER_SELF, _seeded_rng())


func test_apply_modifier_effect_affects_economy() -> void:
	var s := AIRealState.new()
	s.tiles[0] = _make_snap(0, AIRealState.OWNER_SELF)
	(s.tiles[0] as AIRealState.TileSnap).natural_resource = _make_resource(100, 0)
	(s.tiles[0] as AIRealState.TileSnap).resource_gold = 100
	var mod := StatModifier.new("m", "+50%", StatModifier.StatType.PERCENT_GOLD, 50.0, -1)
	_apply(ApplyModifierEffect.new(mod), s)
	assert_eq(s.own.modifiers.size(), 1, "El modifier se añade al estado")
	AIRealSimulator.recompute_own_economy(s)
	assert_eq(s.own.gold_per_turn, 150, "La economía refleja el +50% del evento")


func test_unlock_building_effect_adds_to_possible() -> void:
	var s := AIRealState.new()
	var b := Building.new()
	b.name = "Cuartel"
	_apply(UnlockBuildingEffect.new(b), s)
	assert_true(b in s.own.possible_buildings, "El edificio se desbloquea")
	_apply(UnlockBuildingEffect.new(b), s)
	assert_eq(s.own.possible_buildings.size(), 1, "No se duplica el desbloqueo")


func test_add_to_card_pool_effect_dedups() -> void:
	var s := AIRealState.new()
	var card := _make_card("recruit", 0)
	_apply(AddToCardPoolEffect.new(card, 8.0, -0.1, 3.0), s)
	assert_eq(s.own.unlocked_card_pool.size(), 1, "La carta entra al pool desbloqueado")
	_apply(AddToCardPoolEffect.new(card, 8.0, -0.1, 3.0), s)
	assert_eq(s.own.unlocked_card_pool.size(), 1, "No se duplica por id")


func test_add_card_effect_grows_deck() -> void:
	var s := AIRealState.new()
	s.own.deck = [_make_card("a")]
	_apply(AddCardEffect.new(_make_card("recruit")), s)
	assert_eq(s.own.deck.size(), 2, "AddCard añade una carta al mazo")


func test_add_random_pool_card_effect() -> void:
	var s := AIRealState.new()
	s.own.unlocked_card_pool = [UnlockedCardEntry.new(_make_card("x"), 5.0, 0.0, 1.0)]
	_apply(AddRandomPoolCardEffect.new(), s)
	assert_eq(s.own.deck.size(), 1, "Roba una carta del pool desbloqueado al mazo")


func test_gold_and_food_effects() -> void:
	var s := AIRealState.new()
	s.own.gold = 100
	s.own.food = 10
	_apply(GoldEventEffect.new(-30), s)
	_apply(FoodEventEffect.new(5), s)
	assert_eq(s.own.gold, 70, "GoldEventEffect aplica delta (puede ser negativo)")
	assert_eq(s.own.food, 15, "FoodEventEffect aplica delta")


func test_scaled_gold_effect_uses_turn_and_gpt() -> void:
	var s := AIRealState.new()
	s.own.gold = 0
	s.own.gold_per_turn = 100
	s.turn_number = 10
	# base 50 + turno(10)*2 + gpt(100)*0.5 = 50 + 20 + 50 = 120
	_apply(ScaledGoldEffect.new(50.0, 2.0, 0.5), s)
	assert_eq(s.own.gold, 120, "ScaledGold escala con turno y gpt")


func test_remove_card_event_effect_auto_filter() -> void:
	var s := AIRealState.new()
	s.own.deck = [_make_card("colonize", 0), _make_card("build", 1)]
	var filter := CardRemovalFilter.new()
	filter.card_id = "colonize"
	_apply(RemoveCardEventEffect.new(filter, null), s)
	assert_eq(s.own.deck.size(), 1, "Elimina la carta que casa el filtro")
	assert_eq(s.own.deck[0].id, "build", "Queda la otra carta")


func test_colonize_adjacent_effect() -> void:
	var s := AIRealState.new()
	s.tiles[0] = _make_snap(0, AIRealState.OWNER_SELF)
	s.tiles[1] = _make_snap(1, AIRealState.OWNER_NONE, 0, Tile.location_type.Uncolonized)
	(s.tiles[0] as AIRealState.TileSnap).neighbor_ids = [1]
	_apply(ColonizeAdjacentEffect.new(-1), s)
	assert_eq((s.tiles[1] as AIRealState.TileSnap).owner, AIRealState.OWNER_SELF,
		"El evento coloniza la casilla adyacente libre")


func test_urbanize_to_megalopolis_effect() -> void:
	var s := AIRealState.new()
	var town := _make_snap(0, AIRealState.OWNER_SELF, 0, Tile.location_type.Town)
	var blds: Array[Building] = []
	for i in range(3):
		var b := Building.new()
		b.name = "b%d" % i
		blds.append(b)
	town.buildings = blds
	s.tiles[0] = town
	_apply(UrbanizeToMegalopolisEffect.new(), s)
	assert_eq((s.tiles[0] as AIRealState.TileSnap).location_type,
		Tile.location_type.Megalopolis, "Town con 3 edificios sube a Megalópolis")


# ============================================================
#  Costes
# ============================================================

func test_choice_with_cost_pays_gold() -> void:
	var ch := _choice([GoldEventEffect.new(300)] as Array[TurnEventEffect])
	var cost := TurnEventCost.new()
	cost.gold = 50
	ch.cost = cost
	var event := _make_event("evt", EventCategory.Type.FLAVOUR,
		[ch] as Array[TurnEventChoice], [], false, false)
	var s := _state_with_event(event, 1.0)
	s.own.gold = 100
	AIRealEvents.process_turn_event(s, AIRealState.OWNER_SELF, _seeded_rng())
	assert_eq(s.own.gold, 350, "Paga el coste (50) y recibe el efecto (300): 100 − 50 + 300")


func test_unaffordable_choice_falls_back_to_skip() -> void:
	var ch := _choice([GoldEventEffect.new(300)] as Array[TurnEventEffect])
	var cost := TurnEventCost.new()
	cost.gold = 500  # inasequible
	ch.cost = cost
	var event := _make_event("evt", EventCategory.Type.FLAVOUR,
		[ch] as Array[TurnEventChoice], [], false, true)
	var s := _state_with_event(event, 1.0)
	s.own.gold = 100
	AIRealEvents.process_turn_event(s, AIRealState.OWNER_SELF, _seeded_rng())
	assert_eq(s.own.gold, 100, "Choice inasequible no se aplica; se va a skip")


# ============================================================
#  Integración en advance_turn + clone
# ============================================================

func test_advance_turn_fires_event() -> void:
	var event := _make_event("gold_evt", EventCategory.Type.FLAVOUR,
		[_choice([GoldEventEffect.new(100)] as Array[TurnEventEffect])] as Array[TurnEventChoice],
		[], false, false)
	var s := _state_with_event(event, 1.0)
	s.own.gold = 0
	AIRealSimulator.advance_turn(s, _seeded_rng())
	assert_eq(s.own.gold, 100, "advance_turn dispara el evento de fin de turno")


func test_clone_event_state_independent() -> void:
	var s := AIRealState.new()
	s.own.used_unique_events = ["a"]
	s.own.possible_buildings = [Building.new()]
	var c := s.clone()
	c.own.used_unique_events.append("b")
	c.own.possible_buildings.append(Building.new())
	assert_eq(s.own.used_unique_events.size(), 1, "Clonar no altera los eventos únicos del original")
	assert_eq(s.own.possible_buildings.size(), 1, "Clonar no altera los edificios del original")
