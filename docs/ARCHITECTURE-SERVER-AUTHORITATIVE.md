# 🏛️ ARQUITECTURA REAL - Server-Authoritative

## Principio Fundamental

```
🖥️ SERVIDOR = Única verdad
├─ Valida reglas
├─ Calcula daño
├─ Aplica efectos
├─ Avanza turnos
└─ Modifica GameState

📱 CLIENTE = Espejo + Input
├─ Verifica UX mínimo
├─ Envía intenciones
├─ Recibe GameState del servidor
└─ Renderiza
```

---

## Canales de Comunicación

### ✅ PERMITIDOS (SOLO estos)

```
Cliente ←→ APIClient → HTTP REST → Servidor
Cliente ←→ WebSocketManager → WebSocket → Servidor
```

### ❌ PROHIBIDOS

```
❌ HTTPRequest directo en GameController
❌ HTTPRequest directo en CardPlayManager
❌ HTTPRequest directo en cualquier otro script
❌ Lógica de juego que no sea forwarding
```

---

## Componentes del Cliente

### 1. MatchManager (Autoload)
**Ubicación**: `scripts/managers/MatchManager.gd`  
**Rol**: Session Manager + Event Dispatcher

```gdscript
# QUÉ HACE:
├─ Escucha WebSocket del servidor
├─ Recibe GameState updates
├─ Modifica GameState (local = mirror del servidor)
├─ Emite signals para UI
├─ Coordina fase del turno
└─ Forwardea acciones del cliente al servidor

# QUÉ NO HACE:
❌ Validar si ataque es legal (el servidor lo hizo)
❌ Calcular daño (el servidor lo hizo)
❌ Aplicar efectos (el servidor lo hizo)
❌ Cambiar turno por lógica propia (el servidor lo hace)
```

**Métodos clave**:
```gdscript
func play_card(card_id: String, zone: String, position: int) -> void
    # Envía: POST /api/combat/play-card
    
func declare_attack(attacker_id: String, defender_id: String) -> void
    # Envía: POST /api/combat/declare-attack
    
func end_turn() -> void
    # Envía: POST /api/combat/end-turn
    
func _on_websocket_match_updated(match_data: Dictionary) -> void
    # Recibe del servidor
    # Actualiza GameState
    # Emite match_state_updated
```

---

### 2. GameController (Intention Validator)
**Ubicación**: `scripts/rules/GameController.gd`  
**Rol**: Client-side UX Validator + Forwarder

```gdscript
# QUÉ HACE:
├─ Valida condiciones MÍNIMAS de UX
│  ├─ ¿Estoy en fase MAIN?
│  ├─ ¿La carta está en mi mano?
│  ├─ ¿Puedo arrastrar esta carta? (solo propiedades visibles)
│  └─ ¿Hay espacio en el campo?
├─ Evita requests inútiles al servidor
└─ Forwardea a MatchManager si UX es OK

# QUÉ NO HACE:
❌ Calcular daño
❌ Validar si ataque es LEGAL (el servidor decide)
❌ Aplicar costos (el servidor lo hace)
❌ Modificar GameState
❌ Cambiar turnos
```

**Métodos clave**:
```gdscript
func can_play_card_from_hand(card_id: String) -> bool
    # Valida: ¿estoy en fase main? ¿existe la carta? ¿hay espacio?
    # Retorna: true/false
    
func request_play_card(card_id: String, zone: String, position: int) -> void
    # Si can_play_card_from_hand() == true
    # Llama: MatchManager.play_card(...)
    
func can_declare_attack(attacker_id: String) -> bool
    # Valida: ¿el caballero existe? ¿está en mi campo?
    # NO valida: ¿puede atacar? (eso lo decide el servidor)
    
func request_declare_attack(attacker_id: String, defender_id: String) -> void
    # Si can_declare_attack() == true
    # Llama: MatchManager.declare_attack(...)
```

---

### 3. GameState (Data Mirror)
**Ubicación**: `scripts/models/GameState.gd`  
**Rol**: Read-only data container

```gdscript
# QUÉ HACE:
├─ Almacena espejo del GameState del servidor
├─ Se actualiza vía MatchManager
├─ Emite signals cuando cambian datos críticos
└─ Proporciona métodos de lectura

# QUÉ NO HACE:
❌ Aplicar reglas
❌ Validar legality
❌ Ser modificado por nadie excepto MatchManager
```

**Métodos**:
```gdscript
func get_hand_for_player(player: int) -> Array
func get_cards_in_zone(zone: String, player: int) -> Array
func get_player_cosmos(player: int) -> int
func get_player_life(player: int) -> int
func get_current_phase() -> String
func get_current_player() -> int
# Solo lectura. Nunca modificar directamente.
```

---

### 4. APIClient (HTTP Communication)
**Ubicación**: `scripts/network/APIClient.gd`  
**Rol**: HTTP REST client

```gdscript
# ÚNICA fuente de HTTPRequest en el cliente
# Métodos:
├─ async get_decks() -> Array
├─ async get_active_deck() -> Deck
├─ async play_card(body: Dict) -> Dict
├─ async declare_attack(body: Dict) -> Dict
├─ async end_turn() -> Dict
└─ async get_card_image(card_id: String) -> Texture2D
```

**Regla**: TODOS los requests HTTP van acá. Nadie más.

---

### 5. WebSocketManager (Real-time Events)
**Ubicación**: `scripts/network/WebSocketManager.gd`  
**Rol**: WebSocket listener

```gdscript
# Escucha eventos del servidor:
├─ match_found
├─ match_updated → Envía a MatchManager
├─ card_played
├─ turn_changed
├─ match_ended
└─ etc.

# Emite:
signal match_state_updated(data: Dictionary)
signal turn_changed(player: int)
signal player_defeated(player: int)
```

---

### 6. GameBoard (Renderer + Input Handler)
**Ubicación**: `scenes/game/GameBoard.gd`  
**Rol**: Pure UI

```gdscript
# QUÉ HACE:
├─ Escucha GameState changes
├─ Renderiza cartas
├─ Renderiza cosmos, vida, fases
├─ Maneja input del usuario
│  └─ Valida que sea posible con GameController
│  └─ Forwarda a MatchManager si es OK
├─ Anima cambios
└─ Muestra feedback

# QUÉ NO HACE:
❌ Validar reglas
❌ Aplicar costos
❌ Calcular daño
❌ Modificar GameState
```

**Conexiones**:
```gdscript
# Escucha:
GameState.state_changed.connect(_on_game_state_changed)
MatchManager.match_state_updated.connect(_on_match_state_updated)
WebSocketManager.turn_changed.connect(_on_turn_changed)

# Llama:
GameController.request_play_card(...)
GameController.request_declare_attack(...)
MatchManager.end_turn()
```

---

## Flujos de Datos Correctos

### Flujo 1: Jugar una Carta

```
┌──────────────────┐
│   GameBoard      │ ← Usuario arrastra carta
└────────┬─────────┘
         │
         ├─1─▶ GameController.request_play_card()
         │     (Valida: ¿estoy en fase main? ¿existe?)
         │
         ├─2─▶ MatchManager.play_card()
         │     (Forwardea al servidor)
         │
         ├─3─▶ APIClient.play_card()
         │     (HTTP POST /api/combat/play-card)
         │
         ▼
┌──────────────────────────┐
│    SERVIDOR              │ ← Valida COMPLETO
├─ ¿es legal?             │
├─ ¿costo suficiente?     │
├─ ¿zona válida?          │
├─ Aplica efectos         │
├─ Modifica GameState     │
└────────┬─────────────────┘
         │
         ├─4─▶ WebSocketManager
         │     (match_updated event)
         │
         ├─5─▶ MatchManager._on_match_updated()
         │     (Actualiza GameState local)
         │
         ├─6─▶ GameState.state_changed.emit()
         │
         ▼
    ┌─────────────────┐
    │   GameBoard     │ ← Renderiza cambios
    └─────────────────┘
```

### Flujo 2: Atacar

```
┌──────────────────┐
│   GameBoard      │ ← Usuario cliquea "Atacar"
└────────┬─────────┘
         │
         ├─1─▶ GameController.request_declare_attack()
         │     (Valida: ¿el knight existe? ¿está en campo?)
         │     (NO valida: ¿puede atacar? eso decide servidor)
         │
         ├─2─▶ MatchManager.declare_attack()
         │
         ├─3─▶ APIClient.declare_attack()
         │     (HTTP POST /api/combat/declare-attack)
         │
         ▼
┌──────────────────────────┐
│    SERVIDOR              │ ← Valida COMPLETO
├─ ¿el knight no está      │
│  en modo evasion?        │
├─ ¿el defensor existe?    │
├─ Calcula daño           │
├─ Aplica daño            │
├─ Modifica HP             │
└────────┬─────────────────┘
         │
         ├─4─▶ WebSocketManager (match_updated)
         │
         ├─5─▶ MatchManager (actualiza GameState)
         │
         ├─6─▶ GameState.state_changed.emit()
         │
         ▼
    ┌─────────────────┐
    │   GameBoard     │ ← Anima ataque + daño
    └─────────────────┘
```

### Flujo 3: Fin de Turno

```
┌──────────────────┐
│   GameBoard      │ ← Usuario cliquea "End Turn"
└────────┬─────────┘
         │
         ├─1─▶ MatchManager.end_turn()
         │     (No hay validación en cliente)
         │
         ├─2─▶ APIClient.end_turn()
         │     (HTTP POST /api/combat/end-turn)
         │
         ▼
┌──────────────────────────┐
│    SERVIDOR              │ ← Procesa
├─ Reset cards exhausted   │
├─ Cambia current_player   │
├─ Dibuja carta            │
├─ Cambia fase a "draw"    │
└────────┬─────────────────┘
         │
         ├─3─▶ WebSocketManager (match_updated + turn_changed)
         │
         ├─4─▶ MatchManager (actualiza GameState)
         │
         ├─5─▶ GameState.state_changed.emit()
         │     GameState.turn_changed.emit()
         │
         ▼
    ┌──────────────────────┐
    │   GameBoard          │ ← Renderiza nuevo turno
    │  + AudioManager      │ ← Toca sonido
    └──────────────────────┘
```

---

## TestBoard = Cliente Normal

```
TestBoard.gd
├─ Tiene acceso a MatchManager (para enviar acciones)
├─ Tiene acceso a GameState (para leer estado)
├─ Puede controlar AMBOS jugadores
│  ├─ Jugador 1: Player 1 (tú controlas)
│  └─ Jugador 2: Player 2 (tú también controlas)
└─ Pero IGUAL necesita servidor para:
   ├─ Validar jugadas
   ├─ Calcular daño
   ├─ Aplicar efectos
   └─ Avanzar turnos

# TestBoard ≠ "simulador local"
# TestBoard = "cliente que maneja dos controllers"
```

---

## Reglas de Oro del Cliente

### ❌ NUNCA

```gdscript
# ❌ Calcular daño localmente
var damage = attacker.attack - defender.defense
defender.hp -= damage

# ❌ Validar si ataque es "legal" (eso decide servidor)
if knight.can_attack():
    // Nope. El servidor decide.

# ❌ Aplicar efectos localmente
knight.status_effects.append("stunned")

# ❌ Cambiar turno por lógica propia
current_player = 3 - current_player

# ❌ HTTPRequest directo en GameController
http.request("POST", "/api/play-card", ...)

# ❌ Modificar GameState excepto via MatchManager
game_state.player_cosmos -= 3

# ❌ Decisiones basadas en cálculos propios
if calculated_lethal_damage >= opponent_life:
    // Nope. El servidor decide si es mate.
```

### ✅ SIEMPRE

```gdscript
# ✅ Validar condiciones MÍNIMAS de UX
if game_state.current_phase != "main":
    return false  # No vale la pena enviar

# ✅ Verificar existencia de cartas (propiedades visibles)
var card = game_state.get_card_by_instance_id(card_id)
if not card:
    return false  # Carta no existe en estado visible

# ✅ Forwarding al servidor
MatchManager.play_card(card_id, zone, position)

# ✅ Escuchar respuesta del servidor
MatchManager.match_state_updated.connect(_on_match_state_updated)

# ✅ Renderizar basado en GameState
var hand = game_state.get_hand_for_player(current_player)
for card in hand:
    create_card_display(card)

# ✅ Usar APIClient/WebSocketManager para network
# (Nunca HTTPRequest directo)
```

---

## Responsabilidades por Módulo

| Módulo | Responsabilidad | ¿Toca Network? | ¿Modifica GameState? |
|--------|-----------------|---------------|----------------------|
| **MatchManager** | Coordina cliente + servidor | ✅ WebSocket | ✅ Sí (mirror del server) |
| **GameController** | Valida UX mínimo | ❌ No | ❌ No |
| **GameState** | Almacena datos | ❌ No | ❌ Nunca (solo MatchManager) |
| **APIClient** | HTTP requests | ✅ HTTP | ❌ No |
| **WebSocketManager** | WebSocket listener | ✅ WebSocket | ❌ No |
| **GameBoard** | Renderiza + input | ❌ No | ❌ No |
| **CardPlayManager** | ⚠️ DEBE REFACTORIZAR | ❌ Debe usar APIClient | ❌ No |

---

## Qué Borrar / Refactorizar

### ❌ Borrar

Toda documentación que diga:
- "GameController modifica GameState"
- "Simulación local de reglas"
- "Cálculos de daño en el cliente"
- "BattleCalculator es necesario en el cliente"
- "Modo single-player con reglas propias"
- Cualquier cosa sobre "game rules local"

### ⚠️ Refactorizar

**CardPlayManager.gd**:
```gdscript
# ACTUAL (❌ INCORRECTO):
func _send_play_card_request(card_instance, zone, slot):
    var http = HTTPRequest.new()  # ❌ DIRECTO
    http.request(url, headers, HTTPClient.METHOD_POST, body)

# DEBE SER (✅ CORRECTO):
func play_card_request(card_instance, zone, slot):
    MatchManager.play_card(card_instance.instance_id, zone, slot)
    # MatchManager → APIClient → HTTP
```

**GameController.gd**:
```gdscript
# ACTUAL (❌ PARCIALMENTE INCORRECTO):
func play_card(card, zone, position):
    game_state.modify_player_cosmos(...)  # ❌
    game_state.add_card_to_zone(...)      # ❌

# DEBE SER (✅ CORRECTO):
func request_play_card(card_id, zone, position):
    if not can_play_card_from_hand(card_id):
        return false
    MatchManager.play_card(card_id, zone, position)
    return true
```

---

## GameRules.gd y BattleCalculator.gd

### ¿Se borran?

**Depende**:

- **Si son SOLO para cliente**: ❌ Borrar. El servidor valida.
- **Si van al servidor (backend)**: ✅ Mantener (pero en servidor, no en cliente).

**Decisión recomendada**: 
```
🗑️ Borrar de cliente
🖥️ Implementar en servidor (backend)
```

---

## Resumen Final

```
CLIENTE (Godot)           SERVIDOR (Node.js)
─────────────────────────────────────────────
GameBoard                 GameRules ✅
  ├─ Input                  ├─ Valida
  └─ Render              BattleCalculator ✅
                           ├─ Calcula daño
GameController            GameController ✅
  ├─ Valida UX             ├─ Aplica efectos
  └─ Forwardea            GameState ✅
                           └─ Source of truth
MatchManager             MatchManager
  ├─ Escucha              ├─ Recibe requests
  └─ Mirror state        └─ Responde
  
APIClient                HTTPServer
  └─ HTTP REST           └─ Procesa requests

WebSocketManager         WebSocketServer
  └─ Escucha             └─ Envía updates
  
GameState               GameState
  └─ Mirror local       └─ Real en servidor
```

---

## Próxima Acción

1. ✅ Leer este documento
2. ✅ Confirmar que es el flujo esperado
3. ❌ Borrar documentación incorrecta
4. ✅ Refactorizar GameController.gd
5. ✅ Refactorizar CardPlayManager.gd
6. ✅ Eliminar GameRules.gd del cliente
7. ✅ Eliminar BattleCalculator.gd del cliente

---

**Documento Maestro de Referencia**  
**Guardar para siempre**  
**Consultar antes de hacer cambios**

