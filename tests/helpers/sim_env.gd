extends RefCounted
class_name SimEnv

## Lectura de parámetros por variable de entorno y media aritmética, que las
## suites largas de `tests/simulation/` copiaban cada una en privado.


static func int_env(name: String, fallback: int) -> int:
	var v := OS.get_environment(name)
	return int(v) if v != "" else fallback


static func float_env(name: String, fallback: float) -> float:
	var v := OS.get_environment(name)
	return float(v) if v != "" else fallback


## Media de `xs`; 0.0 si está vacío.
static func mean(xs: Array) -> float:
	var t := 0.0
	for x in xs:
		t += float(x)
	return t / float(maxi(xs.size(), 1))
