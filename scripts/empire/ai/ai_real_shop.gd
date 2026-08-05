extends RefCounted
class_name AIRealShop

## Tienda sobre el snapshot: genera la oferta desde el pool (desbloqueadas +
## exclusivas), compra lo que la política considera valioso y purga las cartas
## más débiles. Espejo de ShopGenerator y de la rama de tienda de AIEventResolver.
##
## Lo que importa para la simulación es que el mazo refleje compras y purgas; la
## decisión exacta la toma AIShopPolicy, compartida con el mundo vivo.


static func _resolve_shop(event: ShopEvent, state: AIRealState, p_owner: int,
		emp: AIRealState.EmpireSnap, turn: int, rng: RandomNumberGenerator,
		w: HeuristicWeights = null) -> void:
	# Vista construida UNA vez para toda la resolución: `emp` es una
	# referencia, así que las compras/purgas que mutan el mazo se ven al instante.
	var view := SnapshotStateView.new(state, p_owner,
		w if w != null else HeuristicWeights.get_default())
	var special := event.shop_type == ShopEvent.ShopType.SPECIAL
	var num_cards := 3 if special else rng.randi_range(2, 3)
	var base_turn := 12 if special else 8
	var max_purges := rng.randi_range(2, 3) if special else 1

	# Pool de tienda completo (espejo de Stats.get_full_shop_pool).
	var pool: Array[UnlockedCardEntry] = []
	pool.append_array(emp.unlocked_card_pool)
	pool.append_array(emp.shop_exclusive_pool)

	# --- Compras ---
	for card in _weighted_pick_cards(pool, num_cards, turn, rng):
		var price := _price_for_card(card, turn, base_turn, rng)
		if emp.gold >= price and AIShopPolicy.should_buy(view, card):
			emp.gold -= price
			emp.deck.append(card.duplicate())

	# --- Purga ---
	var purge_cost := ShopGenerator._get_purge_cost(emp.total_purges_done)
	var purges_done := 0
	while not emp.deck.is_empty() and purges_done < max_purges and emp.gold >= purge_cost:
		var worst := AIShopPolicy.pick_weakest(view, emp.deck)
		if worst == null:
			break
		if AIDeckScorer.score_card_for_deck(view, worst) >= AIShopPolicy.purge_threshold(view):
			break   # todas las cartas son suficientemente valiosas
		emp.deck.erase(worst)
		emp.gold -= purge_cost
		emp.total_purges_done += 1
		purges_done += 1
		purge_cost = ShopGenerator._get_purge_cost(emp.total_purges_done)


## Precio de una carta (espejo de ShopGenerator._price_for_card/_scaled_price):
## base aleatorio por tipo escalado +2%/turno desde base_turn.
static func _price_for_card(card: Card, turn: int, base_turn: int,
		rng: RandomNumberGenerator) -> int:
	var base_min: int
	var base_max: int
	match card.type:
		Card.Type.SPECIAL, Card.Type.SINGLE_USE:
			base_min = ShopGenerator.SPECIAL_PRICE_MIN
			base_max = ShopGenerator.SPECIAL_PRICE_MAX
		_:
			base_min = ShopGenerator.BASIC_PRICE_MIN
			base_max = ShopGenerator.BASIC_PRICE_MAX
	var base := rng.randi_range(base_min, base_max)
	var turns_past := maxi(turn - base_turn, 0)
	return int(base * (1.0 + turns_past * ShopGenerator.PRICE_SCALE_PER_TURN))


## Selección ponderada de N cartas del pool sin repetición (espejo de
## ShopGenerator._weighted_pick_cards).
static func _weighted_pick_cards(pool: Array[UnlockedCardEntry], count: int,
		turn: int, rng: RandomNumberGenerator) -> Array[Card]:
	var result: Array[Card] = []
	if pool.is_empty():
		return result
	var remaining := pool.duplicate()
	for _i in range(mini(count, remaining.size())):
		var total := 0.0
		for entry in remaining:
			total += entry.get_weight(turn)
		if total <= 0.0:
			break
		var roll := rng.randf() * total
		var cumulative := 0.0
		for j in range(remaining.size()):
			cumulative += remaining[j].get_weight(turn)
			if roll <= cumulative:
				result.append(remaining[j].card)
				remaining.remove_at(j)
				break
	return result


