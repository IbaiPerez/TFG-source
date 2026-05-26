extends RefCounted
class_name EmpireCreator

## Selector stateless de tiles iniciales. Sólo emite eventos globales
## (`Events.change_tile_controller`), no tiene señales propias ni vida en
## el SceneTree, así que es RefCounted para autoliberarse y no acumular
## nodos huérfanos en tests / generaciones repetidas.

## Numero maximo de pares (player, ia) que probamos antes de caer al
## fallback. Cota dura para evitar bucles largos en mapas grandes; en
## practica con N candidatas no tiene sentido probar mas de N players
## distintos, asi que el bucle real es `min(MAX_PLACEMENT_ATTEMPTS, N)`.
const MAX_PLACEMENT_ATTEMPTS: int = 16

var settings : GenerationSettings
var possible_tiles : Array[Tile] = []

func init_creator(_in_settings:GenerationSettings):
	settings = _in_settings

## Coloca al jugador y al imperio rival en tiles iniciales validas.
##
## Contrato:
##   - Al entrar, RESETEAMOS los controlled_tiles de todos los candidatos
##     (player_empire + todos los settings.empires). Asi una partida nueva
##     siempre empieza desde cero, sin arrastrar referencias colgantes a
##     tiles freed de partidas anteriores (clave en harnesses headless
##     que reciclan los recursos Empire entre runs).
##   - Si la generacion abortara (mapa degenerado), los imperios quedan
##     vacios — nunca con basura.
##   - En el caso normal de exito, se emite `change_tile_controller` para
##     cada imperio con su tile inicial.
func create_empires():
	# Reset defensivo: limpia el estado de cualquier run anterior. Antes
	# se reseteaba solo player_empire (y la IA dependia de un reset
	# diferido dentro del path de exito), lo que dejaba a las IA empires
	# con refs a tiles freed cuando se reusan los recursos entre runs.
	settings.player_empire.reset_controlled_tiles()
	for e in settings.empires:
		if e != null:
			e.reset_controlled_tiles()

	# Tiles candidatas: del anillo "buffer" (cinturón intermedio del mapa),
	# no oceanicas y con produccion de comida positiva.
	for tile in WorldMap.map:
		if tile.pos_data.buffer and tile.biome != "Ocean" and tile.food_production > 0:
			possible_tiles.append(tile)

	if possible_tiles.is_empty():
		push_error("[EmpireCreator] possible_tiles vacio: el mapa no tiene tiles buffer terrestres con food_production > 0. No se colocan imperios.")
		return

	# Buscamos un par (player, ia) que cumpla `ring_distance > radius`.
	# Si tras MAX_PLACEMENT_ATTEMPTS intentos con players distintos no lo
	# logramos, caemos al fallback (par mas separado entre las candidatas).
	# Si ni siquiera el fallback existe (1 sola candidata), abortamos sin
	# emitir nada — los imperios ya estan reseteados por la pasada de arriba.
	var pair := _find_placement_pair()
	if pair.is_empty():
		push_error("[EmpireCreator] No se pudo elegir un par (player, ia) valido: %d candidata(s), radius=%d. No se colocan imperios." % [
			possible_tiles.size(), settings.radius
		])
		return

	var player_tile: Tile = pair["player"]
	var ia_tile: Tile = pair["ia"]
	var ia_empire: Empire = settings.empires.pick_random()

	Events.change_tile_controller.emit(player_tile, settings.player_empire)
	Events.change_tile_controller.emit(ia_tile, ia_empire)


## Devuelve un diccionario `{ "player": Tile, "ia": Tile }` con el par
## elegido, o `{}` si no es posible colocar dos imperios (mapa con < 2
## candidatas).
##
## Estrategia:
##   1. Estricta: hasta MAX_PLACEMENT_ATTEMPTS intentos con un player
##      aleatorio distinto cada vez. Para cada intento, busca todas las
##      candidatas a `ring_distance > settings.radius` y elige una al
##      azar.
##   2. Fallback: si ningun intento encuentra una pareja estricta, busca
##      el par con maxima distancia entre todas las candidatas (puede que
##      <= radius). Emite push_warning para que sea visible en consola.
##   3. Si possible_tiles tiene < 2 elementos, devuelve `{}`.
func _find_placement_pair() -> Dictionary:
	if possible_tiles.size() < 2:
		return {}

	# Pool barajado: evita probar siempre el mismo player primero si la
	# RNG global esta en un estado parecido entre runs.
	var pool: Array[Tile] = possible_tiles.duplicate()
	pool.shuffle()
	var attempts: int = mini(MAX_PLACEMENT_ATTEMPTS, pool.size())

	for i in range(attempts):
		var candidate_player: Tile = pool[i]
		var far_enough: Array[Tile] = []
		for t in possible_tiles:
			if t == candidate_player:
				continue
			if _ring_distance(candidate_player, t) > settings.radius:
				far_enough.append(t)
		if not far_enough.is_empty():
			return {
				"player": candidate_player,
				"ia": far_enough.pick_random()
			}

	# Ningun intento estricto encontro pareja. Cogemos el par mas
	# separado posible entre cualquier dos candidatas. En mapas pequenos
	# con radius alto, esto puede dejar a los imperios cerca, pero al
	# menos garantiza que ambos quedan colocados.
	return _build_fallback_pair()


## Busca el par de candidatas con maxima `ring_distance`. Asume que
## `possible_tiles.size() >= 2` (el caller lo garantiza).
func _build_fallback_pair() -> Dictionary:
	var best_pair := {}
	var best_dist: int = -1
	for p in possible_tiles:
		for t in possible_tiles:
			if t == p:
				continue
			var d: int = _ring_distance(p, t)
			if d > best_dist:
				best_dist = d
				best_pair = { "player": p, "ia": t }

	if not best_pair.is_empty():
		push_warning("[EmpireCreator] Ningun par cumplio ring_distance > radius=%d tras retries; uso fallback con distancia maxima=%d." % [
			settings.radius, best_dist
		])
	return best_pair


## Distancia de anillo (hex distance / Chebyshev en coordenadas cube).
## Extraido para tests y para que la formula no quede acoplada al
## algoritmo de seleccion.
static func _ring_distance(a:Tile, b:Tile) -> int:
	var ax:int = a.pos_data.grid_position.x
	var ay:int = a.pos_data.grid_position.y
	var bx:int = b.pos_data.grid_position.x
	var by:int = b.pos_data.grid_position.y
	var c_diff:int = abs(ax - bx)
	var r_diff:int = abs(ay - by)
	var delta:int = abs((ax + ay) - (bx + by))
	return max(c_diff, r_diff, delta)
