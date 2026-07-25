extends RefCounted
class_name UILayout

## Utilidades de layout para la UI: centraliza patrones repetidos literalmente en
## muchos paneles. Reduce la duplicación sin cambiar comportamiento.


## Libera (queue_free) todos los hijos de un contenedor. Sustituye al bucle
##   for child in x.get_children(): child.queue_free()
## repetido en ~10 paneles antes de repoblar una grid/lista.
static func clear_children(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
