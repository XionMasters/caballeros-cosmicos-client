# Sistema de Animaciones — Caballeros Cósmicos

## Índice

1. [El problema que resuelve](#1-el-problema-que-resuelve)
2. [Vista general del flujo](#2-vista-general-del-flujo)
3. [Componentes](#3-componentes)
   - [AnimationEvent](#animationevent)
   - [AnimationContext](#animationcontext)
   - [AnimationQueue](#animationqueue)
   - [StateDiffer](#statedifferw)
   - [AnimationOrchestrator](#animationorchestrator)
   - [Eventos concretos](#eventos-concretos)
4. [Cómo funciona un update del servidor](#4-cómo-funciona-un-update-del-servidor)
5. [El Visual Lockstep Queue](#5-el-visual-lockstep-queue)
6. [Cómo agregar una nueva animación](#6-cómo-agregar-una-nueva-animación)
7. [Estructura de archivos](#7-estructura-de-archivos)

---

## 1. El problema que resuelve

Antes del sistema, `GameMatch._render_all()` hacía esto:

```gdscript
_status_controller.render(gs, cm)
_field_renderer.render_field(gs)
player_hand_controller.update_from_state(gs)
opponent_hand_controller.update_from_state(gs)
await await_all([player_hand_controller.finished, opponent_hand_controller.finished])
```

El problema con ese enfoque:

- **No hay orden garantizado.** Si el jugador roba y el oponente ataca en el mismo update, todo pasa a la vez sin coordinación.
- **Solapamiento de updates.** Si llegan dos `match_state_updated` seguidos del servidor mientras las animaciones aún corren, el segundo pisaba al primero.
- **Difícil de extender.** Agregar "animar el ataque antes de mostrar el daño" requería meter `await` en muchos lugares.

El nuevo sistema separa en dos capas:

```
CAPA 1 — LÓGICA:    GameState (la verdad del juego, llega del servidor)
                         ↓
CAPA 2 — VISUAL:    AnimationQueue (muestra los cambios con timing correcto)
```

El estado se aplica primero, la capa visual lo interpreta después.

---

## 2. Vista general del flujo

```
Servidor
   │
   ▼ match_state_updated
GameMatch._on_match_state_updated()
   │
   ▼
AnimationOrchestrator.render_state(gs, cm)
   │
   ├─ [si _is_playing] → await playback_finished  ← LOCKSTEP
   │
   ├─ StateDiffer.compute(prev, next)
   │     └─ devuelve: [DrawCardsEvent, DrawOpponentCardsEvent, ...]
   │
   ├─ _build_queue(diff_events, gs, cm)
   │     └─ construye: [UpdateStatus] → [Draw+DrawOpp PARALELO] → [RenderField]
   │
   ├─ AnimationQueue.run(ctx)
   │     ├─ UpdateStatusEvent.play(ctx)       → síncrono
   │     ├─ PARALELO:
   │     │   ├─ DrawCardsEvent.play(ctx)      → anima cartas jugador
   │     │   └─ DrawOpponentCardsEvent.play() → anima dorsos oponente
   │     └─ RenderFieldEvent.play(ctx)        → sincroniza slots del campo
   │
   ▼
playback_finished.emit()
_prev_state = gs
```

---

## 3. Componentes

### AnimationEvent

**Archivo:** `game/animation/AnimationEvent.gd`  
**Tipo:** `RefCounted` (sin árbol de escena)

La clase base de la que hereda todo evento visual. Tiene una sola responsabilidad: saber cómo reproducirse.

```gdscript
class_name AnimationEvent
extends RefCounted

var label: String = "AnimationEvent"   # solo para logs

func play(ctx: AnimationContext) -> void:
    pass  # override en subclases
```

**Reglas al crear un evento:**
- Sobreescribir `play(ctx)`.
- Usar `await` dentro de `play()` para animaciones asíncronas.
- Guardar los datos que necesitás en el `_init()`.
- No guardar referencias a nodos — usar `ctx` en su lugar.

---

### AnimationContext

**Archivo:** `game/animation/AnimationContext.gd`  
**Tipo:** `RefCounted`

Un "sobre" con todas las referencias que los eventos necesitan para ejecutarse. Se crea una vez en `AnimationOrchestrator.setup()` y se pasa a cada `event.play(ctx)`.

```gdscript
var player_hand_ctrl: PlayerHandController
var opponent_hand_ctrl: OpponentHandController
var field_renderer: FieldRenderer
var status_ctrl: StatusPanelController
var effects_mgr: MatchEffectsManager   # puede ser null por ahora
var parent_node: Node                  # para get_tree(), create_tween(), etc.
```

**Por qué existe:** Los eventos son `RefCounted`, no tienen acceso al árbol de escena. En vez de pasarles referencias sueltas, reciben un contexto limpio. Cuando agregués más controladores, alcanza con agregarlos en `AnimationContext` — todos los eventos se benefician.

---

### AnimationQueue

**Archivo:** `game/animation/AnimationQueue.gd`  
**Tipo:** `RefCounted`

Almacena y ejecuta una lista de eventos con soporte de series y paralelos.

**API:**

| Método | Descripción |
|--------|-------------|
| `add(event)` | Agrega un evento para ejecutar en serie |
| `add_parallel([e1, e2])` | Agrega un grupo que se ejecuta al mismo tiempo |
| `await run(ctx)` | Ejecuta todo y vacía la cola |
| `await run_single(event, ctx)` | Ejecuta un evento puntual sin tocar la cola |
| `clear()` | Vacía la cola sin ejecutar |

**Cómo funciona el paralelismo:**

En GDScript 4, llamar una función `async` sin `await` inicia la coroutine hasta su primer `await`. Guardando todas las coroutines y haciéndoles `await` después, corren solapadas:

```gdscript
# Iniciar TODAS sin bloquear
var coroutines: Array = []
for event in events:
    coroutines.append(event.play(ctx))  # arranca inmediatamente

# Esperar a que TODAS terminen
for co in coroutines:
    await co
```

**Snapshot al inicio de `run()`:**

```gdscript
func run(ctx):
    var snapshot := _entries.duplicate()
    _entries.clear()
    # ... itera snapshot ...
```

Si durante la ejecución se agrega un evento nuevo (por ejemplo, un ataque que llega mientras se anima un robo), ese evento queda en `_entries` para la próxima llamada a `run()`. No se ejecuta a mitad del ciclo actual.

---

### StateDiffer

**Archivo:** `game/animation/StateDiffer.gd`  
**Tipo:** `RefCounted` (solo métodos estáticos)

Compara dos `GameState` y devuelve los eventos visuales que representan lo que cambió.

**Responsabilidad única:** detectar diferencias. NO decide orden ni paralelismo.

```gdscript
StateDiffer.compute(prev: GameState, next: GameState) -> Array
```

**Lo que devuelve según el caso:**

| Situación | Eventos devueltos |
|-----------|-------------------|
| `prev == null` (primer render) | `[DrawCardsEvent, DrawOpponentCardsEvent]` con label `InitialDraw:*` |
| Jugador robó cartas | `[DrawCardsEvent]` |
| Oponente robó o jugó cartas | `[DrawOpponentCardsEvent]` |
| Jugador jugó carta (mano decreció) | `[DrawCardsEvent]` (para eliminar la carta visual) |
| Sin cambios detectados | `[DrawCardsEvent(Sync), DrawOpponentCardsEvent(Sync)]` (para no desincronizarse) |

**Lo que NO devuelve:** `UpdateStatusEvent` ni `RenderFieldEvent`. Esos los agrega siempre el `AnimationOrchestrator` porque son necesarios en todos los updates.

**Helpers internos** (`_field_changed`, `_knight_arrays_differ`): detectan si algún slot del campo cambió de carta, modo o estado de agotamiento. Disponibles para que el Orchestrator los use en el futuro.

---

### AnimationOrchestrator

**Archivo:** `game/animation/AnimationOrchestrator.gd`  
**Tipo:** `Node` (necesita estar en el árbol para create_tween, get_tree, etc.)

El coordinador central. Es el único componente que conoce a todos los demás.

**Setup (desde `GameMatch._setup_controllers()`):**

```gdscript
_orchestrator = AnimationOrchestrator.new()
add_child(_orchestrator)
_orchestrator.setup(
    player_hand_controller,
    opponent_hand_controller,
    _field_renderer,
    _status_controller,
    null  # MatchEffectsManager — pasar cuando esté disponible en escena
)
```

**Punto de entrada principal:**

```gdscript
await _orchestrator.render_state(gs, match_data)
```

Internamente hace:
1. Lockstep: si `_is_playing`, espera `playback_finished` antes de continuar.
2. Llama a `StateDiffer.compute(prev, next)` para obtener los eventos de diff.
3. Construye la cola con `_build_queue()`.
4. Llama a `_flush_queue()` que ejecuta, resetea `_is_playing` y emite `playback_finished`.
5. Guarda `_prev_state = gs`.

**`_build_queue()` — el único lugar donde se decide el orden y el paralelismo:**

```
Cola resultante para un update normal:
[UpdateStatusEvent]              ← siempre primero, síncrono
[DrawCards + DrawOpponent]       ← paralelo si hay dos draws
[RenderFieldEvent]               ← siempre al final
```

**API para combate:**

```gdscript
await _orchestrator.play_attack(attacker_pos, defender_pos, damage, card_type)
```

Si hay animaciones corriendo: el `AttackEvent` se agrega al final de la `_queue` actual, respetando el pipeline.
Si no hay nada corriendo: se ejecuta inmediatamente con `run_single`.

**`reset_state()`:** Llamar cuando cambia la perspectiva (TestMatch). Borra `_prev_state` para que el próximo `render_state` se trate como primer render.

---

### Eventos concretos

Todos están en `game/animation/events/`.

| Clase | Cuándo se usa | Qué hace |
|-------|---------------|----------|
| `DrawCardsEvent` | Jugador roba / sync de mano | Delega a `PlayerHandController.update_from_state()` |
| `DrawOpponentCardsEvent` | Oponente roba / sync de mano | Delega a `OpponentHandController.update_from_state()` |
| `RenderFieldEvent` | Siempre al final del update | Llama a `FieldRenderer.render_field()` |
| `UpdateStatusEvent` | Siempre al inicio del update | Llama a `StatusPanelController.render()` |
| `AttackEvent` | Combate entre caballeros | Flash + número de daño vía `MatchEffectsManager` |

---

## 4. Cómo funciona un update del servidor

Ejemplo: el jugador termine su turno, el oponente roba 2 cartas y pone un caballero en el campo.

**Antes (state):**
```
player_hand: 5 cartas
opponent_hand_count: 4
opponent_field_knights: [null, null, null, null, null]
```

**Después (state):**
```
player_hand: 5 cartas
opponent_hand_count: 6   ← oponente robó 2
opponent_field_knights: [KnightX, null, null, null, null]  ← entró uno
```

**StateDiffer detecta:**
```
opponent_hand_count cambió (4 → 6) → DrawOpponentCardsEvent
```

**_build_queue construye:**
```
[UpdateStatusEvent]         ← actualizar vida/cosmos/contadores
[DrawOpponentCardsEvent]    ← (solo uno, va secuencial)
[RenderFieldEvent]          ← KnightX aparece en slot 0
```

**Visualmente:**
1. Contadores se actualizan (instantáneo)
2. 2 dorsos vuelan del mazo a la mano del oponente (animado)
3. KnightX aparece en el campo (cuando los dorsos ya llegaron)

---

## 5. El Visual Lockstep Queue

**El problema:** En un juego online, el servidor puede mandar dos updates seguidos muy rápido (por ejemplo: el oponente juega una carta y luego roba otra en el mismo frame).

**Sin lockstep:**
```
Update 1 llega → empieza animar robo (tarda 0.8s)
Update 2 llega → empieza animar al mismo tiempo → solapamiento, UI desincronizada
```

**Con lockstep:**
```
Update 1 llega → _is_playing = true → empieza animar
Update 2 llega → _is_playing == true → await playback_finished
                                           (espera)
Update 1 termina → playback_finished.emit()
Update 2 retoma → empieza animar con el estado correcto
```

Esto está implementado en `render_state()`:

```gdscript
if _is_playing:
    await playback_finished   # ← el lockstep

var diff_events = StateDiffer.compute(_prev_state, gs)
# ...
```

El segundo update siempre compara contra el GameState *más reciente* (`_prev_state` se guarda solo después de que terminan todas las animaciones), así nunca se pierde un diff.

---

## 6. Cómo agregar una nueva animación

### Caso A: nueva animación de estado (algo que cambia en el GameState)

**Paso 1:** Crear el evento en `game/animation/events/`:

```gdscript
# game/animation/events/ModeChangedEvent.gd
class_name ModeChangedEvent
extends AnimationEvent

var card_instance: CardInstance
var new_mode: String

func _init(ci: CardInstance, mode: String) -> void:
    label = "ModeChangedEvent"
    card_instance = ci
    new_mode = mode

func play(ctx: AnimationContext) -> void:
    # Buscar el CardDisplay del caballero en el campo y animarlo
    # ctx.field_renderer, ctx.parent_node, etc.
    await ctx.parent_node.get_tree().create_timer(0.3).timeout
```

**Paso 2:** Detectarlo en `StateDiffer._incremental_events()`:

```gdscript
# En StateDiffer.gd
for ci in next.player_field_knights:
    if ci == null:
        continue
    var prev_ci = _find_by_id(prev.player_field_knights, ci.instance_id)
    if prev_ci and prev_ci.mode != ci.mode:
        events.append(ModeChangedEvent.new(ci, ci.mode))
```

El Orchestrator lo va a encolar automáticamente en el bloque `others` de `_build_queue()` sin cambios adicionales.

---

### Caso B: animación disparada por acción del jugador (no por GameState)

Directamente desde el controlador que maneja la acción:

```gdscript
# Desde KnightActionController o game_match.gd
await _orchestrator.play_attack(
    attacker_slot.global_position,
    defender_slot.global_position,
    damage_result,
    "knight"
)
```

O crear cualquier evento manualmente:

```gdscript
var e = MiEfectoEspecialEvent.new(datos)
await _queue.run_single(e, _ctx)  # ejecutar sin encolar
```

---

### Caso C: secuencia de animaciones para combate completo

Cuando el servidor confirme un ataque, crear una secuencia:

```gdscript
# Futuro: en _build_queue() o en un método dedicado
_queue.add(AttackEvent.new(atk_pos, def_pos, damage))
_queue.add(DamageNumberEvent.new(def_pos, damage))
_queue.add(DeathEvent.new(defender_instance))  # si muere
await _flush_queue()
```

Todo en orden, sin `await` sueltos por el código.

---

## 7. Estructura de archivos

```
game/animation/
├── AnimationEvent.gd          ← clase base (solo play() y label)
├── AnimationContext.gd        ← porta referencias a todos los controladores
├── AnimationQueue.gd          ← ejecuta la cola: serie / paralelo / run_single
├── StateDiffer.gd             ← detecta qué cambió entre dos GameStates
├── AnimationOrchestrator.gd   ← coordinador central, lockstep, build_queue
└── events/
    ├── DrawCardsEvent.gd          ← jugador roba o actualiza mano
    ├── DrawOpponentCardsEvent.gd  ← oponente roba o actualiza mano (dorsos)
    ├── RenderFieldEvent.gd        ← sincroniza slots del campo
    ├── UpdateStatusEvent.gd       ← vida, cosmos, contadores de mazo
    └── AttackEvent.gd             ← flash de ataque + número de daño
```

**Punto de entrada desde `GameMatch`:**
```gdscript
# En _render_all():
await _orchestrator.render_state(gs, cm)

# Para ataques:
await _orchestrator.play_attack(attacker_pos, defender_pos, damage)
```

---

*Última actualización: Marzo 2026*
