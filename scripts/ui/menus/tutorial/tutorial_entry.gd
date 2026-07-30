extends RefCounted
class_name TutorialEntry

## Una entrada del manual del tutorial: un texto largo agrupado bajo una
## categoría. Sustituye al Dictionary sin tipar que se indexaba por
## `entry["category"]` desde el panel.
##
## No es un "paso" de tutorial guiado: no hay secuencia, ni imagen, ni destino
## que resaltar. El panel es un navegador de referencia (lista + cuerpo).

var category: String
var title: String
var body: String


func _init(p_category: String, p_title: String, p_body: String) -> void:
	category = p_category
	title = p_title
	body = p_body
