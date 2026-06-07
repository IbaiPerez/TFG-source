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

static func detect(stats: Stats) -> Phase:
	var gpt := stats.gold_per_turn
	var tiles := stats.empire.controlled_tiles.size() if stats.empire != null else 0

	if gpt >= 350 or tiles >= 30:
		return Phase.LATE
	if gpt < 100 and tiles < 12:
		return Phase.EARLY
	return Phase.MID
