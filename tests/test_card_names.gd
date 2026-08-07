extends GutTest

## Guarda de los nombres visibles de carta.
##
## Antes no existian: la UI mostraba el `id` INTERNO, asi que en la Ofrenda de
## Cartas se leia "Recibes una copia de Colonize" jugando en castellano, y en el
## AI Log salian cosas como "Build Escuela de Planificacion", sin tildes y a
## medio traducir.
##
## Estos tests recorren TODAS las cartas del juego, no una lista escrita a mano:
## una carta nueva sin `name_key` hace fallar la suite en vez de aparecer con su
## id crudo en pantalla.


func _rutas_de_carta() -> Array[String]:
	var out: Array[String] = []
	_buscar("res://resources/cards", out)
	return out


func _buscar(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var e := dir.get_next()
	while e != "":
		var full := dir_path.path_join(e)
		if dir.current_is_dir():
			_buscar(full, out)
		elif e.ends_with(".tres"):
			out.append(full)
		e = dir.get_next()
	dir.list_dir_end()


func test_todas_las_cartas_declaran_name_key() -> void:
	var rutas := _rutas_de_carta()
	assert_gt(rutas.size(), 15, "el barrido debe encontrar las cartas del juego")

	var sin_clave: Array[String] = []
	for ruta in rutas:
		var card := load(ruta) as Card
		if card == null:
			continue
		if card.name_key.is_empty():
			sin_clave.append("%s (id '%s')" % [ruta.get_file(), card.id])
	assert_eq(sin_clave, [] as Array[String],
		"estas cartas mostrarian su id interno al jugador: %s" % str(sin_clave))


func test_los_nombres_estan_traducidos_en_ambos_idiomas() -> void:
	# Una clave sin fila en el CSV se muestra como la clave misma
	# (CARD_RECRUIT_NAME), que es un fallo visible y silencioso.
	var previo := TranslationServer.get_locale()
	for locale in ["es", "en"]:
		TranslationServer.set_locale(locale)
		for ruta in _rutas_de_carta():
			var card := load(ruta) as Card
			if card == null or card.name_key.is_empty():
				continue
			assert_ne(TranslationServer.translate(card.name_key), card.name_key,
				"%s sin traducir en '%s'" % [card.name_key, locale])
	TranslationServer.set_locale(previo)


func test_el_nombre_visible_no_es_el_id() -> void:
	# El sintoma exacto que se reporto: leer el identificador interno en pantalla.
	var previo := TranslationServer.get_locale()
	TranslationServer.set_locale("es")
	for ruta in _rutas_de_carta():
		var card := load(ruta) as Card
		if card == null:
			continue
		assert_ne(card.get_display_name(), card.id,
			"%s muestra su id ('%s') en vez de un nombre traducido" % [ruta.get_file(), card.id])
	TranslationServer.set_locale(previo)


func test_sin_name_key_cae_al_id_y_no_a_vacio() -> void:
	# Contrato del fallback: feo pero legible. Una cadena vacia dejaria el hueco
	# en blanco en pantalla sin que nada avisara.
	var suelta := Card.new()
	suelta.id = "Prueba"
	assert_eq(suelta.get_display_name(), "Prueba")
