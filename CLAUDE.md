# Guía del proyecto

Juego de estrategia por turnos en Godot 4.5 (GDScript). Dos imperios compiten por
dominación territorial; el rival lo lleva una IA con SO-ISMCTS guiado por una
heurística. Es el proyecto de un TFG, así que **las mediciones son resultados**:
romper la comparabilidad de una tanda cuesta más que un bug corriente.

---

## Cómo correr las cosas

Godot vive en una **carpeta** con nombre de ejecutable. El binario que imprime a
stdout es el `_console`:

```bash
"C:/Users/ibaip/Desktop/Godot_v4.5-stable_win64.exe/Godot_v4.5-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Reimportar tras tocar scripts, `.tres` o crear un `class_name` nuevo:

```bash
"C:/Users/ibaip/Desktop/Godot_v4.5-stable_win64.exe/Godot_v4.5-stable_win64_console.exe" --headless --editor --quit --path .
```

Las suites largas (optimización, benchmarks, comparación de modos) están detrás de
variables de entorno y tardan de minutos a horas. Están documentadas en
`tests/README_GUT_TESTS.md`, junto con las convenciones para escribir tests.

---

## Trampas del entorno

Esto no es teoría: cada una ha costado un fallo real en este repo.

**El código de salida no es una puerta.** `--editor --quit` devuelve `EXIT=0`
*aunque imprima parse errors*. Hay que **leer el log**, no mirar el código de
retorno. Comprobado inyectando una llamada a una función inexistente: el log grita
y la salida dice 0.

**GUT salta en silencio los scripts que no compilan** y sigue diciendo "All tests
passed" con menos tests. Mirar siempre el **recuento de Scripts y de Tests**, no el
mensaje final. Si el número baja, cuadrar la diferencia al detalle antes de darla
por buena.

**`load()` de un script roto NO devuelve null.** Devuelve un `GDScript` a medio
compilar, así que `assert_not_null(load(p))` es una aserción que no falla nunca. Lo
que discrimina es `can_instantiate()`. Lo vigila `test_zz_all_scripts_compile`.

**`Callable(Clase, "método")` con un nombre equivocado parsea bien.** El nombre
viaja dentro de una cadena: ni el parser ni el reimport lo ven, y falla solo al
pisar esa rama en ejecución. Lo vigila `test_zz_callable_dispatch`.

**`--script` no carga autoloads.** Verificar así código que toca `WorldMap` o
`Events` falla **sin salida**. Para eso, un test GUT, que sí los carga.

**Un `class_name` nuevo exige reimportar ANTES de GUT** o falla en cascada con
"Identifier not declared" (la caché de clases está obsoleta).

**Ciclo de clases y `.tres`.** Si un `Resource` que se carga desde `.tres` acaba
formando un ciclo de referencias entre clases, `load()` devuelve **null en
ejecución**, sin error de parseo y con el reimport en `EXIT=0`. Por eso
`HeuristicWeights` no referencia a `HeuristicWeightsSpec` y `SceneGroups` no tipa
sus accesores con clases del juego. Hay tests-guarda para las dos.

---

## Arquitectura: los dos mundos

La IA razona sobre un **snapshot** (`AIRealState`), no sobre la escena. Eso obliga a
que muchas reglas existan en dos representaciones, y el mayor riesgo del proyecto es
que **divergan** sin que nada lo note.

La solución es un puerto, `AIStateView`, con dos implementaciones —`LiveStateView`
(escena) y `SnapshotStateView` (snapshot)— y las fórmulas escritas **una sola vez**
en `scripts/empire/ai/scoring/`. Cada mundo aporta solo la mitad de "cómo se lee
este mundo":

| | Mundo vivo | Snapshot |
|---|---|---|
| Entrada + wrappers | `AIHeuristic` | `AIRealEvalStrong` |
| Recorridos del mundo | `AILiveFacts` | `AISnapshotFacts` |
| Caché por decisión | `AIDecisionCache` | — |

Al tocar cualquiera de esos ficheros, **mirar su gemelo**. Están partidos con la
misma forma a propósito, justo para que comparar no requiera memoria.

Lo que sigue siendo espejo a propósito (`AIRealCombat`, `AIRealEffects`,
`AIRealEvents`) lo es porque el motor real vive en nodos y emite por el bus
`Events`, que en una simulación dispararía los trackers de la partida en curso. Las
fórmulas sí se comparten (`CombatMath`, `ConquestResolver`).

### Reglas frente a pesos

- `scripts/config/game_balance.gd` → **reglas del juego** (umbral de victoria,
  decaimiento de frentes, frentes máximos, curvas de pool).
- `HeuristicWeights` → **lo que la IA pondera**, ajustable por el optimizador.

No mezclarlos. Cuando la IA necesita *creer* una regla, el peso **deriva** de
`GameBalance` (ver `state_victory_share`). La excepción documentada es
`recruit_front_charge_per_troop`: ahí el peso es la *estimación* ajustable de la IA,
no la regla.

---

## Convenciones

- **Longitud**: ninguna función > 40 líneas, ningún fichero > 400. Lo de los
  ficheros se cumple (0 de 323). Lo de las funciones, casi: quedan **6 de 1701**,
  dos justificadas abajo y cuatro sin revisar (`EventContext.from_snapshot` 51,
  `battle_front_visual._setup_front_line` 48, `AIRealSimulator.recompute_economy`
  44, `AIChoiceScorer.score_choice` 41). Medirlas con el cuerpo real, no de `func`
  a `func`: contar los `@export` y `const` intermedios infló varias cifras del plan
  de refactor.
- **Tipado**: `Array[T]` siempre; `:=` cuando el tipo es evidente; tipo explícito en
  las firmas. Ojo: declarar una función **sin tipo de retorno** devuelve `Variant` y
  rompe la inferencia `:=` de los llamantes en cascada.
- **Contenedores tipados**: nacen tipados en la declaración. Asignar un literal `[]`
  a un `Array[T]` es error **en ejecución**, no de parseo.
- **Cabeceras**: describen el estado actual, no la historia. Nada de marcadores de
  fase (`§1.3.g`, `C6`, `F2.5b`) ni de referencias a símbolos borrados. Si una
  cabecera dice "espejo de X", tiene que seguir siéndolo.
- **Señales**: conectar en `_ready()`, desconectar en `_exit_tree()`; nunca desde el
  editor.
- **i18n**: nunca construir claves por concatenación (`"TILE_" + enum`). Usar los
  helpers (`Tile.biome_key()`). Lo vigila `test_i18n_keys`.
- **Color**: nada de literales hex; van en `UITheme`. Lo vigila `test_ui_theme`.

### Desviaciones deliberadas

No "arreglarlas" sin medir antes:

- `AIRealMCTS._iterate` (52 líneas) **no se parte**. Extraer el descenso obligaría a
  devolver un `Dictionary` por iteración, que es exactamente lo que causó una
  regresión medida del 19% en throughput.
- `AIDeckScorer.score_card_for_deck` (60 líneas) consulta las urgencias **dentro**
  de la rama que las usa, no al entrar. Parece redundante y no lo es: en el snapshot
  esas urgencias recorren frentes y casillas, y esto es camino caliente.
- `HeuristicWeights` son 244 `@export var`. No pueden moverse sin romper
  `heuristic_weights_optimized.tres` y el layout del vector del optimizador — es
  decir, las mediciones del TFG.
- `game_state_serializer` y `map.gd` leen el registro global de frentes a propósito:
  son quien construye y destruye el mundo.

---

## Método

Lo que ha rendido en este repo, por orden:

1. **Medir la premisa antes de ejecutar una tarea del plan.** Las premisas caducan:
   secciones enteras del plan de refactor partían de conteos inflados o de
   duplicaciones que ya no existían. Contar primero ha evitado trabajo inútil y ha
   destapado hallazgos que el plan no listaba.
2. **Verificar en rojo.** Una guarda que nunca se ha visto fallar no es una guarda.
   Antes de dar por bueno un test nuevo, romper a propósito lo que debe detectar y
   comprobar que falla. Así se descubrió que la guarda de compilación llevaba desde
   siempre sin comprobar nada.
3. **Ejercitar donde el fallo se ve.** Un helper probado solo en el caso fácil pasa
   en verde con el bug dentro. El clamp del excedente económico no lo cubría ningún
   test porque ninguna entrada superaba el umbral donde actúa.
4. **Al mover código, comparar el conjunto de funciones antes y después.** Cazó una
   función duplicada en dos ficheros y una muerta que la suite no habría notado.
5. **Los tests afirman la regla, no el número.** Contra el campo de peso
   (`w.surplus_max`), no contra su valor, y derivando también **las entradas** del
   umbral. Un test con entradas literales sigue en verde midiendo otra banda cuando
   cambia un umbral, que es peor que fallar.

## Al commitear

- Una tarea, un commit. Suite en verde antes y después.
- Si toca la IA: además el smoke del benchmark MCTS.
- **Sin coautoría** en los mensajes.
- El working tree arrastra churn de `assets/` y `.tres` (UIDs de textura que
  regenera el reimport) que **no es del refactor**: excluirlo de los commits.
- `_ai_docs/` está en `.gitignore`; no referenciarlo desde el código.
