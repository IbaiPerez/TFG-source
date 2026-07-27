extends RefCounted
class_name AIOptionsBuilder

## Enumera todas las AIPlayOption legales para una carta dada en un contexto.
## Centraliza el dispatcher por tipo de carta para que el AIController no se
## ensucie con un match enorme.
##
## Cobertura:
##  - Fase 1 (cartas simples): Colonize, GenerateGold, CardDraw, DirectBuild.
##  - Fase 2 (cartas con menú/sub-decisión): BuildCard, UpgradeBuildingCard,
##    RecruitCard, OpenFrontCard.
##  - Fase 3 (cartas con acoplamiento UI o ciclo de vida especial):
##    TacticCard, RecoverCard.


## Devuelve la lista de opciones legales que la carta puede generar en este
## contexto. Lista vacía si la carta no es jugable ahora.
static func build_options(card: Card, ctx: AITurnContext) -> Array[AIPlayOption]:
	var options: Array[AIPlayOption] = []
	if card == null:
		return options

	# DirectBuildCard hereda de BuildCard; comprobar antes para que no caiga
	# por la rama de BuildCard genérica.
	if card is DirectBuildCard:
		_add_direct_build_options(card as DirectBuildCard, ctx, options)
		return options

	# UpgradeBuildingCard antes de BuildCard genérica, por si comparte
	# herencia en el futuro (hoy no, pero defensivo).
	if card is UpgradeBuildingCard:
		_add_upgrade_building_options(card as UpgradeBuildingCard, ctx, options)
		return options

	if card is BuildCard:
		_add_build_options(card as BuildCard, ctx, options)
		return options

	if card is ColonizeCard:
		_add_colonize_options(card as ColonizeCard, ctx, options)
		return options

	# ChangeLocationTypeCard cubre Urban Project (Village → Town) y
	# cualquier otra carta de urbanización futura. Sin este case la IA
	# nunca urbaniza, lo que bloquea las condiciones de unlock militar
	# (UrbanizedTilesCondition exige ≥1 Town).
	if card is ChangeLocationTypeCard:
		_add_change_location_type_options(card as ChangeLocationTypeCard, ctx, options)
		return options

	if card is GenerateGoldCard:
		_add_generate_gold_options(card as GenerateGoldCard, ctx, options)
		return options

	if card is CardDrawCard:
		_add_card_draw_options(card as CardDrawCard, ctx, options)
		return options

	if card is RecruitCard:
		_add_recruit_options(card as RecruitCard, ctx, options)
		return options

	if card is OpenFrontCard:
		_add_open_front_options(card as OpenFrontCard, ctx, options)
		return options

	if card is TacticCard:
		_add_tactic_options(card as TacticCard, ctx, options)
		return options

	if card is RecoverCard:
		_add_recover_options(card as RecoverCard, ctx, options)
		return options

	return options


# --- Constructores por tipo de carta --------------------------------------

static func _add_colonize_options(card: ColonizeCard,
		ctx: AITurnContext, options: Array[AIPlayOption]) -> void:
	# Legalidad unificada (§1.4): view.colonizable_tiles() (vivo = AdjacentRule, igual
	# que card.get_valid_targets; snapshot = recorrido). Interfaz común, mecanismo por mundo.
	for target in LiveStateView.new(ctx).colonizable_tiles():
		options.append(AIPlayOption.simple(card, [target]))


## ChangeLocationTypeCard (Urban Project y similares): 1 opción por
## tile válida según ChangeLocationTypeRule. La condición ya filtra:
##   - target.controller == empire
##   - location.type + 1 == card.location_type.type
##   - stats.food >= card.location_type.food_consumption
static func _add_change_location_type_options(card: ChangeLocationTypeCard,
		ctx: AITurnContext, options: Array[AIPlayOption]) -> void:
	# Legalidad unificada (§1.4): AILegality.change_location_targets (espejo de
	# ChangeLocationTypeRule). card.location_type null → target.type crashea igual que el
	# original (ChangeLocationTypeRule sin guarda); en la práctica siempre está definido.
	for target in AILegality.change_location_targets(LiveStateView.new(ctx), card.location_type):
		options.append(AIPlayOption.simple(card, [target]))


static func _add_direct_build_options(card: DirectBuildCard,
		ctx: AITurnContext, options: Array[AIPlayOption]) -> void:
	# DirectBuildCard ya lleva el building incrustado en buildings[0] y
	# get_valid_targets filtra por can_build + oro disponible.
	var valid := card.get_valid_targets(ctx.stats)
	for target in valid:
		options.append(AIPlayOption.simple(card, [target]))


static func _add_generate_gold_options(card: GenerateGoldCard,
		_ctx: AITurnContext, options: Array[AIPlayOption]) -> void:
	options.append(AIPlayOption.simple(card, []))


static func _add_card_draw_options(card: CardDrawCard,
		_ctx: AITurnContext, options: Array[AIPlayOption]) -> void:
	# Bypass obligatorio mediante AIDrawCardOption.
	options.append(AIDrawCardOption.from_card(card))


## BuildCard (genérica): producto cartesiano (tile válida × building).
## Una carta + N tiles + M buildings → hasta N*M opciones, filtradas por
## can_build y oro suficiente para CADA building.
static func _add_build_options(card: BuildCard,
		ctx: AITurnContext, options: Array[AIPlayOption]) -> void:
	# Legalidad unificada (§1.4): producto cartesiano tile×building con coste
	# efectivo + can_build. El vivo aporta card.buildings como fuente de edificios.
	for t in AILegality.build_targets(LiveStateView.new(ctx), card.buildings):
		options.append(AIBuildOption.from_card(card, t["tile"] as Tile, t["building"]))


## UpgradeBuildingCard: enumera (tile × old_building × new_building) legal.
## Usa Tile.can_upgrade y Building.can_be_upgraded; filtra por oro.
static func _add_upgrade_building_options(card: UpgradeBuildingCard,
		ctx: AITurnContext, options: Array[AIPlayOption]) -> void:
	# Legalidad unificada (§1.4): (tile × old × new) con guarda can_be_upgraded +
	# coste efectivo + can_upgrade.
	for t in AILegality.upgrade_targets(LiveStateView.new(ctx)):
		options.append(AIUpgradeBuildingOption.from_card(
			card, t["tile"] as Tile, t["old"], t["new"]))


## RecruitCard: 1 opción por troop disponible y asequible.
##
## Una sola jugada de la carta recluta N = `card.get_effective_troops_per_play`
## tropas (con Cuartel/Academia el bonus crece). Tres filtros:
##
##   1. `can_afford_troop`: la tropa pasa el gating de produccion
##      (Opcion 3b — no se puede reclutar si gpt o food no sostienen el
##      mantenimiento). Es el mismo filtro que aplica `recruit_troop` en
##      runtime, asi que evita enumerar opciones que luego fallarian.
##   2. Coste one-shot total `per_play * recruitment_cost_gold` ≤ total_gold.
##      Si la IA elige Recruit con oro solo para 1 tropa de 3, ejecutaria
##      `recruit_troop` solo la primera vez y dejaria las 2 restantes sin
##      hacer — peor uso del turno.
static func _add_recruit_options(card: RecruitCard,
		ctx: AITurnContext, options: Array[AIPlayOption]) -> void:
	# Legalidad unificada (§1.4): AILegality.recruit_targets sobre la vista viva.
	for t in AILegality.recruit_targets(LiveStateView.new(ctx), card):
		options.append(AIRecruitOption.from_card(card, t["troop"]))


## TacticCard: 1 opción por cada frente activo donde la IA participa.
## Adapter local que evita usar TacticCard.get_valid_targets (acoplado al
## scene tree de visuales). El AITacticOption resuelve el visual al ejecutar.
static func _add_tactic_options(card: TacticCard,
		ctx: AITurnContext, options: Array[AIPlayOption]) -> void:
	# Legalidad unificada (§1.4): view.tactic_targets() (frentes activos donde participamos).
	for front in LiveStateView.new(ctx).tactic_targets():
		options.append(AITacticOption.from_card(card, front))


## RecoverCard: 1 opción por cada carta en played_pile. Sin filtros: si
## hay cartas que recuperar, todas son candidatas.
static func _add_recover_options(card: RecoverCard,
		ctx: AITurnContext, options: Array[AIPlayOption]) -> void:
	if ctx.stats.played_pile == null:
		return
	for played in ctx.stats.played_pile.cards:
		if played == null:
			continue
		options.append(AIRecoverOption.from_card(card, played))


## OpenFrontCard: 1 opción por par (tile_enemiga × tile_propia adyacente).
## Antes de enumerar, inyectamos battle_front_manager en la carta para que
## EnemyAdjacentRule pueda filtrar tiles ya en frente.
## También respetamos el límite de frentes simultáneos del bfm.
static func _add_open_front_options(card: OpenFrontCard,
		ctx: AITurnContext, options: Array[AIPlayOption]) -> void:
	# Legalidad unificada (§1.4): view.open_front_pairs(card) (pares origen propio ×
	# destino enemigo). El mundo vivo inyecta el bfm en la carta y usa EnemyAdjacentRule.
	for pair in LiveStateView.new(ctx).open_front_pairs(card):
		options.append(AIOpenFrontOption.from_card(
			card, pair["def"] as Tile, pair["source"] as Tile, ctx.battle_front_manager))
