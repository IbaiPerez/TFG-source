extends RefCounted
class_name AIGamePhase

## Determina la fase de la partida según el estado económico y territorial,
## no según el turno, para que sea independiente del tamaño del mapa.
##
## EARLY  cuota < phase_early_share  Y  gpt < phase_early_gpt — ambas necesarias.
##        Un imperio pequeño pero rico (mapa mini con muchos edificios) ya ha
##        superado la fase inicial aunque lleve pocos turnos.
## LATE   cuota >= phase_late_share  O  gpt >= phase_late_gpt escalado al mapa —
##        una sola condición basta: mucho territorio o mucha producción es madurez.
## MID    todo lo demás.
##
## Los umbrales son PESOS (HeuristicWeights), no reglas: ninguna regla del juego
## depende de la fase, solo la IA la lee para elegir curva de urgencia y pesos. Con
## `w == null` se usan los pesos por defecto.

enum Phase { EARLY, MID, LATE }

## Fallback sin info de mapa (logs de simulación, contextos sin WorldMap): umbrales
## ABSOLUTOS de casillas. No son pesos a propósito — en partida real siempre se
## conoce el tamaño del mapa, así que esta rama no daría señal al optimizador.
const LATE_TILES_NO_MAP: int = 30
const EARLY_TILES_NO_MAP: int = 12


## Detecta la fase de la partida sobre el mundo vivo.
static func detect(stats: Stats, total_map_tiles: int = 0,
		w: HeuristicWeights = null) -> Phase:
	var tiles := stats.empire.controlled_tiles.size() if stats.empire != null else 0
	return detect_from(stats.gold_per_turn, tiles, total_map_tiles, w)


## Regla de fase, escrita UNA sola vez sobre primitivas. Cada mundo aporta solo
## CÓMO obtiene el gpt y el recuento de casillas (Stats vs AIRealState); la regla se
## comparte. `total_map_tiles == 0` → fallback con umbrales absolutos.
static func detect_from(gpt: int, tiles: int, total_map_tiles: int,
		w: HeuristicWeights = null) -> Phase:
	if w == null:
		w = HeuristicWeights.get_default()

	if total_map_tiles > 0:
		var share := float(tiles) / float(total_map_tiles)
		# El umbral de gpt de LATE escala linealmente con el tamaño del mapa: en un
		# mapa el doble de grande hace falta el doble de producción para que la
		# partida esté igual de avanzada.
		var late_gpt := w.phase_late_gpt * float(total_map_tiles) \
			/ float(GameBalance.DEFAULT_MAP_TILE_COUNT)
		if share >= w.phase_late_share or float(gpt) >= late_gpt:
			return Phase.LATE
		if share < w.phase_early_share and float(gpt) < w.phase_early_gpt:
			return Phase.EARLY
		return Phase.MID

	if float(gpt) >= w.phase_late_gpt or tiles >= LATE_TILES_NO_MAP:
		return Phase.LATE
	if float(gpt) < w.phase_early_gpt and tiles < EARLY_TILES_NO_MAP:
		return Phase.EARLY
	return Phase.MID
