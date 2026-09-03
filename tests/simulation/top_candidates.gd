extends RefCounted
class_name TopCandidates

## Los K mejores candidatos DISTINTOS que ha visto un optimizador.
##
## Sustituye al `best_weights` único que devolvían SA y GA. El motivo es de
## método, no de comodidad: quedarse con el argmax del pool de búsqueda ES el paso
## de sobreajuste. El mejor contra los rivales de la etapa 1 es, por construcción,
## el más afinado a ESOS rivales; si dos candidatos empatan y uno es robusto y el
## otro está especializado, el argmax se queda con el especializado y la etapa 2
## ya no puede arbitrar, porque nunca lo ve.
##
## Pasando los K mejores, la decisión final la toma el pool held-out.
##
## Deduplica por vector: la élite del GA pasa intacta entre generaciones y SA
## revisita puntos, así que sin esto el top-K serían cinco copias del mismo.


var k: int = 5

var _entradas: Array = []      ## [{fitness, weights, clave}] ordenado desc
var _claves: Dictionary = {}   ## clave -> índice, para deduplicar


func _init(p_k: int = 5) -> void:
	k = maxi(1, p_k)


## Ofrece un candidato. Se queda si entra en el top-K y no es un duplicado.
func offer(w: HeuristicWeights, fitness: float, clave: String) -> void:
	if _claves.has(clave):
		return
	if _entradas.size() >= k and fitness <= float(_entradas[-1]["fitness"]):
		return
	_claves[clave] = true
	_entradas.append({"fitness": fitness, "weights": w.clone(), "clave": clave})
	_entradas.sort_custom(func(a, b): return float(a["fitness"]) > float(b["fitness"]))
	while _entradas.size() > k:
		var fuera = _entradas.pop_back()
		_claves.erase(fuera["clave"])


func best() -> HeuristicWeights:
	return _entradas[0]["weights"] if not _entradas.is_empty() else null


func best_fitness() -> float:
	return float(_entradas[0]["fitness"]) if not _entradas.is_empty() else -1.0


func size() -> int:
	return _entradas.size()


## Los K mejores, de mejor a peor: [{fitness, weights}].
func to_array() -> Array:
	var out: Array = []
	for e in _entradas:
		out.append({"fitness": e["fitness"], "weights": e["weights"]})
	return out
