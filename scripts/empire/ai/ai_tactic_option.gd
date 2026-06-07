extends AIPlayOption
class_name AITacticOption

## Bypass de TacticCard: la carta espera `targets[0] as BattleFrontVisual`
## en apply_effects (acoplamiento UI documentado en project_ai_changes.md).
## La IA no puede confiar en TacticCard.get_valid_targets, que lee el group
## "battle_front_visuals" del scene tree de forma frágil — en su lugar el
## AIOptionsBuilder enumera frentes desde battle_front_manager.active_fronts
## y aquí, al ejecutar, resolvemos el visual correspondiente justo a tiempo.
##
## Si no encontramos visual (caso límite: el frente existe en data pero el
## visual no se ha creado todavía o se ha liberado), descartamos la opción
## silenciosamente — la carta queda en mano hasta otra iteración o se
## descarta al final del turno.

var front: BattleFront


static func from_card(p_card: TacticCard, p_front: BattleFront) -> AITacticOption:
	var opt := AITacticOption.new()
	opt.card = p_card
	opt.front = p_front
	# targets se rellena en execute() resolviendo el visual.
	opt.targets = []
	opt.payload = {"front": p_front}
	return opt


func execute(ctx: AITurnContext) -> Card:
	if card == null or front == null:
		return null

	var visual := _resolve_visual_for(front)
	if visual != null:
		# Camino normal con escena 3D activa: targets[0] = BattleFrontVisual.
		targets = [visual]
		card.play(targets, ctx.stats)
		return card

	# Fallback headless (simulación, tests, turno IA sin escena 3D):
	# aplicar la táctica directamente sobre el BattleFront sin visual.
	# Emitimos card_played para que los listeners del bus respondan igual
	# que si la carta se hubiera jugado por el camino normal.
	Events.card_played.emit(card, ctx.stats)
	(card as TacticCard).apply_to_front(front, ctx.stats)
	return card


func describe() -> String:
	return "Tactic(front)"


## Como ancla del feedback visual usamos la tile defensora del frente
## (es donde "ocurre" el efecto desde el punto de vista del atacante).
## Si la IA es defensora, la atacante tiene el mismo sentido visual.
func anchor_tile() -> Tile:
	if front == null:
		return null
	return front.defender_tile if front.defender_tile != null else front.attacker_tile


## Busca en el scene tree el BattleFrontVisual cuyo battle_front == p_front.
## Returns null si no existe.
static func _resolve_visual_for(p_front: BattleFront) -> BattleFrontVisual:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var visuals := tree.get_nodes_in_group("battle_front_visuals")
	for v in visuals:
		if v is BattleFrontVisual and v.battle_front == p_front:
			return v
	return null
