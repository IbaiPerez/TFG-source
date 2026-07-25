extends RefCounted
class_name TestAssertions

## Aserciones de dominio reutilizables. Toman el GutTest (`t`) como primer
## argumento porque los métodos assert_* de GUT son de instancia. Sustituyen a las
## comparaciones con números mágicos que hoy afirman valores derivados sin mostrar
## la derivación (p.ej. `assert_eq(stats.total_gold, 65)` en vez de `100 - 35`).


## El oro pasó de `before` a `before + expected_delta`. Deja explícita la relación
## coste/ingreso en vez de afirmar el resultado ya calculado a mano.
static func assert_gold_delta(t: GutTest, stats: Stats, before: int,
		expected_delta: int, msg := "") -> void:
	var expected := before + expected_delta
	t.assert_eq(stats.total_gold, expected,
		"%s (esperado %d = %d %+d)" % [msg, expected, before, expected_delta])


## Los valores están ordenados de forma estrictamente descendente. Útil para
## verificar prioridades/urgencias monótonas sin fijar sus magnitudes exactas
## (que cambian al reajustar pesos).
static func assert_descending(t: GutTest, values: Array, msg := "") -> void:
	for i in range(1, values.size()):
		t.assert_gt(float(values[i - 1]), float(values[i]),
			"%s: se esperaba values[%d] > values[%d]" % [msg, i - 1, i])


## `option_a` puntúa estrictamente por encima de `option_b` en el mismo contexto.
## Verifica la ORDENACIÓN relativa de la heurística, robusta a cambios de pesos,
## en lugar de fijar el score absoluto.
static func assert_scores_higher(t: GutTest, option_a: AIPlayOption,
		option_b: AIPlayOption, ctx: AITurnContext, msg := "") -> void:
	var sa := AIHeuristic.score_option(option_a, ctx)
	var sb := AIHeuristic.score_option(option_b, ctx)
	t.assert_gt(sa, sb, "%s (score_a=%.3f, score_b=%.3f)" % [msg, sa, sb])
