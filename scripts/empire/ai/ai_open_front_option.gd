extends AIPlayOption
class_name AIOpenFrontOption

## Bypass de OpenFrontCard: el flujo del jugador es de dos pasos
## (target enemigo, luego origen propio). La IA elige el par al enumerar
## y rellena los tres campos runtime de la carta.

var enemy_tile: Tile
var source_tile: Tile


static func from_card(p_card: OpenFrontCard, p_enemy: Tile, p_source: Tile,
		p_bfm: BattleFrontManager) -> AIOpenFrontOption:
	var opt := AIOpenFrontOption.new()
	opt.card = p_card
	opt.targets = [p_enemy]
	opt.enemy_tile = p_enemy
	opt.source_tile = p_source
	opt.payload = {"enemy_tile": p_enemy, "source_tile": p_source}
	# El runtime field battle_front_manager debe estar seteado para que
	# OpenFrontCard.apply_effects pueda llamar bfm.open_front(...).
	(p_card as OpenFrontCard).battle_front_manager = p_bfm
	return opt


func execute(ctx: AITurnContext) -> Card:
	if card == null or enemy_tile == null or source_tile == null:
		return null
	var of_card := card as OpenFrontCard
	of_card.target_enemy_tile = enemy_tile
	of_card.source_own_tile = source_tile
	# Defensivo: por si el bfm se perdió entre enumerate y execute.
	if of_card.battle_front_manager == null:
		of_card.battle_front_manager = ctx.battle_front_manager
	card.play(targets, ctx.stats)
	return card


func describe() -> String:
	return "OpenFront(→enemy)"


func anchor_tile() -> Tile:
	return enemy_tile
