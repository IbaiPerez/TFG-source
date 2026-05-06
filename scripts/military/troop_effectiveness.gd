extends RefCounted
class_name TroopEffectiveness


## Tabla de efectividad estilo piedra-papel-tijera/Pokémon entre tipos de tropa.
##
## Modelo de cálculo (enfoque "weighted average"):
## Para cada tropa propia con tipo X, su contribución de ataque efectivo se
## multiplica por la suma ponderada Σ_Y (peso_Y · eff(X, Y)), donde
## peso_Y = nº_tropas_Y_enemigo / total_tropas_enemigas. Si el enemigo no
## tiene tropas asignadas, la efectividad es neutra (×1.0) y el ataque
## efectivo coincide con la suma plana de troop.attack.
##
## Multiplicadores actuales (suaves; se irán escalando según balance):
##   Fuerte   → 1.5
##   Neutro   → 1.0
##   Débil    → 0.7
##
## Ciclo (cada tipo es fuerte vs los 2 siguientes y débil vs los 2 anteriores):
##   CABALLERÍA → A_DISTANCIA → INFANTERÍA_LIGERA → PIQUEROS → INFANTERÍA_PESADA → CABALLERÍA


const MULTIPLIER_STRONG: float = 1.5
const MULTIPLIER_WEAK: float = 0.7
const MULTIPLIER_NEUTRAL: float = 1.0


## Matriz de matchups: MATRIX[atacante][defensor] = multiplicador.
## Las entradas neutras (×1.0) se omiten y se devuelven por defecto.
const MATRIX: Dictionary = {
	# Caballería pisa a tropas ligeras y a tiradores;
	# sufre contra picas e infantería pesada.
	Troop.TroopType.CABALLERIA: {
		Troop.TroopType.A_DISTANCIA: MULTIPLIER_STRONG,
		Troop.TroopType.INFANTERIA_LIGERA: MULTIPLIER_STRONG,
		Troop.TroopType.INFANTERIA_PESADA: MULTIPLIER_WEAK,
		Troop.TroopType.PIQUEROS: MULTIPLIER_WEAK,
	},
	# A distancia castiga a infantería ligera y pesada (alcance);
	# débil contra caballería (la alcanza rápido) y piqueros (cierran filas).
	Troop.TroopType.A_DISTANCIA: {
		Troop.TroopType.INFANTERIA_LIGERA: MULTIPLIER_STRONG,
		Troop.TroopType.INFANTERIA_PESADA: MULTIPLIER_STRONG,
		Troop.TroopType.CABALLERIA: MULTIPLIER_WEAK,
		Troop.TroopType.PIQUEROS: MULTIPLIER_WEAK,
	},
	# Infantería ligera flanquea a piqueros y desgasta a infantería pesada;
	# débil contra caballería y a distancia.
	Troop.TroopType.INFANTERIA_LIGERA: {
		Troop.TroopType.PIQUEROS: MULTIPLIER_STRONG,
		Troop.TroopType.INFANTERIA_PESADA: MULTIPLIER_STRONG,
		Troop.TroopType.CABALLERIA: MULTIPLIER_WEAK,
		Troop.TroopType.A_DISTANCIA: MULTIPLIER_WEAK,
	},
	# Piqueros frenan caballería y aguantan a infantería pesada en formación;
	# débil contra a distancia y contra infantería ligera que rompe filas.
	Troop.TroopType.PIQUEROS: {
		Troop.TroopType.CABALLERIA: MULTIPLIER_STRONG,
		Troop.TroopType.INFANTERIA_PESADA: MULTIPLIER_STRONG,
		Troop.TroopType.A_DISTANCIA: MULTIPLIER_WEAK,
		Troop.TroopType.INFANTERIA_LIGERA: MULTIPLIER_WEAK,
	},
	# Infantería pesada arrolla caballería y a distancia (las alcanza con armadura);
	# débil contra piqueros y contra infantería ligera que la desgasta.
	Troop.TroopType.INFANTERIA_PESADA: {
		Troop.TroopType.CABALLERIA: MULTIPLIER_STRONG,
		Troop.TroopType.A_DISTANCIA: MULTIPLIER_STRONG,
		Troop.TroopType.PIQUEROS: MULTIPLIER_WEAK,
		Troop.TroopType.INFANTERIA_LIGERA: MULTIPLIER_WEAK,
	},
}


## Devuelve el multiplicador del matchup atacante→defensor.
## Cualquier matchup ausente (mismo tipo, o no definido) devuelve 1.0.
static func get_multiplier(attacker_type: int, defender_type: int) -> float:
	if not MATRIX.has(attacker_type):
		return MULTIPLIER_NEUTRAL
	var row: Dictionary = MATRIX[attacker_type]
	return row.get(defender_type, MULTIPLIER_NEUTRAL)


## Calcula el ataque efectivo de UNA tropa concreta contra la composición
## enemiga. Devuelve `troop.attack * multiplicador_efectivo`. Sin enemigos
## el multiplicador es neutro (×1.0).
static func get_effective_attack_for_troop(troop: Troop, enemy_troops: Array[Troop]) -> float:
	var enemy_count: int = enemy_troops.size()
	if enemy_count == 0:
		return float(troop.attack)

	var composition: Dictionary = {}
	for enemy in enemy_troops:
		var t: int = enemy.type
		composition[t] = int(composition.get(t, 0)) + 1

	var weighted_eff: float = 0.0
	for enemy_type in composition.keys():
		var weight: float = float(composition[enemy_type]) / float(enemy_count)
		weighted_eff += weight * get_multiplier(troop.type, enemy_type)

	return float(troop.attack) * weighted_eff


## Calcula el ataque efectivo total de un bando contra la composición enemiga.
## Equivalente a sumar `get_effective_attack_for_troop` para cada tropa propia.
static func get_effective_attack(my_troops: Array[Troop], enemy_troops: Array[Troop]) -> float:
	if my_troops.is_empty():
		return 0.0

	var total: float = 0.0
	for troop in my_troops:
		total += get_effective_attack_for_troop(troop, enemy_troops)
	return total


## Helper para UI: devuelve el multiplicador efectivo medio que un único tipo
## (atacante) sufriría contra una composición enemiga concreta. Útil para
## mostrar "tu caballería pega ×1.10 contra esta mezcla".
static func get_average_multiplier_against(attacker_type: int, enemy_troops: Array[Troop]) -> float:
	var enemy_count: int = enemy_troops.size()
	if enemy_count == 0:
		return MULTIPLIER_NEUTRAL

	var composition: Dictionary = {}
	for enemy in enemy_troops:
		var t: int = enemy.type
		composition[t] = int(composition.get(t, 0)) + 1

	var weighted: float = 0.0
	for enemy_type in composition.keys():
		var weight: float = float(composition[enemy_type]) / float(enemy_count)
		weighted += weight * get_multiplier(attacker_type, enemy_type)
	return weighted
