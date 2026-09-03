extends RefCounted
class_name SearchSpace

## Espacio de búsqueda de pesos para los optimizadores (SA/GA). Encapsula el
## conjunto de claves a optimizar, sus límites (HeuristicWeightsSpec.get_bounds) y las
## operaciones sobre el vector: conversión ↔ HeuristicWeights y perturbaciones con
## clamp. Antes SA y GA reimplementaban cada uno estas primitivas.
##
## Comparte el RNG del optimizador (se le pasa en _init), de modo que el ORDEN de
## las llamadas al RNG —y por tanto la reproducibilidad con semilla fija— es
## idéntico al del código previo.

var keys: PackedStringArray
var rng: RandomNumberGenerator

## índice de la dimensión -> índices de sus compañeras de bloque (ella incluida).
## Solo entran las que están DENTRO de este espacio: optimizar un subconjunto de
## claves no debe arrastrar a las que quedaron fuera.
var _peers: Dictionary = {}


func _init(p_keys: PackedStringArray = PackedStringArray(),
		p_rng: RandomNumberGenerator = null) -> void:
	keys = p_keys if not p_keys.is_empty() else HeuristicWeightsSpec.OPTIMIZABLE_KEYS
	rng = p_rng if p_rng != null else RandomNumberGenerator.new()
	_build_peers()


func _build_peers() -> void:
	var pos := {}
	for i in range(keys.size()):
		pos[keys[i]] = i
	for i in range(keys.size()):
		var grupo: Array = []
		for k in HeuristicWeightsSpec.block_peers(keys[i]):
			if pos.has(k):
				grupo.append(pos[k])
		_peers[i] = grupo


func dim() -> int:
	return keys.size()


func bounds(i: int) -> Vector2:
	return HeuristicWeightsSpec.get_bounds(keys[i])


## Vector de los pesos `w` en las claves del espacio.
func vector_of(w: HeuristicWeights) -> PackedFloat64Array:
	return HeuristicWeightsSpec.to_vector(w, keys)


## Copia de `base` con el vector `v` aplicado en las claves del espacio. Los campos
## FUERA de `keys` conservan su valor en `base` — clave para no perder pesos al
## encadenar etapas de optimización partiendo de un campeón previo.
func apply(base: HeuristicWeights, v: PackedFloat64Array) -> HeuristicWeights:
	var w := base.clone()
	HeuristicWeightsSpec.apply_vector(w, v, keys)
	# Proyectar sobre la región coherente ANTES de que nadie lo evalúe. Es el único
	# sitio por el que pasan todos los candidatos de SA y de GA, así que reparar
	# aquí garantiza que no se gaste una partida en un juego de pesos con tramos
	# inalcanzables o gradientes invertidos.
	HeuristicWeightsSpec.repair(w)
	return w


func clamp_vec(v: PackedFloat64Array) -> PackedFloat64Array:
	var out := v.duplicate()
	for i in range(out.size()):
		var b := bounds(i)
		out[i] = clampf(out[i], b.x, b.y)
	return out


## SA: perturba `count` dimensiones al azar con ruido gaussiano σ = frac·rango.
## Baraja Fisher-Yates completo y toma las primeras `count`.
##
## Si la dimensión elegida pertenece a un BLOQUE, el movimiento se aplica a todo el
## bloque a la vez. Sin eso, SA no puede alcanzar los movimientos que solo tienen
## sentido en conjunto: con 3 dimensiones perturbadas de más de 60, la probabilidad
## de que toque justo las DOS condiciones de la fase LATE en el mismo paso es del
## orden del 0.1 % — y por separado cada una es casi neutra, así que Metropolis las
## rechaza. Un bloque grande mueve más dimensiones que `count`; es el objetivo.
func perturb_dims(v: PackedFloat64Array, sigma_frac: float, count: int) -> PackedFloat64Array:
	var out := v.duplicate()
	for i in _pick_dims(count):
		_perturb_block(out, i, sigma_frac)
	return out


## Aplica a la dimensión `i` —y a sus compañeras de bloque— el MISMO desplazamiento
## relativo, medido como fracción del rango de cada una. La fracción común conserva
## la forma interna del grupo y desplaza el conjunto, que es justo el movimiento que
## la búsqueda por coordenadas no puede dar. La forma sigue siendo explorable porque
## el `repair` posterior solo corrige el ORDEN, no las distancias.
func _perturb_block(out: PackedFloat64Array, i: int, sigma_frac: float) -> void:
	# Con una sola dimensión esto es EXACTAMENTE el ruido de antes: `frac` es normal
	# de σ = sigma_frac y se multiplica por el rango, igual que `randfn(0, σ·rango)`.
	var frac := rng.randfn(0.0, sigma_frac)
	for j in _peers.get(i, [i]):
		var bj := bounds(j)
		out[j] = clampf(out[j] + frac * (bj.y - bj.x), bj.x, bj.y)


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
## Igual que en SA, un gen de un bloque arrastra a sus compañeras: el cruce puede
## combinar bloques coherentes, pero solo si la mutación los genera coherentes.
func mutate(v: PackedFloat64Array, prob: float, sigma_frac: float) -> PackedFloat64Array:
	for i in range(v.size()):
		if rng.randf() < prob:
			_perturb_block(v, i, sigma_frac)
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
