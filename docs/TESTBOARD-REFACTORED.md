# 🎭 TestBoard - Refactorización Server-Authoritative

**Fecha**: 22 de Diciembre, 2025

---

## 📝 Resumen

TestBoard ha sido **completamente refactorizado** para seguir el patrón **Server-Authoritative**:

- ✅ Cliente obtiene mazo vía DecksManager
- ✅ Cliente valida UX mínimo (40 cartas, existe)
- ✅ Cliente precarga imágenes (opcional)
- ✅ Cliente **PIDE al servidor** crear partida
- ✅ Servidor hace TODO (valida, baraja, roba, decide turnos)
- ✅ Cliente renderiza estado del servidor
- ✅ Ambos jugadores controlados desde TestBoard

---

## 🎬 Flujo Exacto

### Cuando apretás "Test":

```
0️⃣ UI: Usuario aprieta botón "Test"
   └─ launch_test_match()

1️⃣ CLIENTE: Obtiene mazo activo
   └─ DecksManager.get_active_deck()
   └─ HTTP GET /decks/active → Server

2️⃣ CLIENTE: Valida UX mínimo
   └─ ¿Existe? ✅
   └─ ¿Tiene 40-100 cartas? ✅
   └─ TODO lo demás → No importa, server valida

3️⃣ CLIENTE: Precarga imágenes (background)
   └─ CardsManager.preload_deck_images()
   └─ Best effort, no bloquea

4️⃣ CLIENTE: Pide al servidor crear TEST
   └─ MatchManager.start_test_match()
   └─ WebSocketManager.request_test_match()
   └─ Envía: event "request_test_match"

5️⃣-6️⃣-7️⃣ SERVIDOR: Hace TODO
   ├─ Valida ambos mazos COMPLETO
   ├─ Crea instancias de cartas
   ├─ Baraja mazos
   ├─ Roba 6 cartas (ejemplo)
   ├─ Decide quién empieza (random)
   ├─ Inicializa GameState
   ├─ Aplica efectos pasivos iniciales
   └─ Responde: match_found + match_update

8️⃣ CLIENTE: Recibe respuesta del servidor
   └─ WebSocket → WebSocketManager
   └─ → MatchManager._on_match_found()
   └─ → GameState creado (espejo del servidor)
   └─ → match_started signal

9️⃣ CLIENTE: Renderiza
   └─ TestBoard._on_match_started()
   └─ render_all_zones()
   └─ Tablero listo para jugar
```

---

## 🔧 Cambios en el Código

### Métodos Nuevos

#### TestBoard.gd

```gdscript
launch_test_match()
  └─ Punto de entrada (UI apretó botón)

_fetch_active_deck()
  └─ DecksManager.get_active_deck() via HTTP

_validate_and_start_match(deck)
  └─ Validaciones UX mínimo
  └─ 40-100 cartas, existe

_preload_images_for_deck(deck)
  └─ CardsManager precarga en background

_request_start_test_match()
  └─ MatchManager.start_test_match()
  └─ Pide al servidor

_on_match_started(state)
  └─ Signal cuando servidor respondió
  └─ Renderiza GameState

_on_match_state_updated(match_data)
  └─ Signal cada vez que servidor actualiza
  └─ Re-renderiza

render_all_zones()
  └─ Renderiza TODO desde GameState

_render_player_zones()
  └─ Mano conocida + campo

_render_opponent_zones()
  └─ Dorsos + campo visible

_update_turn_display()
  └─ Turno, fase, stats

_on_end_turn_pressed()
  └─ Valida UX mínimo
  └─ Forwardea a MatchManager

_show_loading() / _hide_loading()
  └─ UI loading

_show_error()
  └─ UI error
```

#### MatchManager.gd

```gdscript
start_test_match()
  └─ Pide a WebSocketManager crear TEST
  └─ WebSocketManager.request_test_match()

send_attack(attacker_id, defender_id)
  └─ Nuevo método para atacar
```

#### WebSocketManager.gd

```gdscript
request_test_match()
  └─ Envía event "request_test_match" al servidor

declare_attack(match_id, attacker_id, defender_id)
  └─ Nuevo método para atacar vía WebSocket
```

---

## ✅ Validaciones Correctas

### CLIENTE valida (UX mínimo):

```
✅ ¿Existe el mazo?
✅ ¿Tiene 40-100 cartas?
✅ ¿Es mi turno? (para acciones)
✅ ¿La carta existe en mi mano?

❌ NO valida:
   - Balance de cartas
   - Compatibilidad entre cartas
   - Si costo es suficiente (server)
   - Si zona es válida (server)
   - Si ataque es legal (server)
   - Si hay daño (server calcula)
```

### SERVIDOR valida (COMPLETO):

```
✅ Validación COMPLETA de reglas
✅ Cálculos de daño
✅ Aplicación de efectos
✅ Decisiones de turno
✅ Cambios de estado
```

---

## 🎯 Puntos Clave

### 1. TestBoard es un Cliente Normal

```
❌ ANTES:
"TestBoard es un simulador local con sus propias reglas"

✅ AHORA:
"TestBoard es un cliente que maneja 2 players.
 Depende completamente del servidor."
```

### 2. GameState es Espejo del Servidor

```
TestBoard.game_state = GameState.from_server_data(...)

Todo lo que ves en TestBoard viene del servidor:
├─ Mazos (barajeados por servidor)
├─ Manos (robadas por servidor)
├─ Turno (decidido por servidor)
├─ Fase (decidida por servidor)
├─ Vida/Cosmos (asignados por servidor)
└─ Todo el resto
```

### 3. Flujo Siempre es el Mismo

```
Usuario Input
    ↓
Valida UX mínimo (GameController/TestBoard)
    ↓
Forwardea a servidor (MatchManager)
    ↓
Servidor procesa
    ↓
Servidor responde (WebSocket)
    ↓
MatchManager actualiza GameState
    ↓
UI renderiza automáticamente
```

---

## 🧪 Cómo Probar

1. **Abre Godot**
2. **Vé a Menú Principal**
3. **Apretá botón "Test"**
4. **Debería:**
   - [ ] Obtener mazo activo
   - [ ] Validar 40+ cartas
   - [ ] Precarga imágenes
   - [ ] Pide servidor crear TEST
   - [ ] Servidor responde con GameState
   - [ ] Renderiza tablero con 6 cartas en cada mano
   - [ ] Muestra turno actual
   - [ ] End Turn button funciona

---

## 📊 Arquitectura Final

```
TestBoard.gd
├─ launch_test_match() [UI entry point]
│
├─ _fetch_active_deck()
│  └─ DecksManager.get_active_deck()
│
├─ _validate_and_start_match(deck)
│  └─ UX mínimo validation
│
├─ _preload_images_for_deck(deck)
│  └─ CardsManager.preload_deck_images()
│
├─ _request_start_test_match()
│  └─ MatchManager.start_test_match()
│     └─ WebSocketManager.request_test_match()
│        └─ WebSocket event → Server
│
├─ _on_match_started(state) [Signal]
│  └─ render_all_zones()
│
├─ _on_match_state_updated(match_data) [Signal]
│  └─ render_all_zones()
│
└─ _on_end_turn_pressed()
   └─ MatchManager.end_turn()
```

---

## 🔒 Garantías

- ✅ **Servidor es autoridad**: Cliente NUNCA decide reglas
- ✅ **GameState único**: Solo MatchManager escribe
- ✅ **Sin conflictos**: No hay dos escritores simultáneos
- ✅ **Reproducible**: Mismo flujo en TestBoard y GameBoard
- ✅ **Multiplayer ready**: Funciona con múltiples clientes

---

## 📚 Referencia

| Archivo | Cambios |
|---------|---------|
| **scripts/game/TestBoard.gd** | Refactorizado completamente |
| **scripts/managers/MatchManager.gd** | Agregado `start_test_match()` y `send_attack()` |
| **scripts/managers/WebSocketManager.gd** | Agregado `request_test_match()` y `declare_attack()` |

---

## ⚠️ Próximas Tareas

**En Servidor** (Node.js):
- [ ] Endpoint POST `/api/match/test`
- [ ] Crear partida TEST
- [ ] Baraja y roba inicial
- [ ] Responder con match_found + match_update vía WebSocket

**En Cliente** (Godot):
- [ ] Testear flujo completo
- [ ] Manejar errores (servidor rechaza)
- [ ] Animar cambios de estado
- [ ] Implementar acciones de jugador

---

**Status**: ✅ TestBoard refactorizado  
**Listo para**: Pruebas con servidor real  
**Dependencia**: Servidor debe implementar `/api/match/test`

