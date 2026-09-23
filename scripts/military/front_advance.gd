extends RefCounted
class_name FrontAdvance

## Regla de AVANCE de una ofensiva: a qué casilla enemiga sigue el frente después
## de conquistar una. Escrita una sola vez y usada por los dos mundos
## —BattleFrontManager en el juego y AIRealCombat en la simulación del MCTS—, como
## ConquestResolver, para que la IA prevea el mismo avance que luego ocurre.
##
## Cada mundo describe las candidatas (las vecinas enemigas libres de la casilla
## conquistada) EN EL ORDEN DE VECINAS de esa casilla, que es el mismo en los dos:
## el snapshot copia la lista de la escena saltándose los huecos. Aquí se elige.
##
## Criterios (GameBalance.FRONT_ADVANCE_CRITERION):
##   · CONSOLIDATE: la que tiene más vecinas del atacante. Cierra bolsas y endereza
##     la línea en vez de perforar hacia el interior. Desempata la más débil.
##   · WEAKEST: la más débil —menos defensa de edificios y luego el bioma más fácil
##     de asaltar—. Desempata la más rodeada.
## Si todo empata, la primera en el orden de vecinas.


## Lo que cada mundo aporta de una candidata; lo construye `candidate()`.
class Candidate:
	var own_neighbors: int = 0         ## vecinas que ya son del atacante
	var building_defense: float = 0.0  ## defensa plana de sus edificios (Fortaleza)
	var difficulty: float = 1.0        ## bioma: multiplicador de defensa / de ataque


static func candidate(own_neighbors: int, buildings: Array[Building],
		biome: int) -> Candidate:
	var c := Candidate.new()
	c.own_neighbors = own_neighbors
	for b in buildings:
		if b != null:
			c.building_defense += float(b.flat_defense_bonus)
	var biomes := BiomeConfig.shared()
	c.difficulty = biomes.get_defense_multiplier(biome) \
		/ maxf(biomes.get_attack_multiplier(biome), 0.001)
	return c


## Índice de la candidata elegida, o -1 si no hay ninguna.
static func pick(candidates: Array[Candidate],
		criterion: GameBalance.FrontAdvanceCriterion = GameBalance.FRONT_ADVANCE_CRITERION) -> int:
	var best := -1
	for i in range(candidates.size()):
		if best < 0 or _better(candidates[i], candidates[best], criterion):
			best = i
	return best


## `a` estrictamente mejor que `b`. Con empate total no lo es: gana la primera.
static func _better(a: Candidate, b: Candidate,
		criterion: GameBalance.FrontAdvanceCriterion) -> bool:
	var ka := _keys(a, criterion)
	var kb := _keys(b, criterion)
	for k in range(ka.size()):
		if ka[k] != kb[k]:
			return ka[k] > kb[k]
	return false


## Claves de orden, de más a menos prioritaria. Más alto = preferida.
static func _keys(c: Candidate, criterion: GameBalance.FrontAdvanceCriterion) -> Array[float]:
	var surrounded := float(c.own_neighbors)
	var unfortified := -c.building_defense
	var easy_biome := -c.difficulty
	if criterion == GameBalance.FrontAdvanceCriterion.WEAKEST:
		return [unfortified, easy_biome, surrounded]
	return [surrounded, unfortified, easy_biome]
