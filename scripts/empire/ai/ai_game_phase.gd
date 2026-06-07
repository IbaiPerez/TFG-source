extends RefCounted
class_name AIGamePhase

## Determina la fase de la partida según el número de turno.
## Usada por AIHeuristic para ajustar los pesos de cada dimensión.

enum Phase { EARLY, MID, LATE }

## T < 20  → Early  (expansión y economía básica)
## T < 50  → Mid    (desarrollo acelerado, edificios de upgrade)
## T >= 50 → Late   (conflicto militar decisivo)
static func detect(stats: Stats) -> Phase:
	var t := stats.turn_number
	if t < 20:
		return Phase.EARLY
	if t < 50:
		return Phase.MID
	return Phase.LATE
