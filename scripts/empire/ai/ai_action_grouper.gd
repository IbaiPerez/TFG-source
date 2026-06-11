extends RefCounted
class_name AIActionGrouper

## Reduce el branching efectivo del árbol MCTS agrupando opciones equivalentes
## y devolviendo un representante canónico por grupo.
##
## Equivalencias:
##   Build:     mismo edificio en tiles con igual (bioma, recurso, tipo_location).
##              En un mapa de r=6, un mismo edificio puede aparecer en 20+ tiles
##              del mismo tipo → 1 representante por (edificio, contexto de tile).
##   OpenFront: mismo par (recurso_enemigo, bioma_origen).
##              Reducción de ~60 pares posibles a ~8-12 combinaciones canónicas.
##
## Tipos no agrupados (pocos o ya discriminantes):
##   Colonize, Recruit, Tactic, DrawCard, Recover, DirectBuild, ChangeLocation.

## Devuelve la lista reducida: un representante por grupo + todas las opciones
## no agrupables. El representante es el primer elemento encontrado de cada
## clave canónica. El caller puntúa los representantes con score_option.
static func group_and_pick(options: Array[AIPlayOption],
		_ctx: AITurnContext) -> Array[AIPlayOption]:
	var result: Array[AIPlayOption] = []
	var seen: Dictionary = {}  # group_key → AIPlayOption

	for opt in options:
		var key := _group_key(opt)
		if key.is_empty():
			result.append(opt)
			continue
		if key not in seen:
			seen[key] = opt
		# else: duplicado equivalente — descartado

	for key in seen:
		result.append(seen[key] as AIPlayOption)

	return result


## Clave canónica para opciones agrupables.
## Devuelve "" si la opción no es agrupable.
static func _group_key(opt: AIPlayOption) -> String:
	if opt is AIBuildOption:
		var bo := opt as AIBuildOption
		if bo.building == null or bo.targets.is_empty():
			return ""
		var tile := bo.targets[0] as Tile
		if tile == null:
			return ""
		var biome: int = tile.mesh_data.type if tile.mesh_data != null else -1
		var res: String = tile.natural_resource.name \
			if tile.natural_resource != null else "none"
		var loc: int = tile.location.type if tile.location != null else -1
		return "build|%s|%d|%s|%d" % [bo.building.name, biome, res, loc]

	if opt is AIOpenFrontOption:
		var ofo := opt as AIOpenFrontOption
		if ofo.enemy_tile == null or ofo.source_tile == null:
			return ""
		var enemy_res: String = ofo.enemy_tile.natural_resource.name \
			if ofo.enemy_tile.natural_resource != null else "none"
		var src_biome: int = ofo.source_tile.mesh_data.type \
			if ofo.source_tile.mesh_data != null else -1
		return "front|%s|%d" % [enemy_res, src_biome]

	return ""
