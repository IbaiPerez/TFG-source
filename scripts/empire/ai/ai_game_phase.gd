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
	var gpt := stats.gold_per_turn
	var tiles := stats.empire.controlled_tiles.size() if stats.empire != null else 0

	if total_map_tiles > 0:
		var share := float(tiles) / float(total_map_tiles)
		# LATE: ≥30% del mapa O GPT escalado al tamaño del mapa.
		# El umbral GPT escala linealmente con el mapa (127 tiles = default r=6).
		var late_gpt := int(350.0 * float(total_map_tiles) / 127.0)
		if share >= 0.30 or gpt >= late_gpt:
			return Phase.LATE
		# EARLY: <8% del mapa Y economía inicial.
		if share < 0.08 and gpt < 100:
			return Phase.EARLY
		return Phase.MID

	# Fallback legacy (sin info del mapa):
	if gpt >= 350 or tiles >= 30:
		return Phase.LATE
	if gpt < 100 and tiles < 12:
		return Phase.EARLY
	return Phase.MID
