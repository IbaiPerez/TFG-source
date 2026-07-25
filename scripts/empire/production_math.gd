extends RefCounted
class_name ProductionMath

## Aritmética pura de producción económica, compartida por ProductionCalculator
## (juego real, sobre Stats/Tile/ModifierManager) y AIRealSimulator.recompute_economy
## (snapshot del MCTS). Aísla las dos operaciones cuya divergencia rompería la
## PARIDAD económica entre el juego y la simulación de la IA: cómo se aplica el
## porcentaje y cómo se clampa el descuento de mantenimiento.


## Aplica un modificador porcentual SOLO a la parte positiva de la producción (los
## costes negativos no se amplifican):
##   int(max(base, 0) · (1 + percent/100)) + min(base, 0)
static func apply_percent(base: int, percent: float) -> int:
	return int(maxi(base, 0) * (1.0 + percent / 100.0)) + mini(base, 0)


## Multiplicador de mantenimiento de una tropa según el porcentaje de descuento
## (positivo) o encarecimiento (negativo) acumulado, clampeado al coste mínimo.
static func maintenance_multiplier(percent: float) -> float:
	return ModifierManager.clamp_cost_multiplier(1.0 + percent / 100.0)
