extends RefCounted
class_name VictoryRules

## Regla de VICTORIA, escrita una sola vez y usada por los dos mundos:
## `TurnManager._check_victory` (juego) y `GameSimHarness._check_victory_in_sim`
## (simulaciones). Antes el arnés llevaba una copia con el umbral hardcodeado a
## 0.70: si se tocaba `GameBalance.VICTORY_TILE_SHARE`, las simulaciones medían
## otro juego sin que nada avisara.
##
## Dos condiciones, en este orden:
##   · ELIMINACIÓN: solo un imperio conserva casillas.
##   · DOMINACIÓN: algún imperio controla al menos `VICTORY_TILE_SHARE` del mapa.
##
## Devuelve `{"winner": Empire, "condition": "elimination" | "domination"}`, o un
## diccionario vacío si la partida sigue.

const ELIMINATION := "elimination"
const DOMINATION := "domination"


static func check(empires: Array[Empire], total_tiles: int) -> Dictionary:
	if total_tiles <= 0:
		return {}

	var alive: Array[Empire] = []
	for emp in empires:
		if emp != null and emp.controlled_tiles.size() > 0:
			alive.append(emp)
	if alive.size() == 1:
		return {"winner": alive[0], "condition": ELIMINATION}

	for emp in empires:
		if emp == null:
			continue
		var share := float(emp.controlled_tiles.size()) / float(total_tiles)
		if share >= GameBalance.VICTORY_TILE_SHARE:
			return {"winner": emp, "condition": DOMINATION}

	return {}
