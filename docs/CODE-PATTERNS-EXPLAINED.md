# 🎓 Guía Rápida - Cómo se Refleja la Arquitectura en el Código

## Principio: "Server Manda Siempre"

Cada parte del código ahora refleja este principio. Veamos cómo:

---

## 1. GameController → Intention Validator (No Local Rules)

### Código ANTES (❌ Incorrecto)

```gdscript
# ❌ VIEJO - GameController actuaba como Local Rules Engine
func request_play_card(card_instance, zone, position):
    if not game_rules.can_play_card(card_instance, cosmos):  # ❌ Decidía localmente
        return false
    if not game_rules.can_place_card(card_instance, zone, game_state, player):  # ❌ Decidía localmente
        return false
    
    game_state.modify_player_cosmos(...)  # ❌ Modificaba directamente
    game_state.add_card_to_zone(...)       # ❌ Modificaba directamente
    MatchManager.play_card(...)            # Solo forwardea despues
```

### Código DESPUÉS (✅ Correcto)

```gdscript
# ✅ NUEVO - GameController valida UX MÍNIMO, forwardea TODO al servidor
func request_play_card(card_instance: CardInstance, zone: String, position: int = -1) -> bool:
    # ✅ Validaciones MÍNIMAS (solo propiedades visibles)
    if not game_state.current_player == game_state.local_player:  # ¿Es mi turno?
        return false
    if not card_instance in game_state.get_hand_for_player(game_state.local_player):  # ¿Existe?
        return false
    if card_instance.is_exhausted:  # ¿Está agotada?
        return false
    
    # ⚠️ NO validamos costo, zona, efectos - eso decide SERVIDOR
    
    # ✅ Forwardea TODO al servidor
    match_manager.play_card(card_instance.instance_id, zone, position)
    return true
```

**Diferencia clave**: 
- ANTES: GameController DECIDÍA si era legal
- DESPUÉS: GameController PREGUNTAN AL SERVIDOR

---

## 2. CardPlayManager → Pure UX Validator (No Network)

### Código ANTES (❌ Incorrecto)

```gdscript
# ❌ VIEJO - CardPlayManager hacía HTTPRequest directo
func _send_play_card_request(card_instance, target_zone, target_slot):
    var http = HTTPRequest.new()  # ❌ HTTPRequest DIRECTO aquí
    add_child(http)
    http.request_completed.connect(_on_play_card_response.bind(http))
    
    var body = JSON.stringify({
        "card_instance_id": card_instance.instance_id,
        "zone": target_zone,
        "position": target_slot
    })
    
    var url = "http://localhost:3000/api/combat/play-card"  # ❌ URL HARDCODED
    http.request(url, headers, HTTPClient.METHOD_POST, body)  # ❌ DIRECTO
```

### Código DESPUÉS (✅ Correcto)

```gdscript
# ✅ NUEVO - CardPlayManager solo valida UX, forwardea a MatchManager
func play_card_to_field(card_instance: CardInstance, target_zone: String, target_slot: int) -> void:
    # ✅ Validar MÍNIMO de UX
    if not can_play_card(card_instance, 0):
        card_played.emit(card_instance, false)
        return
    
    # ✅ Forwardear a MatchManager (sin tocar network)
    if match_manager:
        match_manager.play_card(card_instance.instance_id, target_zone, target_slot)
        # MatchManager internamente usa APIClient + WebSocket
        # No hacemos HTTPRequest directo aquí
        _on_request_sent(card_instance)
    else:
        print("[CardPlayManager] ❌ MatchManager no disponible")
```

**Diferencia clave**:
- ANTES: CardPlayManager hacía HTTP directo
- DESPUÉS: CardPlayManager forwardea a MatchManager, que internamente usa APIClient

---

## 3. MatchManager → Único Punto de Entrada a Red

### Principio

```
┌─────────────────────────────────┐
│   Todo en cliente que toque      │
│   red DEBE pasar por:            │
│                                  │
│   MatchManager ← Aquí            │
│   ├─→ APIClient (HTTP)           │
│   ├─→ WebSocketManager (WS)      │
│   └─→ GameState (actualiza)      │
└─────────────────────────────────┘
```

### Código (Conceptual)

```gdscript
# ✅ CORRECTO - MatchManager es la puerta de entrada a red
func play_card(card_id: String, zone: String, position: int) -> void:
    # Internally uses APIClient
    APIClient.play_card({
        "card_instance_id": card_id,
        "zone": zone,
        "position": position
    })
    # Waits for WebSocket response via WebSocketManager
    # Then updates GameState


func _on_websocket_match_updated(match_data: Dictionary) -> void:
    # ✅ ÚNICO lugar donde se actualiza GameState
    game_state.update_from_server(match_data)  # ← Punto crítico
    match_state_updated.emit(match_data)
```

**Garantía**: SOLO MatchManager escribe GameState. Cero conflictos.

---

## 4. GameState → Espejo de Servidor (Read-Only)

### Cambio en Filosofía

```gdscript
# ❌ ANTES - GameState era mutable por cualquiera
game_state.modify_player_cosmos(3)  # Cualquiera puede modificar
game_state.add_card_to_field(...)   # Cualquiera puede modificar

# ✅ DESPUÉS - GameState solo se actualiza desde servidor
game_state.update_from_server(match_data)  # ← ÚNICO punto de escritura
```

**Código**:

```gdscript
# ✅ GameState es now "write-protected" de verdad
class_name GameState
extends Node

# Métodos públicos: SOLO lectura
func get_hand_for_player(player: int) -> Array:
    return _player_hands[player]

func get_player_cosmos(player: int) -> int:
    return _player_cosmos[player]

# Método "privado" (convención):  SOLO MatchManager lo llama
func _update_from_server_response(match_data: Dictionary) -> void:
    # Aquí se modifica basado en respuesta del servidor
    # MatchManager lo llama cuando WebSocket responde
    _player_cosmos[1] = match_data["player1_cosmos"]
    _player_cosmos[2] = match_data["player2_cosmos"]
    # ... etc
    state_changed.emit()
```

---

## 5. Flujo Completo - Cómo se Refleja en Código

### Paso 1: Usuario arrastra carta

```gdscript
# En GameBoard.gd
func _on_card_placed_in_slot(slot: CardSlot, card: Control):
    var card_instance = card.get_meta("card_instance")
    
    # ✅ Valida UX mínimo con GameController
    if not GameController.request_play_card(card_instance, "field_knight", 0):
        print("Movimiento inválido desde UX")
        return
```

### Paso 2: GameController valida mínimo

```gdscript
# En GameController.gd
func request_play_card(card_instance: CardInstance, zone: String, position: int) -> bool:
    # ✅ Validaciones MÍNIMAS (solo propiedades locales visibles)
    if game_state.current_player != game_state.local_player:
        return false
    if not card_instance in game_state.get_hand_for_player(game_state.local_player):
        return false
    
    # ✅ Forwardea AL SERVIDOR (no decide localmente)
    match_manager.play_card(card_instance.instance_id, zone, position)
    return true
```

### Paso 3: MatchManager forwardea

```gdscript
# En MatchManager.gd
func play_card(card_id: String, zone: String, position: int) -> void:
    # ✅ Usa APIClient (ÚNICO para HTTP)
    var response = await APIClient.play_card({
        "card_instance_id": card_id,
        "zone": zone,
        "position": position
    })
    
    # Espera respuesta del servidor via WebSocket
    # (No asume que fue exitoso localmente)
```

### Paso 4: Servidor responde

```
SERVIDOR (Node.js) valida TODO:
├─ ¿Costo suficiente?
├─ ¿Zona válida?
├─ ¿Efectos aplicables?
├─ Modifica su GameState
└─ Responde via WebSocket
```

### Paso 5: Cliente recibe y actualiza

```gdscript
# En WebSocketManager.gd
func _on_websocket_message(message: String) -> void:
    var data = JSON.parse_string(message)
    if data.type == "match_updated":
        MatchManager._on_match_updated(data.payload)  # ← Paso crítico

# En MatchManager.gd
func _on_match_updated(match_data: Dictionary) -> void:
    # ✅ ÚNICO lugar donde actualiza GameState
    game_state._update_from_server_response(match_data)
    
    # ✅ Emite signal para que UI reaccione
    match_state_updated.emit(match_data)

# En GameBoard.gd (escucha)
func _on_match_state_updated(match_data: Dictionary) -> void:
    render_all_zones()  # Re-renderiza con nuevo estado
```

---

## 6. TestBoard = Cliente con 2 Jugadores

### El Concepto

```gdscript
# ✅ TestBoard sigue el MISMO flujo que GameBoard
# Solo que controla ambos jugadores

class_name TestBoard
extends Control

var game_controller_p1: GameController
var game_controller_p2: GameController
var match_manager: MatchManager  # Mismo que GameBoard

func _on_player1_plays_card(card_id, zone, position):
    # ✅ Usa GameController para player 1
    game_controller_p1.request_play_card(card_id, zone, position)
    # → MatchManager.play_card(...)
    # → APIClient.play_card(...) [HTTP al servidor]
    # → Servidor valida
    # → WebSocket responde
    # → MatchManager actualiza GameState
    # → TestBoard re-renderiza

func _on_player2_plays_card(card_id, zone, position):
    # ✅ Usa GameController para player 2
    game_controller_p2.request_play_card(card_id, zone, position)
    # MISMO FLUJO que arriba
```

**Crucial**: TestBoard NO es "simulador local". Es cliente que controla 2 players.

---

## 7. Reglas de Código

### Checklist para cada método nuevo

```gdscript
# ✅ ¿Necesitas validar si algo es legal?
func validate_move(move):
    # ✅ Valida mínimo (propiedades visibles)
    if not game_state.has_property(move.property):
        return false
    # ⚠️ NO validas si es "LEGAL" - eso decide servidor
    return true


# ✅ ¿Necesitas enviar algo al servidor?
func send_action(action):
    # ✅ Usa MatchManager, no HTTPRequest directo
    MatchManager.send_action(action)
    # NO hagas:
    # var http = HTTPRequest.new()
    # http.request(...)


# ✅ ¿Necesitas actualizar GameState?
func update_state(new_data):
    # ✅ Solo desde MatchManager
    if self is MatchManager:
        game_state._update_from_server_response(new_data)
    else:
        # ⚠️ NUNCA hagas esto:
        # game_state.modify_cosmos(3)
        # game_state.add_card(card)
        push_error("No modificar GameState directamente")
```

---

## 📋 Resumen en Código

### Patrón Correcto

```gdscript
# ✅ SIEMPRE hacer así:

# 1. Validar mínimo (UX)
if not validate_ux_conditions():
    return false

# 2. Forwardear al servidor (via MatchManager)
MatchManager.send_action(action)

# 3. Escuchar respuesta
MatchManager.match_state_updated.connect(_on_state_updated)

# 4. Reaccionar a cambios (no anticipar)
func _on_state_updated(new_state):
    render_ui(new_state)  # Renderiza lo que SERVIDOR dice
```

### Patrón Incorrecto (❌ Nunca hacer)

```gdscript
# ❌ NUNCA hacer así:

# 1. Decidir localmente que algo es válido
if game_rules.is_move_legal(move):  # ❌ Client decides
    
    # 2. Modificar estado localmente
    game_state.apply_move(move)  # ❌ Direct modification
    
    # 3. Esperar estar seguro antes de enviar
    var result = http.request(...)  # ❌ Direct HTTP
    
    # 4. Asumir que funciona
    print("Move executed successfully")  # ❌ Optimistic update
```

---

## ✅ Validación

Cada archivo refactorizado ahora sigue estos patrones:

- ✅ [CardPlayManager.gd](scripts/game/CardPlayManager.gd) - Valida UX, forwardea
- ✅ [GameController.gd](scripts/rules/GameController.gd) - Valida UX, forwardea  
- ✅ [MatchManager.gd](scripts/managers/MatchManager.gd) - Coordina, actualiza GameState
- ✅ [GameState.gd](scripts/models/GameState.gd) - Read-mostly, update-from-server

---

**Documento de Referencia**  
**Lee esto cuando agregues nueva funcionalidad**

