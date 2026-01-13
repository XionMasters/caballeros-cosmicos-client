# 🎭 TestBoard - Arquitectura Server-Authoritative

## Resumen Ejecutivo

TestBoard ha sido completamente refactorizado de **Local-Authoritative** a **Server-Authoritative**. El cliente ya **NO** hace cálculos de juego ni gestión de estado - todo es delegado al servidor.

### El Cliente Pide, El Servidor Decide

```
🎮 CLIENT                        ⚙️ SERVER
┌─────────────────┐             ┌──────────────────┐
│ 1. Get deck     │──────────►  │ 2. Validate      │
│ 2. Validate UX  │             │ 3. Shuffle       │
│ 3. Preload img  │             │ 4. Draw cards    │
│ 4. Request      │──────────►  │ 5. Start match   │
│ 5. Render       │◄────────── │ 6. Send GameState│
└─────────────────┘             └──────────────────┘
```

---

## 🔄 Flujo Completo de launch_test_match()

### 0️⃣ Usuario Aprieta Botón "TEST"

```gdscript
func launch_test_match() -> void:
    """Punto de entrada desde el menú"""
    _fetch_active_deck()
```

### 1️⃣ Obtener Mazo Activo (Cliente)

**Responsable**: `DecksManager`
**Comunicación**: HTTP → `/api/decks/active`
**Retorna**: Array de `CardData`

```gdscript
var deck = await DecksManager.get_active_deck()
```

**¿Qué sucede?**
- DecksManager hace llamada HTTP al servidor
- Servidor devuelve mazo del usuario
- RetornaArray de objetos `CardData`

---

### 2️⃣ Validar UX Mínimo (Cliente)

**IMPORTANTE**: Solo validamos UX, NO reglas de juego

**¿Qué validamos?**
✅ ¿Existe el mazo?
✅ ¿40-100 cartas?

**¿Qué NO validamos?**
❌ Balance de cartas
❌ Compatibilidad
❌ Reglas específicas

```gdscript
func _validate_and_start_match(deck: Array) -> void:
    if not deck or deck.is_empty():
        show_error("Mazo vacío")
        return
    
    if deck.size() < 40:
        show_error("Mínimo 40 cartas")
        return
    
    if deck.size() > 100:
        show_error("Máximo 100 cartas")
        return
```

---

### 3️⃣ Precarga de Imágenes (Cliente, Optional)

**Responsable**: `CardsManager`
**Impacto**: Best effort, no bloquea inicio

```gdscript
var cards_for_loading = []
for card_data in deck:
    cards_for_loading.append({
        "card_id": card_data.id,
        "image_url": card_data.image_url
    })

CardsManager.preload_deck_images(cards_for_loading)
```

**¿Qué sucede?**
- CardsManager descarga imágenes en background
- Emite signal `deck_images_preloaded` cuando termina
- Si falta una imagen después, se carga on-demand

---

### 4️⃣ Pedir al Servidor Crear Partida (Cliente)

**⚠️ PUNTO CLAVE**: Aquí es donde cambia el modelo

**Responsable**: `MatchManager` → `WebSocketManager`
**Comunicación**: WebSocket → `request_test_match` event

```gdscript
func _request_start_test_match() -> void:
    # MatchManager maneja todo
    MatchManager.start_test_match()
    
    # Internamente:
    # MatchManager.start_test_match()
    #   → WebSocketManager.request_test_match()
    #     → send_event("request_test_match", {})
```

**¿Qué hace el servidor?**
✅ Valida mazo completamente
✅ Baraja las cartas
✅ Roba 7 cartas para cada jugador
✅ Decide quién empieza
✅ Inicializa GameState
✅ Envía respuesta por WebSocket

---

### 5️⃣-7️⃣ Servidor Hace TODO (Automático)

El cliente no hace nada aquí. El servidor:

1. **Valida** mazo completo (balance, restricciones, etc)
2. **Baraja** las cartas usando seed aleatorio
3. **Roba** 7 cartas iniciales para P1 y P2
4. **Decide** quién empieza (aleatorio o regla)
5. **Inicializa** GameState con toda la información
6. **Responde** por WebSocket

---

### 8️⃣ Servidor Responde - Cliente Recibe (Automático)

**Comunicación**: WebSocket evento `match_found`

```gdscript
# En MatchManager, automáticamente:
func _on_match_found(data: Dictionary) -> void:
    # Crear GameState del servidor
    game_state = GameState.from_server_data(data, local_user_id)
    
    # Emitir signal a TestBoard
    match_started.emit(game_state)
```

**TestBoard escucha**:
```gdscript
MatchManager.match_started.connect(_on_match_started)

func _on_match_started(state: GameState) -> void:
    game_state = state
    render_all_zones()
```

---

### 9️⃣ Renderizar GameState (Cliente)

**GameState es el espejo del servidor**

```gdscript
func render_all_zones() -> void:
    # GameState contiene TODO del servidor:
    # - Mano (cartas conocidas)
    # - Campo (caballeros, técnicas, helpers)
    # - Mazos (contadores)
    # - Vidas, Cosmos
    # - Turnos, fases
    
    _render_player_zones()
    _render_opponent_zones()
    _render_decks()
    _update_turn_display()
```

---

## 📊 Estado Compartido: GameState

`GameState` es un **snapshot del servidor**, sincronizado por WebSocket.

```gdscript
class GameState:
    # Metadata
    match_id: String
    current_turn: int
    current_phase: String
    
    # Jugador local
    player_number: int
    player_hand: Array[CardInstance]
    player_life: int
    player_cosmos: int
    
    # Oponente (info limitada)
    opponent_hand_count: int  # Solo count, no tarjetas
    opponent_life: int
    opponent_cosmos: int
    
    # Métodos de consulta
    func get_hand_for_player(player_num: int) -> Array[CardInstance]
    func get_cards_in_zone(zone: String, player_num: int) -> Array[CardInstance]
    func get_player_life(player_num: int) -> int
    func get_player_cosmos(player_num: int) -> int
    func get_deck_size(player_num: int) -> int
```

---

## 🔄 Actualizaciones Continuas

Durante la partida, el servidor actualiza el GameState con cada evento:

```gdscript
# Servidor envía: match_update event
func _on_match_updated(data: Dictionary) -> void:
    # Actualizar GameState parcialmente
    game_state.apply_update(data, local_user_id)
    
    # Renderizar nuevamente
    render_all_zones()
```

**Ejemplos de eventos**:
- `card_played` - Alguien jugó una carta
- `turn_changed` - Cambió el turno
- `card_attacked` - Hubo un ataque
- `card_died` - Murió un caballero

---

## 🎯 Acciones del Jugador (TestBoard)

Todas las acciones forwardean al servidor:

```gdscript
# EndTurnButton
func _on_end_turn_pressed() -> void:
    # Validación UX: ¿Es mi turno?
    if game_state.current_player != player_number:
        return
    
    # Forwardear al servidor
    MatchManager.end_turn()
    
    # El servidor responde con match_update
    # → game_state se actualiza
    # → UI se renderiza automáticamente
```

**Patrón de Acción**:
```
UI Event
    ↓
MatchManager.action()
    ↓
WebSocketManager.send_event()
    ↓
Server validates & executes
    ↓
WebSocket match_update
    ↓
GameState.apply_update()
    ↓
render_all_zones()
```

---

## 🛠️ Componentes Clave

### DecksManager
**Responsabilidad**: Obtener mazos del servidor
- `get_active_deck()` → HTTP `/api/decks/active` → Array[CardData]
- Devuelve mazo del usuario logueado

### CardsManager
**Responsabilidad**: Precargar imágenes
- `preload_deck_images(cards)` → Background HTTP fetches
- `fetch_card_image(card_id, url)` → On-demand fetch
- Emite signal `deck_images_preloaded` cuando completa

### MatchManager
**Responsabilidad**: Coordinador cliente-servidor
- `start_test_match()` → Pide al servidor crear partida
- `end_turn()` → Pide al servidor pasar turno
- `send_attack()` → Pide al servidor ejecutar ataque
- Escucha WebSocket y actualiza GameState
- Emite signals: `match_started`, `match_state_updated`, `match_error`

### WebSocketManager
**Responsabilidad**: Comunicación WebSocket
- `request_test_match()` → Envía evento `request_test_match`
- `end_turn(match_id)` → Envía evento `end_turn`
- `declare_attack(match_id, attacker, defender)` → Envía evento `declare_attack`
- Escucha eventos del servidor
- Emite signals: `match_found`, `match_updated`, `match_error`

### GameState
**Responsabilidad**: Mirror del servidor
- `from_server_data()` → Construir desde respuesta del servidor
- `apply_update()` → Actualizar parcialmente
- Getters para consulta: `get_hand_for_player()`, `get_cards_in_zone()`, etc.

---

## ✅ Checklist: ¿Está Correcto?

### Cliente
- [x] Obtiene mazo vía HTTP (DecksManager)
- [x] Valida UX mínimo (40-100 cartas)
- [x] Precargar imágenes en background
- [x] Pide al servidor crear partida
- [x] NO hace cálculos de juego
- [x] NO baraja localmente
- [x] NO roba cartas
- [x] Renderiza GameState del servidor
- [x] Todas las acciones forwardean al servidor

### Servidor (TODO)
- [ ] Implementar POST `/api/match/test` endpoint
- [ ] Validar mazo completamente
- [ ] Barajar cartas con seed
- [ ] Robar 7 cartas iniciales
- [ ] Decidir quién empieza
- [ ] Responder con `match_found` event
- [ ] Continuar enviando `match_update` con cada acción

---

## 🚨 Errores Comunes

### ❌ Error 1: Cliente Modifica GameState Directamente
```gdscript
# INCORRECTO
game_state.player_life -= 3
```

**Corrección**:
```gdscript
# CORRECTO
MatchManager.declare_attack(attacker_id, defender_id)
# → Servidor calcula daño
# → Servidor envía match_update
# → GameState se actualiza automáticamente
```

### ❌ Error 2: Validar Reglas en Cliente
```gdscript
# INCORRECTO
if card.cost > player_cosmos:
    show_error("Cosmos insuficiente")
```

**Corrección**:
```gdscript
# CORRECTO (dejar que servidor valide)
MatchManager.play_card(card_id, zone, position)
# Servidor responde con error si no es válido
```

### ❌ Error 3: Renderizar Antes de GameState
```gdscript
# INCORRECTO
launch_test_match()
render_all_zones()  # ← GameState aún es null
```

**Corrección**:
```gdscript
# CORRECTO (esperar al signal)
MatchManager.match_started.connect(_on_match_started)

func _on_match_started(state: GameState) -> void:
    game_state = state
    render_all_zones()  # ← GameState tiene datos
```

---

## 📝 Archivos Modificados

1. **TestBoard.gd**
   - Eliminó todo código local de juego
   - Implementó 9 pasos del flujo server-authoritative
   - Agregó renderizado desde GameState

2. **GameState.gd**
   - Agregó métodos getter para TestBoard:
     - `get_hand_for_player()`
     - `get_cards_in_zone()`
     - `get_deck_size()`
     - `get_player_life()`
     - `get_player_cosmos()`

3. **MatchManager.gd**
   - Verificado `start_test_match()`
   - Verificado `end_turn()`
   - Verificado `send_attack()`

4. **WebSocketManager.gd**
   - Verificado `request_test_match()`
   - Verificado `declare_attack()`
   - Verificado `end_turn()`

---

## 🧪 Testing

### Test Manual
1. Click en botón "TEST" desde MainLobby
2. TestBoard obtiene mazo activo
3. Valida cartas (40-100)
4. Precarga imágenes
5. Pide al servidor crear partida
6. Espera 5-10 segundos
7. Tablero se renderiza con GameState del servidor
8. Turno muestra correctamente
9. Vidas y Cosmos muestran
10. Botón "End Turn" forwardea al servidor

### Dependencias
- ✅ DecksManager.get_active_deck()
- ✅ CardsManager.preload_deck_images()
- ✅ MatchManager.start_test_match()
- ✅ GameState.from_server_data()
- ✅ GameState.get_*() getters
- ⏳ **Server**: POST /api/match/test endpoint
- ⏳ **Server**: WebSocket match_found + match_update

---

## 🎯 Próximos Pasos

### Servidor (Backend)
1. Implementar POST `/api/match/test` endpoint
2. Crear partida con `mode="test"`
3. Enviar respuesta WebSocket `match_found` con GameState
4. Implementar validadores de turno
5. Implementar handlers de acciones (attack, play_card, end_turn)

### Cliente (Frontend)
1. Agregar feedback visual (spinner, mensajes)
2. Implementar play_card UI (drag & drop)
3. Implementar declare_attack UI (click target)
4. Implementar animaciones (card fade, damage popup)
5. Agregar chat en-game

---

**Última Actualización**: Diciembre 2025
**Versión**: 2.0 - Server-Authoritative
**Estado**: ✅ Cliente Refactorizado, ⏳ Servidor Pendiente

