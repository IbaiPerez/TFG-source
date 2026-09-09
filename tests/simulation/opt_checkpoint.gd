extends RefCounted
class_name OptCheckpoint

## Persistencia intermedia de la optimización de dos etapas.
##
## La corrida real dura ~32 h y no guardaba NADA hasta el final: un reinicio de
## Windows Update a las 3 de la mañana costó 18 h de cómputo y los 11 finalistas,
## que solo vivían en memoria. Esto lo arregla en dos puntos:
##
##   1. Al cerrar la etapa 1 se guardan los finalistas (un .tres cada uno, no un
##      vector: así no hay que suponer que sus campos fuera de OPTIMIZABLE_KEYS
##      son los del default).
##   2. Cada finalista de la etapa 2 se guarda EN CUANTO termina, no al final.
##
## Un reinicio cuesta entonces como mucho un finalista (~2,35 h) en vez de todo.
##
## LA HUELLA ES LO QUE HACE ESTO SEGURO. Reanudar mezclando dos configuraciones
## distintas —otro pool, otras semillas, otro espacio de búsqueda— produciría un
## informe que parece válido y no lo es, que en un TFG es peor que perder la
## corrida. Si la huella no coincide exactamente, el checkpoint se ignora.

## Parametrizable a propósito: un test que ejercite esto NO debe poder pisar el
## checkpoint de una corrida de 32 h que esté en marcha.
static var dir_base := "user://opt_2stage_ck"


static func _dir() -> String:
	return dir_base


static func _manifest_path() -> String:
	return "%s/manifest.json" % dir_base


## Cadena canónica de la configuración. Incluye el layout del espacio de búsqueda
## porque añadir o quitar una clave optimizable cambia lo que significan los pesos
## guardados, aunque las semillas sigan siendo las mismas.
static func huella(cfg: Dictionary) -> String:
	var claves := cfg.keys()
	claves.sort()
	var partes: Array[String] = []
	for k in claves:
		partes.append("%s=%s" % [k, cfg[k]])
	partes.append("keys=%d" % HeuristicWeightsSpec.OPTIMIZABLE_KEYS.size())
	return "|".join(partes)


static func _leer_manifest() -> Dictionary:
	if not FileAccess.file_exists(_manifest_path()):
		return {}
	var f := FileAccess.open(_manifest_path(), FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var d = JSON.parse_string(txt)
	return d if d is Dictionary else {}


## Devuelve el manifest solo si la huella coincide. Si existe pero es de otra
## configuración lo dice por consola: un checkpoint ignorado en silencio deja al
## que lanza la corrida creyendo que reanuda cuando en realidad empieza de cero.
static func manifest_valido(hue: String) -> Dictionary:
	var m := _leer_manifest()
	if m.is_empty():
		return {}
	if m.get("huella", "") != hue:
		print("[ck] checkpoint DESCARTADO: es de otra configuración.")
		print("[ck]   guardado: %s" % m.get("huella", "(sin huella)"))
		print("[ck]   actual:   %s" % hue)
		return {}
	return m


static func _escribir_manifest(m: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(_dir())
	var f := FileAccess.open(_manifest_path(), FileAccess.WRITE)
	if f == null:
		push_warning("[ck] no se pudo escribir %s" % _manifest_path())
		return
	f.store_string(JSON.stringify(m, "  "))
	f.close()


## Guarda los finalistas de la etapa 1 y las trazas, que hacen falta para el
## informe final aunque la etapa 1 no se vuelva a ejecutar.
static func guardar_etapa1(hue: String, finalistas: Array,
		sa_trace: Array, ga_trace: Array) -> void:
	DirAccess.make_dir_recursive_absolute(_dir())
	var nombres: Array[String] = []
	for f in finalistas:
		var ruta := "%s/f_%s.tres" % [_dir(), f["name"]]
		var err := ResourceSaver.save(f["w"], ruta)
		if err != OK:
			push_warning("[ck] fallo al guardar %s (err %d)" % [ruta, err])
			return
		nombres.append(f["name"])
	_escribir_manifest({
		"huella": hue, "finalistas": nombres,
		"sa_trace": sa_trace, "ga_trace": ga_trace, "filas": [],
	})
	print("[ck] etapa 1 guardada: %d finalistas en %s" % [
		nombres.size(), ProjectSettings.globalize_path(_dir())])


## Reconstruye los finalistas del checkpoint. Devuelve [] si falta cualquiera:
## media lista es peor que ninguna, porque el informe saldría incompleto sin avisar.
static func cargar_finalistas(m: Dictionary) -> Array:
	var out: Array = []
	for nombre in m.get("finalistas", []):
		var ruta := "%s/f_%s.tres" % [_dir(), nombre]
		# CACHE_MODE_IGNORE: queremos el CONTENIDO DEL FICHERO, no lo que Godot
		# tenga cacheado para esa ruta. Con la caché, un test que guarda y carga
		# en el mismo proceso pasaría devolviendo el objeto en memoria sin llegar
		# a comprobar que el .tres se escribió bien.
		var w = ResourceLoader.load(ruta, "", ResourceLoader.CACHE_MODE_IGNORE)
		if w == null:
			push_warning("[ck] falta %s; se ignora el checkpoint entero" % ruta)
			return []
		out.append({"name": nombre, "w": w})
	return out


## Añade una fila de la etapa 2 y reescribe el manifest. Reescribir entero cada
## vez cuesta milisegundos frente a las 2,35 h que cuesta la fila.
static func anadir_fila(fila: Dictionary) -> void:
	var m := _leer_manifest()
	if m.is_empty():
		return
	var filas: Array = m.get("filas", [])
	filas.append(fila)
	m["filas"] = filas
	_escribir_manifest(m)


static func borrar() -> void:
	if not DirAccess.dir_exists_absolute(_dir()):
		return
	var d := DirAccess.open(_dir())
	if d == null:
		return
	for nombre in d.get_files():
		d.remove(nombre)
	print("[ck] checkpoint borrado.")
