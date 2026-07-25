extends RefCounted
class_name TestWorld

## Limpieza centralizada del estado global entre tests. Sustituye a las 26+
## llamadas manuales dispersas a `BattleFront.clear_active_instances()` y a las
## 23 asignaciones sueltas de `WorldMap.map = []`.
##
## Uso en un test (o en su clase base):
##
##   func after_each() -> void:
##       TestWorld.reset()
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
