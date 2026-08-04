extends RefCounted
class_name ConquestResolver

## Regla de CONQUISTA: qué edificios se destruyen al tomar una casilla enemiga.
## Escrita una sola vez y usada por los dos mundos —
## `BattleFrontManager._apply_conquest` (juego) y `AIRealSimulator._apply_conquest`
## (simulación del MCTS)— para que la IA prevea exactamente lo que va a ocurrir.
##
## CRITERIO: se destruye el edificio MÁS CARO de la casilla (por `construction_cost`).
##
## Antes la regla estaba a medio definir: un `TODO` con un bucle vacío que debía
## localizar "los edificios exclusivos del imperio perdedor" —algo que Building ni
## siquiera modela— y, como placeholder, se destruía el ÚLTIMO del array. Eso hacía
## que el resultado dependiera del ORDEN DE CONSTRUCCIÓN, que es arbitrario y no
## significa nada para el jugador: construir el mercado antes o después del granero
## cambiaba qué se perdía al ser conquistado.
##
## El coste es la mejor señal de valor disponible sin añadir datos nuevos: la
## conquista arrasa lo más costoso, así que perder una casilla desarrollada duele en
## proporción a lo invertido en ella, y el defensor puede razonar sobre el riesgo.
##
## Devuelve una LISTA (hoy siempre de 0 o 1 elementos) para que una regla futura
## —un porcentaje, o los edificios exclusivos si algún día Building los modela— no
## obligue a cambiar a los llamantes.


## Edificios que la conquista destruye, de entre los de la casilla tomada.
## `buildings` es `Array[Building]` en ambos mundos (Building es clase compartida),
## así que la función vale tal cual para el juego y para el snapshot.
static func buildings_to_destroy(buildings: Array[Building]) -> Array[Building]:
	var result: Array[Building] = []
	var most_valuable: Building = null
	for b in buildings:
		if b == null:
			continue
		# `>` estricto: ante empate de coste gana el PRIMERO del array. Ambos mundos
		# recorren la misma lista en el mismo orden (el snapshot la duplica), así que
		# el desempate es idéntico en los dos.
		if most_valuable == null or b.construction_cost > most_valuable.construction_cost:
			most_valuable = b
	if most_valuable != null:
		result.append(most_valuable)
	return result
