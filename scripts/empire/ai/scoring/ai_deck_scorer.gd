extends RefCounted
class_name AIDeckScorer

## Valoración de una carta para el mazo, escrita UNA sola vez (refactor C6 §1.6.5),
## contra el puerto AIStateView. Antes vivía DUPLICADA:
##   - AIHeuristic.score_card_for_deck   → fórmula COMPLETA (pesos + fase + urgencias
##                                          + recorridos de tiles: colonizable/upgradeable/
##                                          slots/change_location/recuperables).
##   - AIRealEvents._score_card_for_deck → APROXIMACIÓN-SUELO (magnitudes planas 11/12/
##                                          10/9…, sin fase ni recorridos de tiles).
##
## Paso (a) — byte-idéntico: SOLO el mundo VIVO delega aquí (AIHeuristic.score_card_for_deck
## pasa a ser un wrapper que construye LiveStateView; LiveStateView reproduce EXACTAMENTE
## los helpers de AIHeuristic, incluidas las urgencias cacheadas de la decisión). El
## SNAPSHOT conmuta en el paso (b) [CAMBIA COMPORTAMIENTO]: adopta esta fórmula completa
## vía SnapshotStateView, borrando su aproximación-suelo.

static func score_card_for_deck(view: AIStateView, card: Card) -> float:
	if card == null:
		return 0.0
	var w := view.weights()
	var gu := view.gold_urgency()
	var fu := view.food_urgency()
	var mu := view.military_urgency()
	var exp := view.expansion_factor()   # presión expansionista: tiles adj. libres
	# Rendimiento decreciente por copias: la n-ésima copia del mismo tipo vale menos
	# aunque el estado del mapa la favorezca. Se multiplica en todos los returns.
	var sat := clampf(1.0 / float(view.same_type_card_count(card)), w.type_sat_min, 1.0)

	if card is ColonizeCard:
		# Sin tiles colonizables: carta inútil, eliminar primero.
		var avail := view.colonizable_count()
		if avail == 0:
			return w.scd_colonize_empty * sat
		return lerpf(w.scd_colonize_lo, w.scd_colonize_hi, exp) * sat

	if card is DirectBuildCard:
		var db := card as DirectBuildCard
		if not db.buildings.is_empty() and db.buildings[0] != null:
			var b := db.buildings[0]
			return (b.gold_produced * w.scd_db_gold * gu \
				  + b.food_produced * w.scd_db_food * fu \
				  + b.flat_defense_bonus * w.scd_db_defense * mu) * sat
		return w.scd_db_default * sat

	if card is UpgradeBuildingCard:
		var upgrades := view.upgradeable_count()
		if upgrades == 0:
			return w.scd_upg_none * sat
		return lerpf(w.scd_upg_lo, w.scd_upg_hi, clampf(float(upgrades) / w.scd_upg_ref, 0.0, 1.0)) * sat

	# BuildCard genérica: valioso solo si hay huecos de edificio libres.
	if card is BuildCard:
		var slots := view.buildable_slots()
		if slots == 0:
			return w.scd_build_none * sat
		return lerpf(w.scd_build_lo, w.scd_build_hi, clampf(float(slots) / w.scd_build_ref, 0.0, 1.0)) * sat

	if card is RecruitCard:
		# troop_sat: rendimiento decreciente por pool grande (diferente a sat por copias).
		var troop_sat := 1.0 / (1.0 + view.troop_pool().size() * w.recruit_saturation_k)
		return (w.scd_recruit_base + mu * w.scd_recruit_mu) * troop_sat * sat

	if card is OpenFrontCard:
		return (w.scd_openfront_base + mu * w.scd_openfront_mu) * sat

	if card is TacticCard:
		return (w.scd_tactic_base + mu * w.scd_tactic_mu) * sat

	if card is ChangeLocationTypeCard:
		var clt_card := card as ChangeLocationTypeCard
		if clt_card.location_type == null:
			return w.scd_clt_invalid * sat
		var valid_count := view.change_location_target_count(clt_card.location_type.type)
		if valid_count == 0:
			return w.scd_clt_invalid * sat
		var tile_factor := clampf(float(valid_count) / w.scd_clt_ref, 0.0, 1.0)
		if view.food() < clt_card.location_type.food_consumption:
			return lerpf(w.scd_clt_poor_lo, w.scd_clt_poor_hi, tile_factor) * sat
		return lerpf(w.scd_clt_lo, w.scd_clt_hi, tile_factor) * sat

	if card is CardDrawCard:
		var deck_ratio := clampf(float(view.deck_size()) / w.scd_draw_ref, 0.0, 1.0)
		return lerpf(w.scd_draw_lo, w.scd_draw_hi, deck_ratio) * sat

	if card is RecoverCard:
		var best_score := 0.0
		for c in view.recoverable_cards():
			if c == null or c is RecoverCard:
				continue
			var s := score_card_for_deck(view, c)
			if s > best_score:
				best_score = s
		# scd_recover_frac del valor de la mejor carta recuperable, entre lo y hi.
		return clampf(best_score * w.scd_recover_frac, w.scd_recover_lo, w.scd_recover_hi) * sat

	if card is GenerateGoldCard:
		return (card as GenerateGoldCard).amount * w.scd_gold_weight * gu * sat

	return w.scd_unknown * sat  # tipo desconocido: valor neutro
