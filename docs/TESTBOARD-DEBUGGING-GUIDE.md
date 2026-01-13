# 🔍 TestBoard Debugging Guide

## Checklist Pre-Testing

Antes de probar TestBoard con el servidor, verifica estos puntos:

### ✅ Cliente Setup

- [x] TestBoard.gd compila sin errores
- [x] GameState.gd tiene todos los getters
- [x] MatchManager conectado a WebSocketManager
- [x] WebSocketManager conectado al servidor
- [x] AuthManager disponible (para user_id)
- [x] DecksManager disponible (para get_active_deck)
- [x] CardsManager disponible (para preload_deck_images)

### ✅ Servidor Setup

- [ ] POST /api/match/test endpoint implementado
- [ ] WebSocket handler para request_test_match
- [ ] GameState initialization en servidor
- [ ] Shuffle algoritmo implementado
- [ ] Draw cards lógica implementada
- [ ] Match persistence en BD

---

## 🎬 Testing Workflow

### Step 1: Abrir TestBoard

```gdscript
# En cualquier escena:
get_tree().change_scene_to_file("res://scenes/game/TestBoard.tscn")
```

**Esperado**: Tablero cargado, UI visible

**Posibles Errores**:
- `❌ MatchManager not found` → Verificar autoload en project.godot
- `❌ player_hand is null` → Verificar @onready paths en TestBoard.gd
- `❌ References not resolved` → Escena tiene todos los nodos necesarios

---

### Step 2: Click Botón TEST

**Usuario**: Click en botón "TEST"

**Esperado**: 
- Loading label visible: "Obteniendo mazo..."
- Console: `[TestBoard] 🎭 launch_test_match`
- Console: `[TestBoard] 1️⃣ Obteniendo mazo activo...`

**Posibles Errores**:

#### ❌ `❌ DecksManager no disponible`
```gdscript
# Causa: DecksManager no iniciado
# Solución: Verificar que DecksManager es autoload en project.godot
```

#### ❌ `❌ No hay mazo activo. Crea uno primero.`
```gdscript
# Causa: User no tiene deck, o active_deck no fue asignada
# Solución: Crear deck en CollectionScreen
# Verificar: DecksManager.get_active_deck() devuelve array vacío
```

#### ❌ `❌ El mazo necesita mínimo 40 cartas`
```gdscript
# Causa: Mazo tiene < 40 cartas
# Solución: Agregar cartas al mazo
```

---

### Step 3: Validación UX

**Esperado**:
- Loading label: "Validando mazo..."
- Console: `[TestBoard] 2️⃣ Validando mazo...`
- Console: `[TestBoard] ✅ Mazo válido: 40+ cartas`

**Posibles Errores**:

#### ❌ Falla silenciosa en validación
```gdscript
# Causa: Excepción en _validate_and_start_match()
# Debug: Agregar prints en cada punto

func _validate_and_start_match(deck: Array) -> void:
    print("DEBUG: deck size = ", deck.size())
    print("DEBUG: deck type = ", typeof(deck[0]))
```

---

### Step 4: Precargar Imágenes

**Esperado**:
- Loading label: "Precargando imágenes (background)..."
- Console: `[TestBoard] 3️⃣ Precargando imágenes...`
- Console: `[CardsManager] Descargando imagen...` (múltiples)
- Console: `[CardsManager] ✅ Preload completo`

**Posibles Errores**:

#### ❌ `⚠️ CardsManager no disponible`
```gdscript
# Causa: CardsManager no iniciado
# Solución: Verificar autoload
# Nota: Es no-fatal, solo no precarga
```

#### ❌ Descargas lentas
```gdscript
# Causa: Red lenta, servidor alejado
# Solución: Normal, solo tarda más
# El cliente continúa sin esperar
```

---

### Step 5: Pedir Servidor

**Esperado**:
- Loading label: "Iniciando partida en servidor..."
- Console: `[TestBoard] 4️⃣ Pidiendo al servidor crear partida TEST...`
- Console: `[MatchManager] 🎭 Pidiendo partida TEST al servidor...`
- Console: `[WebSocketManager] request_test_match()` (si debug enabled)

**Esto puede tardar 5-30s, esperando servidor**

**Posibles Errores**:

#### ❌ `Push error: No conectado`
```gdscript
# Causa: WebSocket no conectado
# Solución:
# 1. Verificar que WebSocketManager está inicializado
# 2. Verificar que servidor está corriendo
# 3. Verificar GameConfig.WS_URL correcto
# Debug: print(WebSocketManager._ws.get_state())
```

#### ❌ Timeout (espera > 30s sin respuesta)
```gdscript
# Causa: Servidor no responde
# Solución:
# 1. Verificar servidor está corriendo
# 2. Verificar endpoint POST /api/match/test implementado
# 3. Revisar logs del servidor
```

#### ❌ Error JSON parsing
```gdscript
# Causa: Respuesta del servidor no es válida
# Solución:
# 1. Verificar formato de respuesta del servidor
# 2. Debe ser valid JSON con keys esperadas
# 3. Revisar MatchManager._on_match_found()
```

---

### Step 6: Servidor Procesa

**En Servidor** (NO cliente puede ver):
- Validar mazo completamente
- Barajar cartas
- Roba 7 cartas P1, 7 P2
- Inicializar GameState
- Enviar respuesta WebSocket

**Tiempo esperado**: 1-5 segundos

**Posibles Errores**:

#### ❌ 400 Bad Request
```
Causa: Mazo inválido para el servidor
Solución: Revisar validadores del servidor
```

#### ❌ 500 Internal Server Error
```
Causa: Excepción en servidor
Solución: Revisar logs del servidor
Verificar:
  - Conexión a BD
  - Queries SQL
  - Shuffle algoritmo
```

---

### Step 7: Cliente Recibe Respuesta

**Esperado**:
- Console: `🔎 Match encontrado: {match data}`
- Console: `[MatchManager] match_found signal emitted`
- Console: `[TestBoard] 8️⃣ Partida iniciada! Renderizando GameState...`

**Posibles Errores**:

#### ❌ `GameState.from_server_data() error`
```gdscript
# Causa: Datos del servidor no tienen formato esperado
# Debug: Agregar prints en GameState.from_server_data()
# Verificar servidor devuelve:
#   - id, current_turn, phase, current_player
#   - player1_id, player2_id
#   - player1_life, player1_cosmos, player1_deck_size, player1_hand_count
#   - player2_life, player2_cosmos, player2_deck_size, player2_hand_count
#   - cards_in_play: Array[{id, card_id, zone, position, ...}]
```

---

### Step 8-9: Renderizar

**Esperado**:
- Loading label desaparece
- Tablero visible con:
  - [x] Mano del jugador (7 cartas)
  - [x] Mano oponente (7 dorsos)
  - [x] Contadores de mazo
  - [x] Vida y Cosmos
  - [x] Turno, Fase, Jugador actual
  - [x] Botón "End Turn" activo

**Console**:
```
[TestBoard] ✅ Tablero listo para jugar
```

**Posibles Errores**:

#### ❌ Mano vacía
```gdscript
# Causa: game_state.player_hand está vacío
# Debug: print(game_state.player_hand.size())
# Verificar: Servidor robó 7 cartas en cards_in_play?
# Verificar: Zona es "hand" y owner correcto?
```

#### ❌ Oponente sin dorsos
```gdscript
# Causa: opponent_hand_count es 0
# Debug: print(game_state.opponent_hand_count)
# Verificar: Servidor envió player2_hand_count?
```

#### ❌ Referencias null
```gdscript
# Causa: Nodos faltando en escena
# Verificar: @onready variables en TestBoard.gd
# Verificar: Paths correctos
# Debug: print(player_hand) en _ready()
```

#### ❌ CardDisplay setup error
```gdscript
# Causa: CardDisplay.setup() falla
# Debug: Verificar CardData tiene los campos necesarios
# Verificar: image_url válida
```

---

## 🔧 Debug Tools

### Habilitar Debug Prints

En TestBoard.gd:
```gdscript
# Al inicio de cada función, agregar:
print("[TestBoard] Entrando a _fetch_active_deck...")
print("[TestBoard] deck size = ", deck.size())
print("[TestBoard] GameState player_hand size = ", game_state.player_hand.size())
```

### Inspeccionar GameState

```gdscript
# En _on_match_started():
print("=== GameState Debug ===")
print("Match ID: ", game_state.match_id)
print("Turn: ", game_state.current_turn)
print("Phase: ", game_state.current_phase)
print("Player #: ", game_state.player_number)
print("Active Player: ", game_state.active_player_number)
print("Player Hand: ", game_state.player_hand.size())
print("Opponent Hand Count: ", game_state.opponent_hand_count)
print("Player Life: ", game_state.player_life)
print("Player Cosmos: ", game_state.player_cosmos)
print("Player Knights Field: ", game_state.player_field_knights.size())
print("========================")
```

### WebSocket State

```gdscript
# En _ready() o cualquier momento:
if WebSocketManager._ws:
    print("WS State: ", WebSocketManager._ws.get_state())
    # 0 = CONNECTING
    # 1 = OPEN
    # 2 = CLOSING
    # 3 = CLOSED
```

### Endpoint Verification

**Verificar servidor está respondiendo**:
```bash
# Terminal
curl -X POST http://localhost:3000/api/match/test \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"deck_id": "your-deck-id"}'
```

**Esperado**: Status 200, JSON con match data

---

## 🚨 Common Issues & Solutions

### Issue 1: Infinite Loading

**Síntomas**: Loading label nunca desaparece

**Causas posibles**:
1. Servidor no responde
2. Signal match_started nunca es emitida
3. MatchManager no inicializado

**Solución**:
```gdscript
# En TestBoard._request_start_test_match(), agregar timeout:
await get_tree().create_timer(30.0).timeout
if _is_loading:
    _show_error("Servidor no responde")
    _is_loading = false
```

---

### Issue 2: Mano Vacía

**Síntomas**: player_hand.size() == 0 pero debe haber 7 cartas

**Causas**:
1. Servidor no robó cartas
2. GameState no parseó correctamente
3. Cartas tienen owner_id diferente

**Debug**:
```gdscript
# En GameState.from_server_data():
print("Cards in play: ", cards_in_play.size())
for card in cards_in_play:
    print("  Card: zone=", card.zone, 
          " player=", card.player_number,
          " owner=", card.get("owner_id"))
```

---

### Issue 3: WebSocket Desconexión

**Síntomas**: Se conecta al inicio, pero mensaje match_found nunca llega

**Causas**:
1. Conexión cae después de iniciar
2. Servidor cierra conexión
3. Firewall/proxy bloquea

**Solución**:
```gdscript
# En WebSocketManager:
if WebSocketManager.connected.connect(_on_ws_connected):
    print("WS Connected")
if WebSocketManager.disconnected.connect(_on_ws_disconnected):
    print("WS Disconnected")

func _on_ws_connected():
    print("✅ WebSocket Connected")

func _on_ws_disconnected():
    print("❌ WebSocket Disconnected - Reconnecting...")
    WebSocketManager.connect_to_server()
```

---

## 📊 Console Output Expected

### Successful Test Flow

```
[TestBoard] 🎭 Inicializando tablero de prueba...
[TestBoard] ✅ Inicializado y escuchando servidor
[TestBoard] 0️⃣ Usuario apretó botón TEST...
[TestBoard] 1️⃣ Obteniendo mazo activo...
[DecksManager] GET /api/decks/active
[TestBoard] 2️⃣ Validando mazo...
[TestBoard] ✅ Mazo válido: 40 cartas
[TestBoard] 3️⃣ Precargando imágenes (background)...
[CardsManager] preload_deck_images() 40 cartas
[CardsManager] Descargando imagen... (x40)
[TestBoard] 4️⃣ Pidiendo al servidor crear partida TEST...
[MatchManager] 🎭 Pidiendo partida TEST al servidor...
[WebSocketManager] request_test_match() → send_event()

[Esperando servidor 5-30s...]

[MatchManager] 🔎 Match encontrado: {match data}
[TestBoard] 8️⃣ Partida iniciada! Renderizando GameState...
[TestBoard] === GameState Debug ===
[TestBoard] Match ID: uuid...
[TestBoard] Turn: 1
[TestBoard] Player Hand: 7
[TestBoard] ========================
[TestBoard] ✅ Tablero listo para jugar
```

---

## 🎯 Next Steps After Success

1. **Click End Turn Button**
   - Esperado: Turno cambia a 2
   - Console: `⏭️ Cambio de turno...`

2. **Jugar Carta** (Cuando implementado)
   - Drag & drop carta de mano a campo
   - Esperado: Actualización en GameState

3. **Atacar** (Cuando implementado)
   - Click caballero enemigo con atacante seleccionado
   - Esperado: Validación, daño calculado

---

## 📝 Logging Configuration

### Enable WebSocket Debug

En WebSocketManager.gd:
```gdscript
const DEBUG = true  # Agrega al inicio

func send_event(event_name: String, data: Dictionary) -> void:
    if DEBUG:
        print("[WSM] Sending event: ", event_name, " data: ", data)
    # ... resto del código
```

### Enable GameState Debug

En GameState.gd:
```gdscript
const DEBUG = true

static func from_server_data(data: Dictionary, local_player_id: String):
    if DEBUG:
        print("[GS] Parsing server data...")
        print("[GS] Match ID: ", data.get("id"))
        print("[GS] Cards in play: ", data.get("cards_in_play").size())
    # ... resto del código
```

---

**Última Actualización**: Diciembre 2025  
**Versión**: 1.0  
**Status**: Listo para debugging

