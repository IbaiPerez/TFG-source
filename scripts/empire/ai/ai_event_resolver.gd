extends RefCounted
class_name AIEventResolver

## Resuelve TurnEvents y ShopEvents headless para la IA, replicando la
## lógica que TurnEventPanel y ShopPanel aplican al jugador pero sin abrir
## ningún panel y eligiendo al azar las decisiones que requieren input.
##
## Versión 1 (Fase 4): random uniforme en todas las decisiones, igual que
## el bucle de cartas. Mejorable cuando metamos heurísticas: a la IA le
## conviene ponderar las choices, descartar cartas con sentido, etc.
##
## Soporta dos tipos de evento:
##  - ShopEvent: itera shop_config.items y compra cada uno con probabilidad
##    SHOP_PURCHASE_CHANCE si puede permitirlo. La purga se omite en esta
##    versión (alcance v1).
##  - TurnEvent normal: filtra choices affordable, añade skip si allow_skip,
##    elige una al azar y la ejecuta. Maneja tile_input y card_input
##    eligiendo random de las eligibles/candidatas.
##
## Marca el evento como `unique` en stats.used_unique_events si aplica.


## Probabilidad de comprar cada item de un shop. Hardcoded en v1; tunear
## cuando se observe el comportamiento real.
const SHOP_PURCHASE_CHANCE := 0.5


## Punto de entrada. Llama desde AIController tras evaluar el evento.
static func resolve(event: TurnEvent, context: EventContext,
		rng: RandomNumberGenerator, manager: TurnEventManager) -> void:
	if event == null or context == null:
		return

	if event is ShopEvent:
		_resolve_shop_event(event as ShopEvent, context.stats, rng)
		_mark_unique_if_applicable(event, context.stats)
		GameLogger.debug("    [IA-Event] resuelto ShopEvent '%s'%s" % [event.id,
			" (marcado unique)" if event.unique else ""])
		return

	_resolve_turn_event(event, context, rng, manager)


# ============================================================
#  TurnEvent (normal)
# ============================================================

static func _resolve_turn_event(event: TurnEvent, context: EventContext,
		rng: RandomNumberGenerator, manager: TurnEventManager) -> void:
	# 1. Filtrar choices affordable (igual que el panel).
	var available: Array[TurnEventChoice] = []
	for c in event.choices:
		if c != null and c.is_affordable(context):
			available.append(c)

	# 2. Añadir skip choice si el evento lo permite. Replica
	#    TurnEventPanel._populate_choices.
	if event.allow_skip:
		var skip_choice := TurnEventChoice.new()
		skip_choice.label = "No hacer nada"
		skip_choice.description = "Declinar el evento."
		available.append(skip_choice)

	# 3. Si no hay nada elegible (raro: ningún choice asequible y no se
	#    permite skip), marcar unique y salir.
	if available.is_empty():
		_mark_unique_if_applicable(event, context.stats)
		return

	# 4. Elegir una al azar.
	var picked := available[rng.randi_range(0, available.size() - 1)]
	var choice_label: String = picked.label if picked.label != "" else "<sin etiqueta>"

	# 5. Despachar según el tipo de input que requiera.
	if picked.needs_tile_input():
		_execute_choice_with_tile_input(event, picked, context, rng)
		GameLogger.debug("    [IA-Event] '%s' → choice '%s' (tile input)%s" % [event.id,
			choice_label, " | marcado unique" if event.unique else ""])
	elif picked.needs_player_input():
		_execute_choice_with_card_input(event, picked, context, rng)
		GameLogger.debug("    [IA-Event] '%s' → choice '%s' (card input)%s" % [event.id,
			choice_label, " | marcado unique" if event.unique else ""])
	else:
		# Camino normal (incluye skip, que tampoco tiene effects):
		# turn_event_manager.resolve hace pay + execute + marca unique.
		manager.resolve(event, picked, context)
		GameLogger.debug("    [IA-Event] '%s' → choice '%s'%s" % [event.id, choice_label,
			" | marcado unique" if event.unique else ""])


## Replica TurnEventPanel._on_tile_selected: paga el coste, ejecuta el
## tile_effect con la tile elegida random, ejecuta los demás effects que
## no requieran tile input, y marca el evento como unique.
static func _execute_choice_with_tile_input(event: TurnEvent, choice: TurnEventChoice,
		context: EventContext, rng: RandomNumberGenerator) -> void:
	if choice.cost != null:
		choice.cost.pay(context)

	var tile_effect: TurnEventEffect = choice.get_tile_effect()
	if tile_effect != null and tile_effect.has_method("get_eligible_tiles"):
		var eligible: Array = tile_effect.get_eligible_tiles(context)
		if not eligible.is_empty():
			var picked_tile = eligible[rng.randi_range(0, eligible.size() - 1)]
			if tile_effect.has_method("execute_with_tile"):
				tile_effect.execute_with_tile(picked_tile, context.stats)

	# Ejecutar los effects restantes (los que no son de tile input).
	for effect in choice.effects:
		if effect != null and not effect.needs_tile_input():
			effect.execute(context)

	_mark_unique_if_applicable(event, context.stats)


## Replica TurnEventPanel._on_card_selected: identifica el primer
## RemoveCardEventEffect en effects, pide candidatas, elige una al azar
## y ejecuta los effects pasándola.
static func _execute_choice_with_card_input(event: TurnEvent, choice: TurnEventChoice,
		context: EventContext, rng: RandomNumberGenerator) -> void:
	# Buscar el effect que requiere selección de carta.
	var candidates: Array[Card] = []
	for effect in choice.effects:
		if effect != null and effect.needs_player_input() and effect is RemoveCardEventEffect:
			candidates = effect.get_candidates(context.stats)
			break

	if candidates.is_empty():
		# Sin cartas candidatas: nada que elegir, marcamos unique y salimos.
		_mark_unique_if_applicable(event, context.stats)
		return

	var chosen_card := candidates[rng.randi_range(0, candidates.size() - 1)]

	# Ejecutar todos los effects, pasando la carta elegida a los que la pidan.
	for i in choice.effects.size():
		var effect: TurnEventEffect = choice.effects[i]
		if effect == null:
			continue
		if effect.needs_player_input():
			effect.execute(context, chosen_card)
		else:
			effect.execute(context)

	_mark_unique_if_applicable(event, context.stats)


# ============================================================
#  ShopEvent
# ============================================================

static func _resolve_shop_event(event: ShopEvent, stats: Stats,
		rng: RandomNumberGenerator) -> void:
	var config := event.generate_shop(stats)
	if config == null:
		return

	# Iteramos una copia para evitar problemas si purchase modifica la
	# lista (no debería, pero defensivo).
	for item in config.items.duplicate():
		if item == null:
			continue
		if not item.is_available():
			continue
		if not item.can_afford(stats.total_gold):
			continue
		if rng.randf() < SHOP_PURCHASE_CHANCE:
			item.purchase(stats)

	# Purga: omitida en v1. Tunear cuando se observe comportamiento real.


# ============================================================
#  Helpers
# ============================================================

static func _mark_unique_if_applicable(event: TurnEvent, stats: Stats) -> void:
	if event.unique and event.id not in stats.used_unique_events:
		stats.used_unique_events.append(event.id)
