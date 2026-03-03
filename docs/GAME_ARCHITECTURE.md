# Arquitectura del Sistema de Partidas

> Última actualización: Marzo 2026  
> Estado: refleja el código en producción

## Flujo de Navegación Real

```
LoginScreen → MainLobby → MatchSearch | match_test_button → GameMatch.tscn
```

- `menus/login/` — autenticación
- `menus/lobby/MainLobby.tscn` — hub principal tras login
- `menus/matchsearch/MatchSearch.tscn` — matchmaking PvP
- `menus/lobby/MatchTestButton.tscn` — acceso rápido a partida TEST
- `game/match/GameMatch.tscn` — escena de partida activa

> **Nota**: `game/board/GameBoard.gd` y `GameBoard.tscn` son una versión anterior (refactor v2, ~160 líneas).
> El controlador activo es `game/match/game_match.gd` (671 líneas). No confundirlos.

---

## Archivos Principales de Partida

### 1. `game/match/game_match.gd` + `GameMatch.tscn` — CONTROLADOR PRINCIPAL

**Responsabilidades**:
- Orquestar renderización delegando a controladores especializados
- Conectar señales de `MatchSessionService` (estado, fases, errores)
- Configurar animadores, hand controllers y slots al iniciar
- Gestionar modos de selección de acción (ataque, movimiento)
- Despachar acciones del jugador a `MatchSessionService`

**Flujo `_ready()`**:
```gdscript
_ready()
  ↓ obtener game_state de SceneTransition
  ↓ await 2 frames (nodos listos)
  ↓ conectar señales de MatchSessionService
  ↓ _setup_end_turn_button()
  ↓ _setup_card_slots()
  ↓ _setup_knight_actions_panel()
  ↓ _setup_card_deal_animator()
  ↓ _setup_hand_controllers()
  ↓ await _render_from_match_state()
  ↓ await timer 1s (precarga imágenes)
  ↓ MatchSessionService.on_gamematch_ready()  ← dispara primer turno
```

**Variables de estado interno**:
- `_pending_attacker_id`: ID del atacante esperando objetivo
- `_pending_move_id`: ID del caballero esperando destino
- `_is_selecting_attack_target / _is_selecting_move_target`: modos de selección

### 2. `game/controllers/` — CONTROLADORES DELEGADOS

| Archivo | Responsabilidad |
|---|---|
| `MatchFlowController.gd` | Fetch deck → validar → crear/reanudar partida |
| `MatchPlayController.gd` | Acciones en juego (jugar carta, fin de turno) |
| `MatchEventBridge.gd` | Puente entre eventos WS y el tablero |
| `MatchInitializer.gd` | Setup inicial de la escena de partida |

### 3. `game/match/PlayerHandController.gd` / `OpponentHandController.gd`

Gestionan la mano propia (con animaciones de robo) y la mano rival (dorsos).
Creados por `game_match.gd` como objetos GD (no nodos), no tienen escena propia.

### 4. `game/rules/GameController.gd`

Validador ligero de UX del lado cliente. **No** aplica lógica de juego.
Verifica condiciones mínimas (turno, agotamiento, pertenencia) antes de enviar al servidor.
Forwardea a `MatchSessionService`.

---

### 5. `cards/CardDisplay.gd` + `CardDisplay.tscn`

Representa visualmente una carta individual. Maneja hover, clic, drag & drop.
Instanciado por `game_match.gd` usando `CARD_DISPLAY_SCENE` preloadeado.

Señales relevantes: `card_clicked`, `card_double_clicked`, `drag_started`.

---

### 6. `game/zones/CardSlot.gd`

Representa un espacio del campo. Acepta drop de cartas y emite `card_dropped` y `slot_clicked`.
Los slots propios responden al menú de acciones de caballero; los rivales responden a confirmación de ataque.

### 7. Managers globales (autoloads)

| Manager | Responsabilidad |
|---|---|
| `managers/WebSocketManager.gd` | Conexión WS, envío/recepción de mensajes con el servidor |
| `managers/CardsManager.gd` | Caché de imágenes de cartas |
| `managers/TurnPhaseManager.gd` | Estado de fase actual del turno |
| `managers/AudioManager.gd` | Efectos de sonido y música |
| `managers/LocalizationManager.gd` | Traducciones (es/en/pt) |
| `managers/AuthManager.gd` | Token JWT, sesión del usuario |
| `managers/Signals.gd` | Bus de señales globales |

### 8. `shared/services/MatchSessionService.gd`

Autoload que centraliza el estado de la partida activa en el cliente.
Todo lo que `game_match.gd` envía al servidor pasa por aquí.
Observa eventos WS y emite señales hacia la escena (`match_state_updated`, `phase_changed`, `match_error`).

### 9. `data/CardInstance.gd` / `data/GameState.gd`

Modelos de datos de partida activa. `GameState` es snapshot del servidor; `CardInstance` representa una carta en juego con su estado (zona, modo, agotamiento).

---

## Flujos Completos

### 1. Iniciar partida TEST
```
MainLobby → MatchTestButton presionado
  ↓ MatchFlowController.start_test_match()
  ↓ DecksManager.fetch_user_decks()
  ↓ (deck listo) WebSocketManager.request_test_match()
  ↓ Servidor crea partida TEST, responde con match_found + match_update
  ↓ MatchSessionService recibe match_found → SceneTransition a GameMatch.tscn
  ↓ game_match.gd._ready() → carga estado → MatchSessionService.on_gamematch_ready()
  ↓ Servidor envía 1er match_update → _render_from_match_state()
```

### 2. Iniciar partida PvP
```
MainLobby → MatchSearch.tscn
  ↓ WebSocketManager.search_match()
  ↓ Servidor hace matchmaking FIFO
  ↓ Servidor responde match_found a ambos jugadores
  ↓ MatchSessionService → SceneTransition a GameMatch.tscn
```

### 3. Jugar una carta
```
Jugador arrastra CardDisplay desde HandLayout
  ↓ Suelta en CardSlot
  ↓ CardSlot emite card_dropped(payload)
  ↓ game_match._on_card_dropped_in_slot(payload)
  ↓ MatchSessionService.play_card(instance_id, zone, position)
  ↓ WebSocketManager.play_card() → send_match_event("play_card", {...})
  ↓ WS → servidor: { type: "PLAY_CARD", match_id, card_id, zone, position }
  ↓ Servidor valida + actualiza BD
  ↓ Servidor broadcast match_update a ambos jugadores
  ↓ MatchSessionService.match_state_updated emitida
  ↓ game_match._on_match_state_updated() → _render_from_match_state()
```

### 4. Atacar con un caballero (ver sección dedicada más abajo)

### 5. Fin de turno
```
Jugador presiona EndTurnButton
  ↓ game_match._on_end_turn_button_pressed()
  ↓ MatchSessionService.end_turn()
  ↓ WebSocketManager.end_turn(match_id)
  ↓ WS → servidor: { type: "END_TURN", match_id, action_id }
  ↓ Servidor valida + cambia turno
  ↓ Servidor broadcast match_update
  ↓ game_match re-renderiza + actualiza botón End Turn
```

---

---

## Flujo Detallado: Atacar con un Caballero

```
[1] Jugador clickea su propio knight slot
      ↓ CardSlot emite slot_clicked(slot)
      ↓ game_match._on_player_knight_slot_clicked(slot)
      ↓ (slot tiene carta, sin modo activo) knight_actions_panel.show_actions_for_knight(slot)

[2] Panel muestra opciones → jugador presiona "Batalhar (BA)"
      ↓ KnightActionsPanel._on_action_button_pressed("attack")
      ↓ _start_attack_mode() → action_selected.emit("attack", selected_knight_slot)

[3] game_match recibe signal action_selected
      ↓ _on_knight_action_selected("attack", source_slot)
      ↓ _pending_attacker_id = instance_id
      ↓ _is_selecting_attack_target = true
      (visual: el jugador debe seleccionar objetivo)

[4] Jugador clickea un slot rival
      ↓ CardSlot emite slot_clicked(slot)
      ↓ game_match._on_opponent_knight_slot_clicked(slot)
      ↓ (modo activo: _is_selecting_attack_target)
      ↓ defender_id = slot.card_instance.instance_id (vacío = daño directo)
      ↓ MatchSessionService.send_attack(_pending_attacker_id, defender_id)
      ↓ _is_selecting_attack_target = false

[5] MatchSessionService
      ↓ send_attack(attacker_id, defender_id)
      ↓ WebSocketManager.declare_attack(match_id, attacker_id, defender_id)

[6] WebSocketManager
      ↓ send_match_event("declare_attack", { match_id, attacker_id, defender_id })
      ↓ _to_match_action_type("declare_attack") → "ATTACK"
      ↓ send_event("match_action", { type: "ATTACK", match_id, attacker_id, defender_id, action_id })

[7] Servidor (TypeScript)
      ↓ websocket-router.ts recibe match_action
      ↓ matchesCoordinator.handleAction({ type: "ATTACK", ... })
      ↓ MatchCoordinator.attack(matchId, userId, attackerId, defenderId, actionId)
      ↓ AttackRulesEngine.ts: valida reglas, calcula daño (CE/AR/modo)
      ↓ Actualiza CardInPlay en BD (HP, zona yomotsu si muere)
      ↓ MatchStateService.buildBroadcastMatchState()
      ↓ broadcast match_update a ambos jugadores con perspectivas separadas

[8] Cliente recibe match_update
      ↓ MatchSessionService.match_state_updated.emit(data)
      ↓ game_match._on_match_state_updated()
      ↓ _render_from_match_state() → re-renderiza tablero completo
      ↓ MatchEffectsManager.play_attack_effect() (línea + número de daño)
      ↓ CombatAnimator.animate_attack() (dash del clon del atacante)
```

**Archivos involucrados en el ataque:**

| Capa | Archivo | Rol |
|------|---------|-----|
| UI | `ui/KnightActionsPanel.gd` | Panel que inicia el modo ataque |
| Orquestador | `game/match/game_match.gd` | Captura clicks, gestiona estado de selección |
| Validación cliente | `game/rules/GameController.gd` | Verifica mínimos (turno, agotamiento) antes de enviar |
| Servicio cliente | `shared/services/MatchSessionService.gd` | `send_attack()` → delega a WS |
| Transporte | `managers/WebSocketManager.gd` | `declare_attack()` → empaqueta y envía `match_action` |
| Enrutamiento servidor | `services/websocket/websocket-router.ts` | Recibe `match_action` tipo `ATTACK` |
| Coordinador servidor | `services/coordinators/matchesCoordinator.ts` | Delega a `MatchCoordinator.attack()` |
| Lógica de dominio | `engine/AttackRulesEngine.ts` | Calcula daño, valida modos, aplica resultado |
| Modelo | `models/CardInPlay.ts` | Registro de carta en juego (HP, zona, modo) |
| Efectos visuales | `game/MatchEffectsManager.gd` | Línea de ataque + número de daño flotante |
| Animación | `shared/effects/CombatAnimator.gd` | Dash del clon del atacante |
| Efecto flash | `shared/effects/AttackFlash.gd` | Flash sobre la carta impactada |

---

## Zonas del tablero

| Zona (`zone`) | Descripción |
|---|---|
| `hand` | Mano del jugador |
| `field_knight` | Slots de caballeros en campo (0–4) |
| `field_technique` | Slots de técnicas en campo (0–4) |
| `field_helper` | Slot del ayudante |
| `field_scenario` | Slot del escenario |
| `field_occasion` | Slot de ocasión |
| `yomotsu` | Cementerio |
| `exiled` | Cartas exiliadas |

---

## Guía de modificación

| Qué cambiar | Dónde ir |
|---|---|
| Agregar nueva acción de caballero | `ui/KnightActionsPanel.gd` + `game_match._on_knight_action_selected()` |
| Cambiar renderizado del tablero | `game/match/game_match.gd` → `_render_from_match_state()` |
| Cambiar cómo se arma el estado del servidor | `services/match/matchState.service.ts` |
| Agregar nuevo tipo de evento WS | `managers/WebSocketManager.gd` + `services/websocket/websocket-router.ts` |
| Cambiar animación de ataque | `shared/effects/CombatAnimator.gd` |
| Cambiar reglas de combate | `engine/AttackRulesEngine.ts` (servidor) |

---

## Checklist de debugging

1. ¿El WS está conectado? → `WebSocketManager.is_connected_to_server()`
2. ¿Llega `match_update`? → `print` en `MatchSessionService._on_match_update()`
3. ¿El `game_state` tiene las cartas? → `print(MatchSessionService.game_state)`
4. ¿El slot recibe clicks? → Verificar `mouse_filter` en `CardSlot`
5. ¿La acción llega al servidor? → Logs del servidor `[MatchesCoordinator]`
6. ¿El atacante está agotado? → `CardInstance.is_exhausted` en `GameState`
