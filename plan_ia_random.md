# Plan — IA random + presentación de acciones IA

> Versión 1 de la IA. Decide aleatoriamente entre todas las opciones legales y el jugador ve qué juega en tiempo real (floating label sobre la tile + pacing entre acciones + mini-log opcional).

---

## 1. Objetivos de esta iteración

1. Que el `AIController` deje de descartar toda su mano y juegue cartas reales con efectos reales sobre el estado del juego.
2. Que las decisiones se tomen **al azar uniforme** sobre todas las jugadas legales — sin heurística, sin valoración. Es deliberado: queremos validar el flujo (efectos, señales, UI, save/load entre turnos IA, fin de turno) antes de añadir inteligencia.
3. Que el jugador reciba **información clara y posicional** de lo que la IA hace, en tiempo real, sin tener que leer la consola.
4. Que el bucle decisorio sea **determinista** dado un seed (clave para tests GUT) y **acotado** (límite duro de iteraciones por turno para que un bug nunca cuelgue el juego).
5. No introducir regresiones en lo que ya funciona del flujo de turnos.

Lo que **NO** entra en esta iteración: heurísticas de utilidad, IA militar real (gestión de tropas/asignación a frentes), elección informada de tácticas/edificios. Esas decisiones siguen siendo random. La meta es el andamio.

---

## 1.B. Auditoría de información disponible para la IA (2026-05-10)

Antes de codear, repaso de qué accede el `AIController` al decidir y qué se le tiene que inyectar.

### Lo que la IA tiene "gratis" (heredado de `EmpireController`)
- **`stats`** propio — `total_gold`, `gold_per_turn`, `food`, `turn_number`, `deck` / `draw_pile` / `discard_pile` / `played_pile`, `possible_buildings`, `troop_pool`, `empire`, `available_events`, `used_unique_events`, `unlocked_card_pool`. Todo lo que necesita el jugador, lo tiene la IA.
- **`stats.empire.controlled_tiles`** — sus tiles. Los `tile.neighbors[]` permiten saber qué tiles son enemigas (`controller != null and controller != stats.empire`) o vacías (`controller == null`).
- **`modifier_manager`** — modificadores propios activos.
- **`battle_front_manager.active_fronts`** — frentes en los que la IA participa (atacante o defensora).
- **`BattleFront.is_tile_in_active_front(tile)`** estático — para saber si una tile global está en un frente cualquiera (cubre los frentes de otros imperios también).
- **`WorldMap.map`** autoload — todo el mapa de tiles. **No hay fog of war**, así que la IA puede ver tiles lejanas si la carta lo requiriese (hoy ninguna lo hace; todas operan localmente).
- **Group `battle_front_visuals`** del scene tree — para resolver el `BattleFrontVisual` correspondiente a un `BattleFront`. Necesario sólo en el momento de `apply_effects` de `TacticCard`.

### Lo que NO tiene (y por qué da igual para la v1 random)
- **Stats de otros imperios.** Cada controller posee su propio `Stats`. Sin acceso al oro/mano del rival. Para una IA random es irrelevante; cuando metamos heurística necesitará al menos saber cuántas tropas tiene el rival visualizando frentes.
- **Lista directa de "imperios enemigos".** La IA infiere enemigos recorriendo vecinos de sus tiles. No hace falta un registro central para el MVP.

### Lo que el `AIOptionsBuilder` debe inyectar antes de enumerar
Hallazgos clave de revisar el código:

1. **`OpenFrontCard.battle_front_manager`** — campo runtime que NO viene del .tres ni se setea en `start_game`. Hoy lo asigna el flujo de jugado del jugador (probablemente `card_target_selector` u otro punto del state machine de cartas; no aparece en grep, así que toca verificar). El builder debe hacer `card.battle_front_manager = battle_front_manager` antes de llamar a `card.get_valid_targets(stats)`. Mismo motivo: `EnemyAdjacentCondition` lo necesita para filtrar tiles ya en frente.

2. **`BuildCard.buildings`** — sí viene sincronizado. `Stats.create_instance()` copia `possible_buildings` y llama `_sync_build_cards()` sobre `[deck, draw_pile, discard_pile, played_pile]`. `_apply_empire_ability()` añade exclusivos del imperio (vía `add_possible_building` que re-sincroniza). Las cartas robadas por la IA salen de `draw_pile` ya sincronizadas. ✅

3. **`RecruitCard.available_troops`** — `@export`, viene del .tres. ✅

4. **`TacticCard.get_valid_targets`** — lee scene tree (group `battle_front_visuals`). Para la IA hacemos adapter local que enumera desde `battle_front_manager.active_fronts` y filtra por `attacker_empire == stats.empire or defender_empire == stats.empire`. En `apply_effects` la TacticCard espera `targets[0] as BattleFrontVisual`, así que el builder debe resolver el visual correspondiente al frente justo antes de ejecutar (lookup por `visual.battle_front == front` sobre el group).

### Recursos por turno: gold acumulable, food per-turn

Importante para enumerar correctamente:

- **`stats.total_gold`** se acumula entre turnos (`stats.total_gold += stats.gold_per_turn` en `_process_turn_start`). Las condiciones de `BuildCard` y `RecruitCard` checkean `>= cost`.
- **`stats.food`** se reasigna cada turno (`stats.food = final_food`, no `+=`). Es un presupuesto por turno. Sólo lo consume `ChangeLocationTypeCondition` (`stats.food >= location_type.food_consumption`).

Esto significa que la IA, durante su bucle, debe re-enumerar tras cada jugada porque `stats.total_gold` puede haber bajado (Build/Recruit/Upgrade lo gastan al ejecutar el efecto, no antes).

### Verificaciones pendientes antes/durante Fase 1
- Confirmar **dónde se setea hoy `card.battle_front_manager` en el flujo del jugador**, para imitar el patrón. Si no se setea para el jugador y la `OpenFrontCard` confía en que ya está, hay un bug latente.
- ~~Confirmar que en `_create_ai_controllers()` la IA termina con `possible_buildings` no vacío.~~ **Resuelto:** confirmado por el usuario que `possible_buildings` empieza vacío y se llena diegéticamente vía eventos de turno (igual que para el jugador). Esto convierte el sistema de eventos en parte obligatoria del MVP — ver sección 1.C.

---

## 1.C. Eventos para la IA (REQUERIDO en el MVP)

### Por qué esta sección existe

Las `BuildCard` de la IA empiezan con `buildings = []`, igual que las del jugador. El array se rellena cuando un `TurnEvent` de la categoría CORE_PROGRESSION (u otro) ofrece desbloquear un edificio. Si la IA no resuelve eventos, **nunca podrá construir nada**. Por tanto resolver eventos no es feature opcional, es prerrequisito para que el bucle de cartas tenga sentido.

Más en general, principio de diseño confirmado: **la IA debe estar sometida al mismo flujo de eventos que el jugador**. Eventos de turno, eventos únicos, tiendas, etc.

### Cómo se resuelven hoy los eventos para el jugador

`PlayerHandler.evaluate_end_of_turn` llama a `_evaluate_end_of_turn` (heredado), que invoca `turn_event_manager.evaluate(context)`. Si hay evento, emite `Events.turn_event_triggered`, lo que `scene_manager` traduce en abrir `TurnEventPanel` o `ShopPanel` según el subtipo. El jugador clica una choice, hace selecciones secundarias (tile / carta) si la choice las pide, y al final se emite `Events.turn_event_resolved` (o `Events.shop_event_resolved`), que el `PlayerHandler` espera para terminar el turno.

### Cómo los resolverá la IA (random headless)

El `AIController` no debe abrir paneles. Crea un `AIEventResolver` que recibe `(TurnEvent, EventContext, RandomNumberGenerator)` y resuelve la decisión sin pasar por UI.

**TurnEvent normal:**
1. Filtrar `event.choices` por `choice.is_affordable(context)`.
2. Si `event.allow_skip`, añadir una choice virtual "skip" (la misma que crea `TurnEventPanel._populate_choices`).
3. Random entre las viables.
4. Si la choice elegida `needs_tile_input()`: pedir `choice.get_tile_effect().get_eligible_tiles(context)` y elegir tile random. Llamar `effect.execute_with_tile(tile, context.stats)` para el efecto de tile + `effect.execute(context)` para los demás (mismo patrón que `TurnEventPanel._on_tile_selected`).
5. Si la choice elegida `needs_player_input()`: identificar el `RemoveCardEventEffect` (u otro), pedir `effect.get_candidates(context.stats)`, elegir carta random, ejecutar todos los effects pasando la elegida.
6. Si no necesita inputs: `turn_event_manager.resolve(event, choice, context)`.
7. Marcar `unique` si aplica (esto hoy lo hace `scene_manager` para shops y `TurnEventPanel` para los demás — la IA debe replicar).

**ShopEvent:**
1. `shop_config = event.generate_shop(stats)`.
2. Por cada `item` en `shop_config.items`, decisión random: `if rng.randf() < 0.5 and item.can_afford(stats.total_gold): item.purchase(stats)`. Iterar mientras queden items y haya oro. (Nota: probabilidad fija a 0.5 para empezar; tunear si se ve que la IA acumula oro o se arruina.)
3. Decisión random sobre purgar (probabilidad baja, ej. 0.1, sólo si hay mazo grande). En esta v1 podríamos saltarlo entero — anotar como mejora.
4. Marcar `unique` y emitir `Events.shop_event_resolved`.

### Información que la IA NO debe ver al decidir en eventos

- **Mano, deck o discard del jugador.** El `EventContext` se construye desde el `Stats` propio del controlador, así que esto ya se respeta automáticamente — pero conviene auditar `EventContext.build` cuando lo toquemos.
- **Que un evento concreto haya salido al jugador.** `used_unique_events` es por imperio (vive en cada `Stats`), así que también se respeta.

### Principio de simetría de información (decisión de diseño confirmada)

La IA en este juego debe tener **exactamente la misma información que tiene el jugador**, ni más ni menos:
- ✅ Ve todo el mapa (no hay fog of war, igual que el jugador).
- ✅ Conoce a sus enemigos por adyacencia.
- ❌ NO conoce el deck/mano del jugador — y respetamos esto manteniendo `Stats` privado por controlador.

Mejora futura (NO en v1): un sistema de "memoria de cartas vistas" en la IA, que escuche `Events.card_played` filtrado por `controller != self` y mantenga un registro de cartas que el jugador ha jugado. Esto simula la información que un jugador humano tiene del rival al verle jugar. Anotado en `project_ai_changes.md`.

---

## 2. Diseño del bucle decisorio

### 2.1 La unidad de decisión: `AIPlayOption`

Toda jugada legal se representa como un objeto homogéneo. Esto es lo que la IA enumera y lo que después ejecuta. Permite enumerar y elegir random sin un `match` gigante.

```gdscript
class_name AIPlayOption extends RefCounted

var card:Card                   # carta que se va a jugar
var targets:Array[Node] = []    # 0..N targets resueltos (Tile, BattleFrontVisual, ...)
var payload:Dictionary = {}     # sub-decisiones (building elegido, tropa, source_tile…)

# Ejecución headless: se llama desde el AIController, no pasa por scene_manager
func execute(stats:Stats) -> void: ...
```

Cada subclase de `Card` (o un módulo de adaptadores en `scripts/empire/ai/options_builder.gd`) sabe enumerar sus propias `AIPlayOption`s. Yo prefiero **un enumerador externo** (`AIOptionsBuilder`) en lugar de ensuciar las Card con métodos `enumerate_ai_options`. Las Card ya tienen `get_valid_targets`; el builder las consulta y monta las options.

### 2.2 `AIOptionsBuilder.build_options(card, stats, battle_front_manager) -> Array[AIPlayOption]`

Tabla de cómo se enumera por tipo de carta (basado en lo que ya hay en `scripts/cards_resources/`):

| Card                         | Target          | Cómo enumerar                                                                                                                                                                                                                                                                                              |
|------------------------------|-----------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `ColonizeCard`               | TILE            | `card.get_valid_targets(stats)` → 1 option por tile.                                                                                                                                                                                                                                                       |
| `ChangeLocationTypeCard`     | TILE            | igual.                                                                                                                                                                                                                                                                                                     |
| `GenerateGoldCard`           | SELF            | 1 option, targets vacío.                                                                                                                                                                                                                                                                                   |
| `CardDrawCard`               | SELF            | 1 option, targets vacío.                                                                                                                                                                                                                                                                                   |
| `DirectBuildCard`            | TILE            | igual a Colonize (ya lleva el building incrustado).                                                                                                                                                                                                                                                        |
| `BuildCard`                  | TILE            | Por cada tile válida × por cada building del array `buildings` que `tile.can_build(b)` y `stats.total_gold >= b.construction_cost`. Payload `{building: Building}`. Bypass del `BuildingPanel`.                                                                                                            |
| `UpgradeBuildingCard`        | TILE            | Por cada tile con buildings upgradables × por cada par `(old_building, new_building)` legal. Payload `{old_building, new_building}`.                                                                                                                                                                       |
| `RecruitCard`                | SELF            | 1 option por troop de `available_troops` que `stats.can_afford_troop(t)`. Payload `{troop: Troop}`. Bypass del `RecruitPanel`.                                                                                                                                                                             |
| `OpenFrontCard`              | TILE (enemiga)  | Por cada tile enemiga válida × por cada tile propia adyacente. Payload `{source_tile, target_tile}`. Sólo se expone si la regla "una tile en un único frente" lo permite (consultar `BattleFront.is_tile_in_active_front`).                                                                               |
| `TacticCard`                 | BATTLE_FRONT    | Por cada frente activo del propio imperio. **Importante:** no leer `tree.get_nodes_in_group("battle_front_visuals")` (acoplamiento UI), sino enumerar a partir de `battle_front_manager.active_fronts` y resolver el `BattleFrontVisual` correspondiente al ejecutar.                                       |
| `RecoverCard`                | SELF            | 1 option por cada carta de `stats.played_pile`. Payload `{chosen_card: Card}`.                                                                                                                                                                                                                             |

**Nota sobre TacticCard:** lo dejaremos enumerable pero — al ser random uniforme — la IA va a malgastar muchas tácticas. Es lo que queremos para esta iteración. La duplicación de targets (visual vs frente) la resolveremos exponiendo un helper `BattleFrontManager.get_visual_for(front)` o, más limpio, refactorizando `TacticCard.get_valid_targets` para que devuelva los `BattleFront` directamente y dejar que `apply_effects` resuelva el visual. Tarea separada, fuera del MVP, pero conviene anotarla.

### 2.3 El bucle en `AIController`

Pseudo-código del nuevo `start_turn`:

```
start_turn():
  print/emit "ai turn started"
  _process_turn_start()                   # producción y modificadores (igual que ahora)
  _process_battle_fronts()                # tickeo de frentes (NUEVO: hoy no se hace)
  drawn = robar(_get_effective_cards_per_turn())
  hand = drawn.duplicate()

  iterations = 0
  while iterations < MAX_ITER and not hand.is_empty():
    options = []
    for card in hand:
      options.append_array(AIOptionsBuilder.build_options(card, stats, battle_front_manager))
    options.append(AIPlayOption.PASS)     # opción "no jugar nada y pasar"

    chosen = _rng.choose(options)
    if chosen.is_pass(): break

    Events.ai_card_played.emit(...)       # señal antes de aplicar
    chosen.execute(stats)                  # aplica efectos + Events.card_played
    hand.erase(chosen.card)
    _handle_card_played(chosen.card)       # discard / played_pile / return
    await get_tree().create_timer(AI_ACTION_DELAY).timeout
    iterations += 1

  for card in hand: stats.discard_pile.add_card(card)   # descartar el resto
  await get_tree().create_timer(AI_TURN_END_DELAY).timeout
  _evaluate_end_of_turn()                  # eventos (placeholder hoy, real cuando exista)
  _finish_turn()
```

Decisiones clave:

- **Re-enumerar tras cada jugada**, no una vez al principio: jugar una carta cambia el oro/tiles/buildings y por tanto las opciones legales del resto.
- **`AIPlayOption.PASS`** es una opción más, con un peso configurable (al inicio simplemente 1, igual que las demás). Esto da variabilidad: la IA a veces no jugará todo. Cuando metamos heurística, ese peso se podrá modular.
- **`MAX_ITER`** (constante, p.ej. 20) corta cualquier ciclo infinito provocado por una carta mal definida o un bug en el builder.
- **`AI_ACTION_DELAY`** ~0.9 s y **`AI_TURN_END_DELAY`** ~0.5 s. Configurables por export en `AIController` para poder bajarlos en tests (a 0).
- **RNG inyectable**: `var _rng:RandomNumberGenerator = RandomNumberGenerator.new()` con un `seed` opcional. En tests, fijamos seed para tener determinismo.

### 2.4 Bypass de los menús de confirmación

El jugador pasa por `BuildingPanel`, `RecruitPanel`, etc. La IA no. La forma limpia de hacerlo es que `AIPlayOption.execute` rellene directamente `card.chosen` / `card.old_building` / `card.source_own_tile` y llame a `card.apply_effects(targets, stats)` sin pasar por `card.confirm()`. No emitimos las señales `*_card_confirm_started` desde la IA.

Esto requiere que **no haya lógica esencial dentro de `confirm()`** que la IA se esté saltando. Revisado: hoy `confirm()` solo emite señales para abrir UI. Bien.

---

## 3. Presentación al jugador

Tres capas, en orden de importancia:

### 3.1 Floating label desde la tile (capa principal)

Nuevo nodo `AIActionFeedback` (autoload o nodo en `Map`) que escucha `Events.ai_card_played(card, tile_or_anchor, empire)` y spawnea un `Label3D` con billboard sobre la tile/frente afectado. Animación: aparece con tween de subida ~1 m + fade out (duración ~1.5 s). Texto: nombre/icono de la carta + color del imperio.

Archivo nuevo: `scripts/ui/ai_action_feedback.gd` y `scenes/ui/ai_floating_label.tscn`.

Para SELF cards (sin tile concreta) usamos como ancla la "capital" del imperio (la primera tile controlada; o un punto fijo en pantalla con un toast estilo notificación). De inicio: si no hay tile, no spawneamos floating y solo alimentamos el log.

### 3.2 Pacing y cámara (capa de soporte)

- El `await` entre acciones (sección 2.3) ya da el ritmo.
- **Opcional pero muy efectivo:** el `AIActionFeedback` puede emitir una señal `request_camera_focus(world_pos)` que el `Camera3D` escuche para hacer un pan suave. Lo dejo como capa opcional — si el cambio en `camera_3d.gd` es trivial, va dentro del MVP; si no, sale a una segunda iteración.

### 3.3 Mini-log lateral (capa de respaldo)

Pequeño `VBoxContainer` en la UI (esquina superior derecha) con últimas N entradas tipo `[Mongol] jugó "Construir minas" en (3,2)`. Persistente entre turnos (con un fade de las líneas viejas). Sirve cuando el jugador se distrae. Implementación trivial: un `Control` que escucha `Events.ai_card_played` y añade líneas.

Archivo nuevo: `scripts/ui/ai_action_log.gd` y `scenes/UI/ai_action_log.tscn`.

### 3.4 Señales nuevas en `Events.gd`

```gdscript
# Acciones de IA — para feedback visual
signal ai_card_played(card:Card, anchor_tile:Tile, empire:Empire, payload:Dictionary)
signal ai_turn_started(controller:EmpireController)
signal ai_turn_ended(controller:EmpireController)
```

`anchor_tile` puede ser `null` para cartas SELF; el feedback decide qué hacer en ese caso. `payload` lleva las sub-decisiones (ej. `{building_name: "Mina"}`) para enriquecer el texto del label/log.

Reaprovechamos las ya existentes `empire_turn_started/ended` para señales genéricas; las `ai_*` son **específicas de la presentación** (las consumen sólo la UI de feedback).

---

## 4. Archivos a crear / modificar

### Nuevos
- `scripts/empire/ai/ai_play_option.gd` — clase `AIPlayOption` (RefCounted) con `execute(stats)` y constante `PASS`.
- `scripts/empire/ai/ai_options_builder.gd` — `build_options(card, stats, bfm)`, un método estático con un `match` o un dispatcher por tipo de carta.
- `scripts/empire/ai/ai_event_resolver.gd` — resolución headless de TurnEvent/ShopEvent. Recibe `(event, context, rng)` y aplica la elección random; replica la lógica de `TurnEventPanel` y `ShopPanel` sin UI.
- `scripts/ui/ai_action_feedback.gd` — escucha `ai_card_played`, instancia floating labels.
- `scenes/UI/ai_floating_label.tscn` + `scripts/ui/ai_floating_label.gd` — el label 3D + tween de subida y fade.
- `scripts/ui/ai_action_log.gd` + `scenes/UI/ai_action_log.tscn` — log lateral.
- Tests (sección 5).

### Modificados
- `scripts/empire/ai_controller.gd` — sustituir el stub por el bucle real. Añadir export `_rng_seed`, `MAX_ITER`, `AI_ACTION_DELAY`, `AI_TURN_END_DELAY`.
- `scripts/events.gd` — 3 señales nuevas (`ai_card_played`, `ai_turn_started`, `ai_turn_ended`).
- `scenes/world_generation/map.tscn` — añadir nodos `AIActionFeedback` y `AIActionLog`.
- (Opcional) `scripts/cards_resources/tactic_card.gd` — refactor para que `get_valid_targets` opcionalmente acepte `bfm` y devuelva frentes en lugar de visuales. Si se hace, ajustar `card_target_selector` y los tests existentes de tácticas. Si no se hace, el builder hace el adapter localmente.

---

## 5. Tests GUT

Cada bloque del bucle decisorio se testea en aislamiento. Política del proyecto: ningún cambio funcional sin sus tests.

### 5.1 `tests/test_ai_options_builder.gd` (NUEVO)
Cubre la enumeración de `AIPlayOption` por tipo de carta:
- `test_colonize_enumerates_one_option_per_adjacent_uncontrolled_tile`
- `test_build_card_filters_by_gold_and_can_build`
- `test_build_card_enumerates_one_option_per_(tile, building)_pair`
- `test_recruit_card_filters_unaffordable_troops`
- `test_open_front_card_skips_tiles_already_in_a_front`
- `test_tactic_card_only_returns_own_battle_fronts`
- `test_self_target_cards_return_one_option_with_empty_targets`

Sin escena, sin renderizado: se construye un `Stats` mínimo con un `Empire` y unos pocos tiles mock (igual que `test_conditions_effects.gd` ya hace).

### 5.2 `tests/test_ai_controller.gd` (NUEVO)
Cubre el bucle del controlador:
- `test_with_seeded_rng_choices_are_deterministic` — fijo seed, espero la misma secuencia de cartas jugadas.
- `test_turn_terminates_within_max_iterations` — con un mock que siempre dé 1 opción, comprobar que respeta `MAX_ITER`.
- `test_pass_option_short_circuits_loop` — forzando que el random caiga en PASS, no juega ninguna carta.
- `test_emits_ai_card_played_per_action` — count de señales = cartas jugadas.
- `test_finishes_turn_emits_turn_finished` — la señal heredada se sigue emitiendo.
- `test_unplayed_cards_go_to_discard_pile` — al cortar el bucle, las cartas restantes se descartan.
- `test_re_enumerates_options_after_each_play` — tras jugar una BuildCard que gasta oro, las opciones del siguiente paso reflejan el oro nuevo.

Para que esto sea testable, los `await` deben usar un timer configurable; en tests fijamos `AI_ACTION_DELAY = 0` para no esperar de verdad.

### 5.3 `tests/test_ai_action_feedback.gd` (NUEVO)
Cubre el consumidor visual:
- `test_floating_label_spawns_when_ai_card_played_with_tile`
- `test_no_floating_label_when_anchor_tile_null`
- `test_label_disappears_after_animation`
- `test_log_appends_one_line_per_action`

### 5.4 `tests/test_ai_event_resolver.gd` (NUEVO)
Cubre la resolución headless de eventos:
- `test_picks_random_choice_among_affordable`
- `test_skip_choice_added_when_allow_skip`
- `test_unaffordable_choices_filtered_out`
- `test_tile_input_choice_picks_random_eligible_tile`
- `test_card_input_choice_picks_random_candidate`
- `test_unique_event_marks_used_after_resolve`
- `test_shop_event_purchases_subset_of_affordable_items`
- `test_shop_event_does_not_overspend`
- `test_resolver_uses_seeded_rng_for_determinism`

### 5.5 Modificar tests existentes
- `test_card_types.gd` — si refactorizamos `TacticCard.get_valid_targets`, hay que actualizar los asserts. Sólo si vamos por ese refactor.

---

## 6. Decisiones cerradas (acordado 2026-05-10)

1. **Una IA inicialmente.** Pacing acordado: ~0.9 s entre acciones, ~0.5 s al cerrar el turno. Configurable por export en `AIController` para poder bajarlo en tests. Si más adelante hay varias IAs y se nota lento, abrimos un slider "velocidad IA" en settings.

2. **Cámara: pan opcional con toggle en settings, off por defecto.** Implementación dentro del MVP si el cambio en `camera_3d.gd` es trivial; si no, sale a Fase 5.

3. **`TacticCard.get_valid_targets` no se refactoriza ahora.** En el `AIOptionsBuilder` haremos un adapter local que enumere frentes desde `BattleFrontManager.active_fronts` y resuelva el `BattleFrontVisual` sólo en el momento de ejecutar. Refactor anotado en memoria (`project_ai_changes.md`, sección "Refactors diferidos") para retomar cuando metamos heurística.

4. **Peso de la opción "pasar" = 1**, igual que cualquier otra option. Si en juego se observa que la IA pasa demasiado, bajamos el peso entonces.

5. **No se centraliza el coste de cartas.** Razón: hay cartas cuyo coste pertenece al efecto, no al hecho de jugarlas (construir cuesta lo que cueste el edificio, reclutar lo que cueste la tropa). Cada Card/Condition seguirá checkeando su propio coste como hace hoy. Anotado en `project_ai_changes.md` por si vuelve a discutirse.

---

## 7. Orden de implementación recomendado

Seis fases, cada una con tests que se quedan en verde antes de pasar a la siguiente.

1. **Fase 1 — Andamio sin presentación.** Crear `AIPlayOption` + `AIOptionsBuilder` con cobertura para los tipos de carta más simples (Colonize, GenerateGold, CardDraw, DirectBuild). Reescribir `AIController.start_turn` con el bucle, `await`, MAX_ITER, RNG. Tests `test_ai_options_builder.gd` (parcial) y `test_ai_controller.gd` (con sólo cartas simples).

2. **Fase 2 — Cobertura completa de cartas.** Añadir BuildCard, UpgradeBuildingCard, RecruitCard, OpenFrontCard al builder + bypass de menús. Ampliar tests.

3. **Fase 3 — TacticCard.** Adapter en el builder (sin tocar la card todavía) + tests.

4. **Fase 4 — Eventos de turno.** Crear `AIEventResolver`. Modificar `AIController._evaluate_end_of_turn` para invocar el resolver en lugar de emitir señales de UI. Cubrir TurnEvent (con/sin tile/card input, con/sin allow_skip, con/sin coste) y ShopEvent. Tests `test_ai_event_resolver.gd`. **Esta fase es la que desbloquea de verdad las BuildCards de la IA**, así que conviene verificar end-to-end manualmente al finalizarla.

5. **Fase 5 — Señales + feedback visual.** Añadir señales a `Events.gd`, emitirlas desde el bucle, crear `AIActionFeedback` + `AIFloatingLabel` + log. Tests.

6. **Fase 6 — Pacing/cámara final + cleanup.** Tunear delays, pan opcional, settings. Pase de tests completo.

Cada fase es mergeable independientemente: 1-4 dejan la IA jugando completamente y resolviendo eventos, sin más feedback que prints; la 5 mete el visual.

---

## 8. Riesgos y mitigaciones

- **Cuelgues por await**: si una excepción rompe el bucle entre `await`s, el turno IA puede dejar a `TurnManager` esperando. Mitigación: bloque `try/except` lógico en cada iteración + emit `turn_finished` siempre en `_finish_turn` con `defer`.
- **Cartas mal configuradas que devuelven options inválidas**: validación en `AIPlayOption.execute` que comprueba pre-condiciones antes de aplicar; si fallan, log y skip.
- **Save entre turno IA**: el sistema de save vive en `scripts/save/`. Hoy guarda al final del turno del jugador; conviene confirmar que no rompe si el guardado se dispara durante un turno IA. Recomendación: bloquear F5 (quicksave) mientras `AIController` está en su bucle y permitirlo solo entre controladores. Esto puede ser una tarea separada al final.
- **Tests con timers**: forzar `AI_ACTION_DELAY = 0` en `before_each`. Si los `await` siguen rompiendo el timing del test runner, usar señales internas en lugar de timers.

---

## 9. Resumen ejecutivo

Construimos `AIPlayOption` + `AIOptionsBuilder` para enumerar legalmente todas las jugadas; el `AIController` itera, elige al azar, ejecuta y espera. Para cada jugada se emite `Events.ai_card_played`, que un nuevo `AIActionFeedback` consume para mostrar un floating label sobre la tile y alimentar un mini-log. RNG con seed → tests deterministas; MAX_ITER → no se cuelga. Cinco fases, mergeable cada una. Antes de empezar, espero tu input sobre las cinco decisiones abiertas de la sección 6.
