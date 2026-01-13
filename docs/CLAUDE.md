# 🏛️ INSTRUCCIONES PARA CLAUDE - Arquitectura Real

**Documento Maestro de Referencia** para cualquier cambio futuro.

---

## 🎮 Principio Fundamental

```
🖥️ SERVIDOR (Node.js Express + WebSocket)
└─ AUTORIDAD ABSOLUTA
   ├─ Valida reglas
   ├─ Calcula daño
   ├─ Aplica efectos
   ├─ Modifica GameState
   └─ Responde a cliente

📱 CLIENTE (Godot 4)
└─ ESPEJO + ENTRADA
   ├─ Verifica mínimo de UX
   ├─ Envia intenciones
   ├─ Recibe GameState (espejo)
   └─ Renderiza + Anima
```

---

## 📡 Canales de Comunicación

### ✅ ÚNICOS Permitidos

```
HTTP REST:
Cliente ← HTTPRequest → APIClient.gd → HTTP → Servidor

WebSocket Real-time:
Cliente ← WebSocket → WebSocketManager.gd → WebSocket → Servidor
```

### ❌ PROHIBIDO Absolutamente

```
❌ HTTPRequest directo en GameController
❌ HTTPRequest directo en CardPlayManager
❌ HTTPRequest directo en CUALQUIER otro script excepto APIClient
❌ Cálculos de daño locales
❌ Validación de reglas complejas localmente
❌ Modificar GameState excepto desde MatchManager
```

---

## 🏗️ Arquitectura de Módulos

### 1. MatchManager (Autoload/Singleton)
**Archivo**: `scripts/managers/MatchManager.gd`  
**Responsabilidad**: Session + Event Dispatcher

```
ENTRADA (desde UI):
GameBoard → MatchManager.play_card()
GameBoard → MatchManager.declare_attack()
GameBoard → MatchManager.end_turn()

PROCESAMIENTO:
├─ Valida que la intención sea básicamente válida
├─ Forwardea a APIClient (HTTP) o crea WebSocket request
├─ Envía al servidor

SALIDA (desde servidor):
WebSocket event → MatchManager._on_match_updated()
├─ Recibe GameState actualizado
├─ Actualiza GameState.gd (espejo local)
├─ Emite signal match_state_updated
└─ GameBoard se re-renderiza automáticamente
```

**Métodos Clave**:
```gdscript
func play_card(card_id: String, zone: String, position: int) -> void
func declare_attack(attacker_id: String, defender_id: String) -> void
func end_turn() -> void
func _on_websocket_match_updated(match_data: Dictionary) -> void
```

---

### 2. GameController (Intention Validator)
**Archivo**: `scripts/rules/GameController.gd`  
**Responsabilidad**: Validador ligero + Forwarder

```
VALIDACIONES MÍNIMAS (cliente):
├─ ¿Es mi turno?
├─ ¿La carta existe en mi mano? (propiedades visibles)
├─ ¿El caballero está agotado? (propiedades visibles)
└─ ¿Estoy intentando jugar con mi propio caballero?

QUÉ EVITA:
├─ Cálculos de daño (server decide)
├─ Validación de costos (server decide)
├─ Validación de zonas (server decide)
├─ Aplicación de efectos (server decide)
└─ Modificar GameState (nunca, solo MatchManager)

FLUJO:
Usuario → GameBoard → GameController.request_play_card()
├─ Valida mínimo
└─ Forwardea a MatchManager.play_card()
```

**Métodos Clave**:
```gdscript
func request_play_card(card_instance: CardInstance, zone: String, position: int) -> bool
func request_attack(attacker_id: String, defender_id: String) -> bool
func request_end_turn() -> void
```

---

### 3. GameState (Data Mirror)
**Archivo**: `scripts/models/GameState.gd`  
**Responsabilidad**: Contenedor de datos (read-only)

```
QUIÉN LO MODIFICA:
└─ SOLO MatchManager (nunca nadie más)

QUE CONTIENE:
├─ Player hands
├─ Field knights/techniques
├─ Player life/cosmos
├─ Current phase
├─ Current player turn
└─ Metadata del match

MÉTODOS:
├─ get_hand_for_player(player: int) -> Array
├─ get_cards_in_zone(zone: String, player: int) -> Array
├─ get_player_cosmos(player: int) -> int
├─ get_current_phase() -> String
└─ get_current_player() -> int
```

**CRÍTICO**: GameState SOLO es modificado por MatchManager cuando recibe respuesta del servidor.

---

### 4. APIClient (HTTP Requests)
**Archivo**: `scripts/network/APIClient.gd`  
**Responsabilidad**: ÚNICO punto de HTTPRequest

```
TODOS los requests HTTP van aquí.
Nadie más hace HTTPRequest directo.

MÉTODOS:
├─ async play_card(body: Dict) -> Dict
├─ async declare_attack(body: Dict) -> Dict
├─ async end_turn() -> Dict
├─ async get_card_image(card_id: String) -> Texture2D
└─ ... otros requests REST
```

---

### 5. WebSocketManager (Real-time Events)
**Archivo**: `scripts/network/WebSocketManager.gd`  
**Responsabilidad**: Escuchador de WebSocket

```
ESCUCHA EVENTOS DEL SERVIDOR:
├─ match_found → Navega a GameBoard
├─ match_updated → Envía a MatchManager
├─ card_played → Información de que se jugó
├─ turn_changed → Cambio de turno
├─ match_ended → Fin de partida
└─ etc.

EMITE SIGNALS:
└─ match_state_updated(data: Dictionary)
```

---

### 6. GameBoard (Renderer + Input)
**Archivo**: `scenes/game/GameBoard.gd`  
**Responsabilidad**: UI pura

```
ESCUCHA:
├─ GameState.state_changed
├─ MatchManager.match_state_updated
├─ WebSocketManager.turn_changed
└─ etc.

ACCIONES DEL USUARIO:
├─ Cliquea carta → Valida con GameController
├─ Arrastra a campo → Valida con GameController
└─ Si OK → Forwardea a MatchManager

RENDERIZA:
├─ Cartas en mano
├─ Cartas en campo
├─ Cosmos, vida, fases
└─ Animaciones de cambios
```

---

### 7. CardPlayManager (Validador de UI)
**Archivo**: `scripts/game/CardPlayManager.gd`  
**Responsabilidad**: Validación específica de jugar cartas

```
SIMILAR A GameController pero más específico.

VALIDA:
├─ ¿Estoy en fase main?
├─ ¿La carta está en mi mano?
└─ ¿La carta existe?

FORWARDEA A:
└─ MatchManager.play_card() (nunca HTTPRequest directo)
```

---

## 🔄 Flujos de Datos CORRECTOS

### Flujo 1: Jugar una Carta

```
┌────────────────────┐
│   Usuario          │ Arrastra carta
└─────────┬──────────┘
          │
          ├─1─▶ GameBoard._on_card_placed_in_slot()
          │
          ├─2─▶ GameController.request_play_card()
          │     Valida: ¿es mi turno? ¿existe en mano?
          │
          ├─3─▶ MatchManager.play_card()
          │
          ├─4─▶ APIClient.play_card() [HTTP POST]
          │
          ▼
┌──────────────────────────┐
│    SERVIDOR              │
├─ Valida COMPLETAMENTE   │
├─ Costo suficiente?      │
├─ Zona válida?           │
├─ Efectos del card?      │
├─ Modifica GameState     │
└─────────┬────────────────┘
          │
          ├─5─▶ WebSocketManager (match_updated event)
          │
          ├─6─▶ MatchManager._on_match_updated()
          │     Actualiza GameState local
          │
          ├─7─▶ GameState.state_changed.emit()
          │
          ▼
    ┌──────────────────┐
    │   GameBoard      │ Se re-renderiza automáticamente
    │   Anima cambios  │
    └──────────────────┘
```

### Flujo 2: Atacar

```
┌────────────────────┐
│   Usuario          │ Cliquea "Atacar"
└─────────┬──────────┘
          │
          ├─1─▶ GameBoard._on_attack_button_clicked()
          │
          ├─2─▶ GameController.request_attack()
          │     Valida: ¿el knight existe? ¿en campo?
          │     NO valida: ¿puede atacar? (server decide)
          │
          ├─3─▶ MatchManager.send_attack()
          │
          ├─4─▶ APIClient.declare_attack() [HTTP POST]
          │
          ▼
┌──────────────────────────┐
│    SERVIDOR              │
├─ Valida legality       │
├─ ¿Modo evasión?        │
├─ ¿Defensor existe?     │
├─ Calcula daño          │
├─ Aplica efectos        │
├─ Modifica HP            │
└─────────┬────────────────┘
          │
          ├─5─▶ WebSocketManager (match_updated)
          │
          ├─6─▶ MatchManager (actualiza GameState)
          │
          ├─7─▶ GameState.state_changed.emit()
          │
          ▼
    ┌──────────────────┐
    │   GameBoard      │ Anima ataque + daño
    │   AudioManager   │ Toca sonidos
    └──────────────────┘
```

### Flujo 3: TestBoard (Cliente con 2 jugadores)

```
TestBoard.gd (Cliente que maneja 2 players)
├─ Tiene acceso a MatchManager
├─ Puede controlar Jugador 1 Y Jugador 2
│  ├─ Input Player 1 → GameController.request_play_card(player 1)
│  └─ Input Player 2 → GameController.request_play_card(player 2)
└─ PERO IGUAL necesita servidor para:
   ├─ Validar (costaría el cosmos? es legal?)
   ├─ Calcular (cuanto daño?)
   ├─ Aplicar (actualizar HP)
   └─ Confirmar (responder via WebSocket)

# TestBoard ≠ "simulador local"
# TestBoard = "cliente que maneja dos controllers"
# IGUAL depende del servidor
```

---

## ⚠️ Reglas de Oro

### ❌ NUNCA Hagas

```gdscript
# ❌ HTTPRequest directo fuera de APIClient
var http = HTTPRequest.new()
http.request(url, ...)

# ❌ Modificar GameState excepto desde MatchManager
game_state.player_cosmos -= 3
game_state.remove_card_from_hand(card_id)

# ❌ Calcular daño en cliente
var damage = attacker.attack - defender.defense

# ❌ Validar si ataque es "legal" localmente
if knight.has_exhausted_after_attack:
    # Nope. Server decides.

# ❌ Aplicar efectos localmente
knight.status_effects.append("stunned")

# ❌ Cambiar turno por lógica propia
current_player = 3 - current_player

# ❌ Tomar decisiones basadas en cálculos propios
if calculated_damage >= opponent_hp:
    // Nope. Server decides.
```

### ✅ SIEMPRE Haz

```gdscript
# ✅ Validar MÍNIMO de UX
if game_state.current_player != game_state.local_player:
    return false

# ✅ Verificar existencia (propiedades visibles)
var card = game_state.get_card_by_instance_id(card_id)
if not card:
    return false

# ✅ Forwardear al servidor
MatchManager.play_card(card_id, zone, position)

# ✅ Escuchar respuesta
MatchManager.match_state_updated.connect(_on_match_state_updated)

# ✅ Renderizar basado en GameState
var hand = game_state.get_hand_for_player(player_number)
for card in hand:
    create_card_display(card)

# ✅ Usar APIClient / WebSocketManager
# NUNCA HTTPRequest directo
```

---

## 🗑️ Qué Borrar del Cliente

### Borrrado (Pertenecen al Servidor)

- ❌ `GameRules.gd` - Validación compleja (server)
- ❌ `BattleCalculator.gd` - Cálculos de daño (server)
- ❌ `HandManager.gd` - Gestión de mano (server decidecambios)
- ❌ `FieldManager.gd` - Gestión de campo (server decide cambios)

### Refactorizado

- ⚠️ `CardPlayManager.gd` - Ya refactorizado (forwardea a MatchManager)
- ⚠️ `GameController.gd` - Ya refactorizado (validación mínima + forwarding)

---

## 📚 Responsabilidades por Módulo

| Módulo | Rol | ¿Network? | ¿Modifica GameState? | Ubicación |
|--------|-----|-----------|----------------------|-----------|
| **MatchManager** | Coordinador | ✅ WebSocket | ✅ Sí (mirror) | `scripts/managers/` |
| **GameController** | Validador UX | ❌ No | ❌ No | `scripts/rules/` |
| **CardPlayManager** | Validador cards | ❌ No | ❌ No | `scripts/game/` |
| **GameState** | Data mirror | ❌ No | ❌ Nunca | `scripts/models/` |
| **APIClient** | HTTP client | ✅ HTTP | ❌ No | `scripts/network/` |
| **WebSocketManager** | WS listener | ✅ WebSocket | ❌ No | `scripts/network/` |
| **GameBoard** | UI + Input | ❌ No | ❌ No | `scenes/game/` |

---

## 🎯 Checklist para Nueva Funcionalidad

Antes de implementar cualquier feature:

- [ ] ¿Necesita comunicación con servidor? → usa APIClient o WebSocketManager
- [ ] ¿Necesita validar legality? → valida MÍNIMO localmente, forwardea a servidor
- [ ] ¿Necesita calcular daño? → NUNCA en cliente, SIEMPRE en servidor
- [ ] ¿Necesita modificar GameState? → NUNCA directo, SIEMPRE via MatchManager
- [ ] ¿Es animación/UI? → escucha GameState changes
- [ ] ¿Requiere HTTPRequest? → usa APIClient
- [ ] ¿Requiere WebSocket? → usa WebSocketManager
- [ ] ¿Depende de datos del servidor? → espera MatchManager.match_state_updated signal

---

## 🔗 Referencia Rápida

**Para jugar una carta**:
```gdscript
GameController.request_play_card(card, zone, position)
  → MatchManager.play_card(...)
    → APIClient.play_card() [HTTP]
      → Servidor valida
        → WebSocketManager (match_updated)
          → MatchManager (GameState update)
            → GameBoard (re-renderiza)
```

**Para atacar**:
```gdscript
GameController.request_attack(attacker, defender)
  → MatchManager.send_attack(...)
    → APIClient.declare_attack() [HTTP]
      → Servidor calcula + aplica
        → WebSocketManager (match_updated)
          → MatchManager (GameState update)
            → GameBoard (anima)
```

**Para fin de turno**:
```gdscript
GameController.request_end_turn()
  → MatchManager.end_turn()
    → APIClient.end_turn() [HTTP]
      → Servidor procesa (reset cards, siguiente player)
        → WebSocketManager (match_updated + turn_changed)
          → MatchManager (GameState update)
            → GameBoard (nuevo turno)
```

---

## 📖 Documentación Relacionada

- `ARCHITECTURE-SERVER-AUTHORITATIVE.md` - Explicación detallada
- `NETWORK-ARCHITECTURE.md` - Diagrama de comunicación
- `GameRules.gd` - ⚠️ DEBE ESTAR EN SERVIDOR, NO EN CLIENTE
- `BattleCalculator.gd` - ⚠️ DEBE ESTAR EN SERVIDOR, NO EN CLIENTE

---

## 🚨 Errores Comunes a Evitar

1. **HTTPRequest directo en GameController**
   ```
   ❌ NUNCA hacer esto
   var http = HTTPRequest.new()
   http.request("POST", url, ...)
   
   ✅ Hacer esto
   MatchManager.play_card(...)  // Internamente usa APIClient
   ```

2. **Modificar GameState en múltiples lugares**
   ```
   ❌ NUNCA hacer esto
   GameController → modifica GameState
   MatchManager → también modifica GameState
   
   ✅ Hacer esto
   SOLO MatchManager modifica GameState
   GameController solo forwardea
   ```

3. **Calcular reglas en cliente**
   ```
   ❌ NUNCA hacer esto
   var can_attack = knight.attack > 0 && !knight.is_exhausted
   
   ✅ Hacer esto
   if knight.is_exhausted return false  // UX mínimo
   MatchManager.send_attack(...)  // Server decide si es legal
   ```

4. **Depender de cálculos locales**
   ```
   ❌ NUNCA hacer esto
   var lethal_damage = calculated_damage >= opponent_hp
   
   ✅ Hacer esto
   Esperar respuesta del servidor via WebSocket
   ```

---

**Documento Maestro**  
**Versión**: 1.0  
**Fecha**: Diciembre 22, 2025  
**Referencia obligatoria para cualquier cambio futuro**

