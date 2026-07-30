extends GutTest

## Fija el contrato de [SceneGroups], que centraliza los nombres de grupo con los
## que se localizan los nodos únicos de la partida.
##
## Lo importante que se fija aquí es el NULL SILENCIOSO: los accesores devuelven
## null sin `assert` ni `push_error` cuando no hay escena de mapa montada. Es
## deliberado — los tests headless y los arneses de simulación corren sin
## PlayerHandler ni capa de UI, varios llamantes ya tratan ese null como caso
## normal, y GUT convierte cualquier error de motor en un fallo de test.
##
## Las aserciones NO asumen que los grupos estén vacíos al empezar: otro script de
## test puede dejar un nodo suyo registrado y el orden de GUT no está garantizado.


func test_el_accesor_no_cambia_el_resultado_de_la_busqueda_por_grupo() -> void:
	# El accesor es un envoltorio: aporta el nombre y el tipo, no otra semántica.
	assert_eq(SceneGroups.ui_layer(get_tree()),
		get_tree().get_first_node_in_group(SceneGroups.UI_LAYER))


func test_buscar_sin_escena_de_partida_no_provoca_ningun_error() -> void:
	# Si alguien metiera un assert o un push_error en los accesores, GUT marcaría
	# este test como fallido por "Unexpected Errors" aunque no falle ninguna
	# aserción. Ese es justamente el fallo que se quiere impedir.
	SceneGroups.ui_layer(get_tree())
	SceneGroups.player_handler(get_tree())
	assert_true(true, "llamar a los accesores sin partida montada es legítimo")


func test_encuentra_la_capa_de_ui_registrada() -> void:
	var layer := CanvasLayer.new()
	layer.add_to_group(SceneGroups.UI_LAYER)
	add_child_autofree(layer)

	var found := SceneGroups.ui_layer(get_tree())
	assert_not_null(found, "con un nodo en el grupo debe devolver alguno")
	if found != null:
		assert_true(found.is_in_group(SceneGroups.UI_LAYER))


func test_la_capa_de_ui_admite_nodos_que_no_son_canvaslayer() -> void:
	# Se devuelve Node a propósito: los llamantes solo usan API de Node y un
	# downcast a CanvasLayer perdería el nodo si un arnés registrase otra cosa.
	var plain := Node.new()
	plain.add_to_group(SceneGroups.UI_LAYER)
	add_child_autofree(plain)

	assert_eq(SceneGroups.ui_layer(get_tree()),
		get_tree().get_first_node_in_group(SceneGroups.UI_LAYER),
		"un nodo que no es CanvasLayer no debe descartarse")


func test_el_accesor_de_player_handler_devuelve_el_nodo_sin_castear() -> void:
	# El accesor NO puede declararse `-> PlayerHandler`: eso metería a SceneGroups
	# en el ciclo initial_stats.tres → cartas → DrawCardEffect → SceneGroups →
	# PlayerHandler → EmpireController → Stats, que GDScript no resuelve al cargar
	# el recurso (load() devuelve null). El casteo es cosa del llamante.
	var impostor := Node.new()
	impostor.add_to_group(SceneGroups.PLAYER_HANDLER)
	add_child_autofree(impostor)

	assert_eq(SceneGroups.player_handler(get_tree()),
		get_tree().get_first_node_in_group(SceneGroups.PLAYER_HANDLER),
		"devuelve lo que haya en el grupo, sin filtrar por tipo")


func test_scene_groups_no_referencia_ninguna_clase_del_juego() -> void:
	# Guarda del ciclo: si alguien vuelve a tipar un accesor con una clase del
	# juego, el fallo aparecería lejos de aquí (12 tests de serialización cayendo
	# con "Nonexistent function 'create_instance' in base 'Nil'") y sin mencionar
	# el ciclo. Este test señala la causa directamente.
	var source := FileAccess.get_file_as_string("res://scripts/config/scene_groups.gd")
	assert_ne(source, "", "no se pudo leer scene_groups.gd")
	for forbidden in ["PlayerHandler", "EmpireController", "Stats", "CardPile"]:
		assert_false(_mentions_outside_comments(source, forbidden),
			"scene_groups.gd no debe referenciar %s fuera de comentarios" % forbidden)


## Busca `needle` solo en las líneas de código (descarta las de comentario), para
## que la documentación del ciclo pueda nombrar las clases sin disparar la guarda.
func _mentions_outside_comments(source: String, needle: String) -> bool:
	for line in source.split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with("#"):
			continue
		if stripped.contains(needle):
			return true
	return false


func test_los_nombres_de_grupo_son_los_de_la_escena() -> void:
	# Deja escrito el contrato que antes vivía como literal repetido en 16 puntos:
	# "ui_layer" lo declara map.tscn y "player_handler" lo registra
	# player_handler.gd en su _ready.
	assert_eq(SceneGroups.UI_LAYER, "ui_layer")
	assert_eq(SceneGroups.PLAYER_HANDLER, "player_handler")
