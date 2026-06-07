extends Card
class_name TacticCard

## Carta táctica que aplica un bonus de ataque y/o defensa a las tropas
## de uno o varios tipos asignadas a un frente de batalla.
##
## Modelo:
## - El bonus se evalúa **dinámicamente** cada turno: las tropas asignadas
##   más tarde también se benefician (la táctica "vive" en el frente).
## - El porcentual aplica al ATAQUE EFECTIVO (pasa por la matriz de
##   efectividad piedra-papel-tijera). La defensa se aplica sobre la base.
## - El bonus se escala por un único `biome_modifiers` que se interpreta
##   contra la tile contraria para la parte de ATK y la propia para la DEF.
##   El multiplicador queda **congelado** al jugar la carta y se guarda en
##   el bonus dict; cambios futuros del bioma de la tile no afectan.
## - Los multiplicadores de bioma siempre se clamp a [0, ∞): jugar la carta
##   nunca penaliza, sólo es desperdicio en biomas hostiles.
##
## Target: BATTLE_FRONT. Type: SPECIAL (no es single-use).


## Nombre legible para tooltip y UI ("Carga de Caballería").
@export var tactic_name: String = ""

## Tipos de tropa que reciben el bonus (Troop.TroopType).
@export var affected_troop_types: Array[int] = []

## Bonus porcentual sobre la base/efectividad de las tropas afectadas.
## % positivo aumenta el aporte ofensivo/defensivo de cada tropa afectada.
@export var attack_percent_per_type: float = 0.0
@export var defense_percent_per_type: float = 0.0

## Bonus plano por tropa afectada (reservado para cartas raras y poderosas).
## NO pasa por la matriz de efectividad.
@export var attack_per_troop: float = 0.0
@export var defense_per_troop: float = 0.0

## Multiplicador por bioma de la tile relevante.
## ATK se multiplica por el bioma de la tile **contraria** (donde atacas).
## DEF se multiplica por el bioma de la tile **propia** (donde defiendes).
## Biomas no listados → 1.0 (neutro). Valores negativos se clampan a 0.
## Diccionario {Tile.biome_type: float}.
@export var biome_modifiers: Dictionary = {}


func _build_tooltip() -> String:
	var lines: Array[String] = []
	var title: String = tactic_name if tactic_name != "" else "Táctica"
	lines.append("[center][b][color=#4A6A8A]%s[/color][/b][/center]" % title)

	# Lista los tipos afectados.
	if not affected_troop_types.is_empty():
		var labels: Array[String] = []
		for t in affected_troop_types:
			labels.append(Troop.type_label_for(t))
		lines.append("[center][color=#5a4838]Afecta a: %s[/color][/center]" % ", ".join(labels))

	# Bonus principales.
	var bonus_lines: Array[String] = []
	if attack_percent_per_type != 0.0:
		bonus_lines.append("+%.0f%% ATK" % attack_percent_per_type)
	if defense_percent_per_type != 0.0:
		bonus_lines.append("+%.0f%% DEF" % defense_percent_per_type)
	if attack_per_troop != 0.0:
		bonus_lines.append("+%.1f ATK plano por tropa" % attack_per_troop)
	if defense_per_troop != 0.0:
		bonus_lines.append("+%.1f DEF plano por tropa" % defense_per_troop)
	if not bonus_lines.is_empty():
		lines.append("[center][color=#cc3333]%s[/color][/center]" % " · ".join(bonus_lines))

	# Modificadores de bioma no neutros.
	if not biome_modifiers.is_empty():
		var biome_lines: Array[String] = []
		for biome in biome_modifiers.keys():
			var mod: float = float(biome_modifiers[biome])
			if absf(mod - 1.0) < 0.001:
				continue
			biome_lines.append("%s ×%.1f" % [_biome_label(biome), mod])
		if not biome_lines.is_empty():
			lines.append("[center][color=#3a5a3a]Bioma: %s[/color][/center]" % " · ".join(biome_lines))

	return "\n".join(lines)


func get_valid_targets(_stats: Stats) -> Array[Node]:
	var targets: Array[Node] = []
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return targets
	var visuals := tree.get_nodes_in_group("battle_front_visuals")
	for visual in visuals:
		if visual is BattleFrontVisual and not visual.battle_front.is_resolved:
			targets.append(visual)
	return targets


func is_valid_target(node: Node, _stats: Stats) -> bool:
	if node is BattleFrontVisual:
		return not node.battle_front.is_resolved
	return false


## Calcula el modificador de bioma para una tile concreta.
## Cualquier bioma no listado en `biome_modifiers` es neutro (×1.0).
## Valores negativos se clampan a 0 para que la carta nunca penalice.
func get_biome_modifier_for_tile(tile: Tile) -> float:
	if tile == null or tile.mesh_data == null:
		return 1.0
	var biome: int = tile.mesh_data.type
	if not biome_modifiers.has(biome):
		return 1.0
	return maxf(0.0, float(biome_modifiers[biome]))


func apply_effects(targets: Array[Node], stats: Stats) -> void:
	if targets.is_empty():
		return

	var visual: BattleFrontVisual = targets[0] as BattleFrontVisual
	if visual == null:
		return

	apply_to_front(visual.battle_front, stats)


## Variante headless: aplica la táctica directamente sobre un BattleFront
## sin necesitar BattleFrontVisual. La IA la usa cuando no existe el nodo
## visual (simulación, tests, turno IA sin escena 3D activa).
## El comportamiento es idéntico al de apply_effects con visual presente.
func apply_to_front(front: BattleFront, stats: Stats) -> void:
	if front == null or stats == null:
		return

	var side: StringName
	var enemy_tile: Tile
	var own_tile: Tile
	if front.attacker_empire == stats.empire:
		side = &"attacker"
		enemy_tile = front.defender_tile
		own_tile = front.attacker_tile
	else:
		side = &"defender"
		enemy_tile = front.attacker_tile
		own_tile = front.defender_tile

	# Política exclusiva: sólo una táctica activa por bando en cada frente.
	front.clear_tactics_for_side(side)

	var atk_biome_mod := get_biome_modifier_for_tile(enemy_tile)
	var def_biome_mod := get_biome_modifier_for_tile(own_tile)

	var bonus := TacticBonus.new()
	bonus.tactic_name              = tactic_name
	bonus.troop_types              = affected_troop_types.duplicate()
	bonus.attack_percent_per_type  = attack_percent_per_type
	bonus.defense_percent_per_type = defense_percent_per_type
	bonus.attack_per_troop         = attack_per_troop
	bonus.defense_per_troop        = defense_per_troop
	bonus.attack_biome_modifier    = atk_biome_mod
	bonus.defense_biome_modifier   = def_biome_mod
	front.add_bonus(side, bonus)

	Events.battle_front_bonus_applied.emit(front, side)


## Etiqueta legible de un bioma para el tooltip.
func _biome_label(biome: int) -> String:
	match biome:
		Tile.biome_type.Grassland: return "Pradera"
		Tile.biome_type.Desert: return "Desierto"
		Tile.biome_type.Tundra: return "Tundra"
		Tile.biome_type.Forest: return "Bosque"
		Tile.biome_type.Swamp: return "Pantano"
		Tile.biome_type.Mountain: return "Montaña"
		Tile.biome_type.Ocean: return "Océano"
		_: return "?"
