# Suite de tests (GUT)

Qué se ejecuta por defecto, qué va bajo demanda y cómo lanzar cada cosa.

> Este fichero documentaba antes **41 tests del sistema de bloqueo de menús**, que era
> toda la suite cuando se escribió. Hoy son más de 1.600 en más de 110 scripts, y su
> comando de arranque apuntaba a `addons/gut/run_tests.gd`, **que no existe**. Reescrito.

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
Scripts             114
Tests              1620
Passing Tests      1619
Risky/Pending         1
Asserts            3700
Time              50.0s
```

(Cifras orientativas: cambian con cada test nuevo. Lo que importa es que `Scripts` y
`Tests` **no bajen** respecto a la corrida anterior sin una explicación.)

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
| `RUN_OPT_2STAGE` | Optimización de pesos en dos etapas (SA + GA) contra un pool de rivales | ~horas |
| `RUN_CALIBRATE_SA` | Calibración de los hiperparámetros del SA (experimento cerrado; ver su cabecera) | ~días |
| `RUN_HP_SWEEP` | Calibración de hiperparámetros del SO-ISMCTS (ablación) | ~horas |
| `RUN_MODE_COMPARISON` | Round-robin heurística vs SO-ISMCTS por emparejamiento y presupuesto | ~horas |
| `RUN_VALIDATE_CHAMPION` | Generalización del campeón contra un pool held-out; reporta también la duración en turnos | ~horas |
| `RUN_AB_THROUGHPUT` | A/B de throughput del MCTS con las partidas clavadas | ~12 min |
| `RUN_BENCH_MCTS` | Benchmark campeón-MCTS vs baseline-MCTS, acotado por tiempo | una noche |
| `RUN_PLAY_VS_AI` | Jugar una partida contra la IA desde fuera, por guion (ver `ManualPolicy`) | segundos por jugada |

Todos llevan `ENABLE_FROM_GUI := false`: desde el panel GUT tampoco se disparan sin la
variable. Hubo una época en que cinco lo tenían a `true` y un "Run All" con *Include
Subdirs* lanzaba horas de cómputo.

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

### Lo que NO es un lanzador

`tests/simulation/` contiene también la infraestructura: `game_sim_harness.gd` (una
partida headless con dos `AIController`), `multi_run_simulator.gd`, `ai_mode_comparator.gd`,
`heuristic_fitness.gd` + `heuristic_opponents.gd` (fitness y pool del optimizador),
`sa_optimizer.gd` / `ga_optimizer.gd`, `search_space.gd`, `top_candidates.gd`,
`opt_checkpoint.gd` y `manual_policy.gd`. Ninguno empieza por `test_`, así que GUT no
los toma por suites.

El arnés **no pasa por `TurnManager`**: llama a `start_turn()` de cada IA por turnos y
decide el final con `VictoryRules`, la misma clase que usa `TurnManager` en el juego.
Es la única regla compartida; el orden de turnos y las señales de ronda del juego real
no se ejercitan en simulación.

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

Lo que documentaba la versión anterior de este fichero (41 tests) se ha quedado en dos
ficheros: `test_ui_state.gd` cubre el contador de `UIState` y sus señales de transición
(0→1, 1→0), y `test_menu_blocking.gd` prueba, **sobre los scripts reales** (`camera_3d.gd`,
`interaction.gd` y los paneles que se registran), que un menú abierto bloquea el clic en el
mapa y el zoom de cámara. Los otros cuatro ficheros de aquella versión ejercitaban mocks que
replicaban la lógica de producción y no habrían cazado que se borrara la comprobación; se
han eliminado.

## Otros barridos

- `test_turn_event_catalog.gd` recorre todos los `.tres` de `resources/turn_events/` por la
  vía del juego (`TurnEventLoader.load_all`): claves i18n, opciones, condiciones, y ejecuta
  cada opción por el camino del jugador y por el de la IA.
- `test_sim_smoke.gd` juega UNA partida corta (radio 4, 4 rondas) con el arnés de simulación
  en la suite por defecto, y comprueba que la misma semilla reproduce la misma partida.
- `test_turn_manager.gd` + `test_victory_rules.gd` cubren la rotación de turnos del juego real
  y la condición de victoria, que las simulaciones no recorren.
