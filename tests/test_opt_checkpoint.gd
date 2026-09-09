extends GutTest

## Guardas de OptCheckpoint. Lo que se protege aquí no es "que funcione", es que
## un checkpoint MEDIO VÁLIDO no pueda colarse en un informe del TFG: reanudar
## mezclando dos configuraciones produce números que parecen buenos y no lo son.
##
## Usa su propio directorio: la suite NO puede pisar el checkpoint de una corrida
## de 32 h que esté en marcha.

const DIR_TEST := "user://test_opt_ck"

var _dir_previo: String


func before_each() -> void:
	_dir_previo = OptCheckpoint.dir_base
	OptCheckpoint.dir_base = DIR_TEST
	OptCheckpoint.borrar()


func after_each() -> void:
	OptCheckpoint.borrar()
	OptCheckpoint.dir_base = _dir_previo


## Pesos reconocibles: se desplaza cada clave optimizable una fracción distinta
## de su valor por defecto, para que un round-trip que devolviera los defaults
## (o que mezclara dos finalistas) se note en CUALQUIER clave, no solo en una.
func _pesos_marcados(semilla: int) -> HeuristicWeights:
	var w := HeuristicWeights.new()
	var i := 0
	for k in HeuristicWeightsSpec.OPTIMIZABLE_KEYS:
		var base: float = float(w.get(k))
		w.set(k, base + float(semilla) + float(i) * 0.125)
		i += 1
	return w


func _finalistas() -> Array:
	return [
		{"name": "baseline", "w": HeuristicWeights.new()},
		{"name": "sa_1", "w": _pesos_marcados(1)},
		{"name": "ga_1", "w": _pesos_marcados(2)},
	]


func test_el_round_trip_conserva_todos_los_pesos() -> void:
	var hue := OptCheckpoint.huella({"a": 1})
	var originales := _finalistas()
	OptCheckpoint.guardar_etapa1(hue, originales, [], [])

	var cargados := OptCheckpoint.cargar_finalistas(
		OptCheckpoint.manifest_valido(hue))
	assert_eq(cargados.size(), originales.size(), "Deben volver todos los finalistas")

	for idx in range(originales.size()):
		assert_eq(cargados[idx]["name"], originales[idx]["name"],
			"El orden de los finalistas debe conservarse")
		var esperado: HeuristicWeights = originales[idx]["w"]
		var leido: HeuristicWeights = cargados[idx]["w"]
		for k in HeuristicWeightsSpec.OPTIMIZABLE_KEYS:
			assert_almost_eq(float(leido.get(k)), float(esperado.get(k)), 1e-4,
				"%s.%s debe sobrevivir al round-trip" % [originales[idx]["name"], k])


func test_una_huella_distinta_descarta_el_checkpoint() -> void:
	OptCheckpoint.guardar_etapa1(OptCheckpoint.huella({"riv": 19}), _finalistas(), [], [])

	var otra := OptCheckpoint.huella({"riv": 12})
	assert_eq(OptCheckpoint.manifest_valido(otra), {},
		"Un checkpoint de otra configuración no se puede reanudar")


## El espacio de búsqueda entra en la huella aunque no sea un parámetro de la
## corrida: si cambia el número de claves optimizables, los pesos guardados
## significan otra cosa y el vector deja de casar.
func test_la_huella_incluye_el_espacio_de_busqueda() -> void:
	var hue := OptCheckpoint.huella({"riv": 19})
	assert_string_contains(hue, "keys=%d" % HeuristicWeightsSpec.OPTIMIZABLE_KEYS.size())


func test_si_falta_un_tres_se_descarta_el_checkpoint_entero() -> void:
	var hue := OptCheckpoint.huella({"a": 1})
	OptCheckpoint.guardar_etapa1(hue, _finalistas(), [], [])

	var d := DirAccess.open(DIR_TEST)
	assert_not_null(d, "El directorio del checkpoint debe existir")
	assert_eq(d.remove("f_sa_1.tres"), OK, "Debe poder borrarse el .tres de sa_1")

	assert_eq(OptCheckpoint.cargar_finalistas(OptCheckpoint.manifest_valido(hue)), [],
		"Media lista es peor que ninguna: debe descartarse entera")

	# El fichero que falta hace que el motor grite por consola. Es justo lo que
	# este test provoca a propósito, así que se declaran esperados; si no, GUT
	# los cuenta como errores inesperados y falla el caso que sí pasó.
	for e in get_errors():
		e.handled = true


func test_las_filas_se_acumulan_una_a_una() -> void:
	var hue := OptCheckpoint.huella({"a": 1})
	OptCheckpoint.guardar_etapa1(hue, _finalistas(), [], [])

	OptCheckpoint.anadir_fila({"name": "baseline", "winrate": 0.5})
	OptCheckpoint.anadir_fila({"name": "sa_1", "winrate": 0.7})

	var filas: Array = OptCheckpoint.manifest_valido(hue).get("filas", [])
	assert_eq(filas.size(), 2, "Cada finalista terminado deja su fila")
	assert_eq(filas[1]["name"], "sa_1", "Se conservan en orden de terminación")


## Sin manifest no hay dónde acumular: añadir una fila no debe crear uno huérfano
## que luego se reanude sin finalistas.
func test_sin_manifest_no_se_crea_uno_a_medias() -> void:
	OptCheckpoint.anadir_fila({"name": "suelta", "winrate": 0.9})
	assert_eq(OptCheckpoint.manifest_valido(OptCheckpoint.huella({"a": 1})), {},
		"No debe aparecer un checkpoint de la nada")
