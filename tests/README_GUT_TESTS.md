# Suite de tests (GUT)

Qué se ejecuta por defecto, qué va bajo demanda y cómo lanzar cada cosa.

> Este fichero documentaba antes **41 tests del sistema de bloqueo de menús**, que era
> toda la suite cuando se escribió. Hoy son 1.431 en 96 scripts, y su comando de
> arranque apuntaba a `addons/gut/run_tests.gd`, **que no existe**. Reescrito.

## Corrida por defecto

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Unos **45 segundos**. Cubre dominio, IA, persistencia y UI; los helpers entran por la vía
de `test_helpers_audit.gd`.

En Windows, el ejecutable con consola es el que imprime a stdout:

```bash
"/c/Users/ibaip/Desktop/Godot_v4.5-stable_win64.exe/Godot_v4.5-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

### Qué NO entra

`.gutconfig.json` declara `dirs: ["res://tests/"]` y GUT **escanea solo ese nivel**, no
los subdirectorios. Es deliberado:

| Carpeta | Por qué queda fuera |
|---|---|
| `tests/helpers/` | Utilidades (`TestBuilders`, `TestFixtures`, `TestWorld`, `TestAssertions`), no suites. Se ejercitan desde `test_helpers_audit.gd`. |
| `tests/simulation/` | Partidas completas y optimizaciones: de minutos a horas. |

## Comprobar el resultado

**No basta con leer «All tests passed».** Si un script de test no compila, GUT **lo salta
en silencio** y sigue dando ese mensaje con menos tests. Hay que mirar el recuento:

```
Scripts              96
Tests              1431
Passing Tests      1430
Risky/Pending         1
Asserts            3602
Time              45.658s
```

**Las líneas malas solo salen si hay algo malo.** `Failing Tests`, `Risky/Pending`,
`Orphans`, `Errors` y `Warnings` pasan por `_log_non_zero_total` (`addons/gut/summary.gd`),
así que **su ausencia significa cero**. `Scripts`, `Tests` y `Passing Tests` salen siempre.

- **Scripts**: si baja, algo dejó de compilar.
- **Risky/Pending**: tests que terminan sin evaluar ninguna aserción. **Hoy hay 1, y es
  esperado**: `test_la_encuesta_se_publica_para_todos_los_idiomas_o_para_ninguno` sale
  antes de aseverar mientras `BuildInfo.SURVEY_URLS` esté vacío. Se cerrará sola al pegar
  las URLs de los formularios. Si aparece alguna más, hay algo que mirar.
- **Orphans**: nodos sin liberar. `Tile` extiende `Node3D`, así que los tests que los
  crean con `.new()` deben pasarlos por `add_child_autofree()`.

Al salir, el motor reporta fugas de RID y de `ObjectDB` en modo headless. Es ruido del
cierre del renderizador dummy, no un fallo de la suite: lo que manda es el bloque de
recuento.

Un `class_name` nuevo exige reimportar **antes** de correr GUT, o falla en cascada con
«Identifier not declared» por caché de clases obsoleta:

```bash
godot --headless --editor --quit --path .
```

## Suites bajo demanda

Todas viven en `tests/simulation/` y están cerradas por variable de entorno. Cada fichero
documenta en su cabecera los parámetros finos y dónde deja el JSON.

| Variable | Qué lanza | Orden de magnitud |
|---|---|---|
| `RUN_SIM_FULL_GAME` | 15 partidas heurística vs heurística (balance) | minutos |
| `RUN_OPT_SA` / `RUN_OPT_GA` | Optimización de pesos (recocido simulado / genético) | ~horas |
| `RUN_OPT_2STAGE` | Optimización en dos etapas contra un pool de rivales | ~horas |
| `RUN_HP_SWEEP` | Calibración de hiperparámetros del SO-ISMCTS (ablación) | ~horas |
| `RUN_MODE_COMPARISON` | Round-robin heurística vs SO-ISMCTS por emparejamiento y presupuesto | ~horas |
| `RUN_VALIDATE_CHAMPION` | Generalización del campeón contra un pool held-out | ~horas |
| `RUN_AB_THROUGHPUT` | A/B de throughput del MCTS con las partidas clavadas | ~12 min |
| `RUN_BENCH_MCTS` | Benchmark campeón-MCTS vs baseline-MCTS, acotado por tiempo | una noche |

Atajos de humo, para comprobar que el arnés arranca sin esperar el ciclo entero:
`OPT_SMOKE=1` (optimizadores) y `BENCH_SMOKE=1` (benchmark).

### Cómo lanzar una

**El `"-gconfig="` vacío es imprescindible.** Sin él siguen aplicándose los `dirs` de
`.gutconfig.json` y `-gtest=` no filtra nada: se corre la suite entera *además* de lo que
pedías.

bash:

```bash
RUN_SIM_FULL_GAME=1 godot --headless -s addons/gut/gut_cmdln.gd "-gconfig=" -gtest=res://tests/simulation/test_sim_full_game.gd -gexit
```

PowerShell:

```powershell
$env:RUN_SIM_FULL_GAME=1; & godot --headless -s addons/gut/gut_cmdln.gd "-gconfig=" -gtest=res://tests/simulation/test_sim_full_game.gd -gexit
```

Los JSON de salida van a `user://`, que en Windows es
`%APPDATA%\Godot\app_userdata\Source\`.

### No hay una config «lenta» aparte

El plan de refactor pedía un `gutconfig` separado que incluyera `tests/simulation/`. **No
se añade a propósito**: sería un gatillo para lanzar horas de cómputo de una vez, cuando lo
que se quiere es disparar UNA tanda concreta. Las puertas de entorno más el `-gtest=` de
arriba ya dan ese control, y con menos formas de equivocarse.

## Filtrar dentro de la suite rápida

Por nombre de script (sin ruta ni extensión):

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_ai_urgency -gexit
```

`-gselect` filtra sobre lo que la config ya escanea; `-gtest` toma una ruta completa y
quiere el `"-gconfig="` vacío. Confundirlos hace correr la suite entera.

## Helpers

En `tests/helpers/`, no se ejecutan como suite:

| Fichero | Para qué |
|---|---|
| `builders.gd` | `TestBuilders`: API fluida para Empire, Stats, Tile, Building, Troop, AITurnContext. |
| `fixtures.gd` | `TestFixtures`: escenarios completos (`early_expansion`, `mid_economy`, `late_dominance`). |
| `test_world.gd` | `TestWorld.reset()`: pizarra limpia (registro de frentes + `WorldMap`, incluido `map_as_dict`). |
| `assertions.gd` | `TestAssertions`: afirmar la derivación (`assert_gold_delta`) en vez del número ya calculado. |

`test_helpers_audit.gd` los ejercita todos. **Existe por un motivo concreto**: estos
helpers se escribieron sin llamantes y `TestBuilders.building()` estuvo roto desde el
principio sin que nadie lo notara — asignaba un `Array` sin tipar a un
`Array[Tile.biome_type]`, que es error *en ejecución* y dejaba el builder devolviendo `null`.

Al usar los fixtures, **libera las casillas**: devuelven `Tile` sin padre, y
`late_dominance()` son 12 de golpe.

## Convenciones al escribir tests

- **Afirmar la derivación, no el resultado.** `assert_gold_delta(stats, antes, -item.price)`
  en vez de `assert_eq(total_gold, 65)`. Con los pesos de la IA, afirmar contra el campo
  (`w.gold_urg_early_v0`) en vez de contra su valor actual: así el test comprueba *en qué
  banda cae* la entrada, que es lo que decide la función, y sobrevive a los reajustes.
- **Invariantes estructurales** junto a los casos concretos: monotonía, orden relativo,
  fronteras. No dependen de ningún número y son los que cazan bugs de verdad.
- **Limpieza explícita** con `TestWorld.reset()` en `before_each`/`after_each`. No hay clase
  base que lo haga: GUT solo invoca el `after_each` más derivado, así que heredarlo
  obligaría a acordarse de `super.after_each()` y fallaría en silencio al olvidarlo.

## El bloque de bloqueo de menús

Lo que documentaba la versión anterior de este fichero sigue existiendo y pasando:
`test_ui_state.gd`, `test_interaction_blocking.gd`, `test_camera_blocking.gd`,
`test_menu_registration.gd` y `test_menu_blocking_integration.gd` cubren el contador de
`UIState`, sus señales de transición (0→1, 1→0) y que los menús abiertos bloqueen el clic
en el mapa y el zoom de cámara. Se ejecutan con la suite por defecto, sin nada especial.
