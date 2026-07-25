extends RefCounted
class_name SearchSpace

## Espacio de búsqueda de pesos para los optimizadores (SA/GA). Encapsula el
## conjunto de claves a optimizar, sus límites (HeuristicWeights.get_bounds) y las
## operaciones sobre el vector: conversión ↔ HeuristicWeights y perturbaciones con
## clamp. Antes SA y GA reimplementaban cada uno estas primitivas.
##
## Comparte el RNG del optimizador (se le pasa en _init), de modo que el ORDEN de
## las llamadas al RNG —y por tanto la reproducibilidad con semilla fija— es
## idéntico al del código previo.

var keys: PackedStringArray
var rng: RandomNumberGenerator


func _init(p_keys: PackedStringArray = PackedStringArray(),
		p_rng: RandomNumberGenerator = null) -> void:
	keys = p_keys if not p_keys.is_empty() else HeuristicWeights.OPTIMIZABLE_KEYS
	rng = p_rng if p_rng != null else RandomNumberGenerator.new()


func dim() -> int:
	return keys.size()


func bounds(i: int) -> Vector2:
	return HeuristicWeights.get_bounds(keys[i])


## Vector de los pesos `w` en las claves del espacio.
func vector_of(w: HeuristicWeights) -> PackedFloat64Array:
	return w.to_vector(keys)


## Copia de `base` con el vector `v` aplicado en las claves del espacio. Los campos
## FUERA de `keys` conservan su valor en `base` — clave para no perder pesos al
## encadenar etapas de optimización partiendo de un campeón previo.
func apply(base: HeuristicWeights, v: PackedFloat64Array) -> HeuristicWeights:
	var w := base.clone()
	w.apply_vector(v, keys)
	return w


func clamp_vec(v: PackedFloat64Array) -> PackedFloat64Array:
	var out := v.duplicate()
	for i in range(out.size()):
		var b := bounds(i)
		out[i] = clampf(out[i], b.x, b.y)
	return out


## SA: perturba `count` dimensiones al azar con ruido gaussiano σ = frac·rango.
## Baraja Fisher-Yates completo y toma las primeras `count` (igual que el original,
## para conservar el orden de consumo del RNG).
func perturb_dims(v: PackedFloat64Array, sigma_frac: float, count: int) -> PackedFloat64Array:
	var out := v.duplicate()
	for i in _pick_dims(count):
		var b := bounds(i)
		out[i] = clampf(out[i] + rng.randfn(0.0, (b.y - b.x) * sigma_frac), b.x, b.y)
	return out


func _pick_dims(count: int) -> Array:
	var n := keys.size()
	var pool := range(n)
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, mini(count, n))


## GA: muestrea un punto cercano perturbando TODAS las dimensiones (σ = frac·rango).
func sample_near(v: PackedFloat64Array, sigma_frac: float) -> PackedFloat64Array:
	var out := v.duplicate()
	for i in range(out.size()):
		var b := bounds(i)
		out[i] = clampf(out[i] + rng.randfn(0.0, (b.y - b.x) * sigma_frac), b.x, b.y)
	return out


## GA: muta cada gen con probabilidad `prob` (σ = frac·rango). Muta `v` in place.
func mutate(v: PackedFloat64Array, prob: float, sigma_frac: float) -> PackedFloat64Array:
	for i in range(v.size()):
		if rng.randf() < prob:
			var b := bounds(i)
			v[i] = clampf(v[i] + rng.randfn(0.0, (b.y - b.x) * sigma_frac), b.x, b.y)
	return v


## GA: cruce BLX-α entre dos vectores.
func crossover_blx(a: PackedFloat64Array, b: PackedFloat64Array,
		alpha: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(a.size())
	for i in range(a.size()):
		var lo := minf(a[i], b[i])
		var hi := maxf(a[i], b[i])
		var d := hi - lo
		var val := rng.randf_range(lo - alpha * d, hi + alpha * d)
		var bnd := bounds(i)
		out[i] = clampf(val, bnd.x, bnd.y)
	return out
