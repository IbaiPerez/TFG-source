extends RefCounted
class_name TestWorld

## Limpieza centralizada del estado global entre tests: una sola idea de "pizarra
## limpia" en vez de que cada fichero recuerde qué piezas hay que borrar.
##
##   func before_each() -> void:
##       TestWorld.reset()
##
## Que eso importe no es teórico: `map_as_dict` es justo la pieza que se olvidaba,
## y el bug de producción del commit 2b092e0 (casillas ya liberadas al empezar una
## segunda partida) convivía con 10+ sitios que la limpiaban a mano.
##
## NO se introduce una clase base `GameTest` que llame a esto desde su
## `after_each`, como proponía el plan: GUT invoca solo el `after_each` más
## derivado, así que cada fichero tendría que acordarse de `super.after_each()`.
## Sería la misma disciplina que ahora, pero fallando EN SILENCIO en vez de a la
## vista. La llamada explícita se queda.
##
## Los ficheros que además limpian A MEDIA PRUEBA (test_ai_controller,
## test_battle_front_manager…) siguen llamando a `clear_active_instances()` ahí a
## propósito: quieren vaciar los frentes sin tocar el mundo que acaban de montar.
##
## GUT solo escanea el nivel superior de res://tests/ (no tests/helpers/), así
## que este fichero no se ejecuta como suite pese al nombre.


## Reinicia el estado global compartido entre partidas/tests: registro de frentes
## de batalla y el mapa del mundo. Llamar en after_each() de los tests que tocan
## frentes o generan mundo.
static func reset() -> void:
	BattleFront.clear_active_instances()
	WorldMap.map = []
	WorldMap.map_as_dict = {}
