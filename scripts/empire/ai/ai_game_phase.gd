extends RefCounted
class_name AIGamePhase

## Determina la fase de la partida según el estado económico y territorial,
## no según el turno, para que sea independiente del tamaño del mapa.
##
## EARLY  gpt < 100  Y  tiles < 12   — ambas condiciones necesarias.
##        Un empire pequeño pero rico (mapa mini con muchos edificios)
##        ya ha superado la fase inicial aunque lleve pocos turnos.
## LATE   gpt ≥ 350  O  tiles ≥ 30   — una sola condición es suficiente.
##        Controlar mucho territorio o tener alta producción indica madurez.
## MID    todo lo demás.

enum Phase { EARLY, MID, LATE }

## Detecta la fase de la partida.
## Si total_map_tiles > 0, usa territory_share en lugar de umbrales absolutos
## (evita entrar en LATE con el 11% del mapa en mapas grandes).
## Si total_map_tiles == 0 usa el comportamiento legacy para compatibilidad
## con tests y contextos sin mapa (AIEventResolver).
static func detect(stats: Stats, total_map_tiles: int = 0) -> Phase:
	var tiles := stats.empire.controlled_tiles.size() if stats.empire != null else 0
	return detect_from(stats.gold_per_turn, tiles, total_map_tiles)


## Regla de fase, escrita UNA sola vez (§1.11) sobre primitivas. Antes estaba
## duplicada aquí y en AIRealEval.detect_phase con los mismos umbrales; solo
## difería en CÓMO obtiene cada mundo el gpt y el recuento de casillas (Stats vs
## AIRealState), así que el recorrido se queda en cada llamante y la regla se
## comparte. `total_map_tiles == 0` → fallback legacy con umbrales absolutos.
static func detect_from(gpt: int, tiles: int, total_map_tiles: int) -> Phase:
	if total_map_tiles > 0:
		var share := float(tiles) / float(total_map_tiles)
		# LATE: ≥30% del mapa O GPT escalado al tamaño del mapa.
		# El umbral GPT escala linealmente con el mapa (127 tiles = default r=6).
		var late_gpt := int(float(GameBalance.PHASE_LATE_GPT) * float(total_map_tiles) \
			/ float(GameBalance.DEFAULT_MAP_TILE_COUNT))
		if share >= GameBalance.PHASE_LATE_SHARE or gpt >= late_gpt:
			return Phase.LATE
		# EARLY: <8% del mapa Y economía inicial.
		if share < GameBalance.PHASE_EARLY_SHARE and gpt < GameBalance.PHASE_EARLY_GPT:
			return Phase.EARLY
		return Phase.MID

	# Fallback legacy (sin info del mapa):
	if gpt >= GameBalance.PHASE_LATE_GPT or tiles >= GameBalance.PHASE_LATE_TILES_LEGACY:
		return Phase.LATE
	if gpt < GameBalance.PHASE_EARLY_GPT and tiles < GameBalance.PHASE_EARLY_TILES_LEGACY:
		return Phase.EARLY
	return Phase.MID
