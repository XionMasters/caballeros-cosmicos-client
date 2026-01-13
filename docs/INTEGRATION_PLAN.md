# Plan de Integración - CardInstance y GameState

## 🎯 Objetivo
Integrar los nuevos modelos `CardInstance` y `GameState` en el código existente sin romper funcionalidad actual.

---

## 📋 Paso 1: Registrar los nuevos modelos en autoload

**Acción**: Agregar a `project.godot` (si no están ya):

```ini
[autoload]
CardInstance="*res://scripts/models/CardInstance.gd"
GameState="*res://scripts/models/GameState.gd"
```

O simplemente usar `class_name` (ya está en los archivos).

---

## 📋 Paso 2: Modificar GameBoard.gd para usar GameState

### Cambios necesarios:

**Antes:**
```gdscript
var current_match: Dictionary = {}
var game_state: Dictionary = {}
```

**Después:**
```gdscript
var current_match: Dictionary = {}
var game_state: GameState = null
var player_id: String
```

### Modificar `update_board()`:

**Antes:**
```gdscript
func update_board(state: Dictionary):
    game_state = state
    render_all_zones()
```

**Después:**
```gdscript
func update_board(state_data: Dictionary):
    # Crear GameState desde datos del servidor
    game_state = GameState.from_server_data(state_data, player_id)
    render_all_zones()
```

### Modificar `render_all_zones()`:

**Antes:**
```gdscript
func render_all_zones():
    var player_data = game_state.get("player", {})
    var hand = player_data.get("hand", [])
    for card_data in hand:
        _add_card_to_hand(CardData.from_json(card_data), {})
```

**Después:**
```gdscript
func render_all_zones():
    if not game_state:
        return
    
    # Renderizar mano usando CardInstance
    for card_instance in game_state.player_hand:
        _add_card_to_hand(card_instance)
    
    # Renderizar campo
    for i in range(5):
        var knight = game_state.player_field_knights[i] if i < game_state.player_field_knights.size() else null
        if knight:
            _place_card_in_slot(player_knight_slots[i], knight, false)
```

### Modificar `_add_card_to_hand()`:

**Antes:**
```gdscript
func _add_card_to_hand(card_data: CardData, card_in_play: Dictionary):
    var card_display = CARD_DISPLAY_TEMPLATE.instantiate()
    card_display.setup(card_data)
```

**Después:**
```gdscript
func _add_card_to_hand(card_instance: CardInstance):
    var card_display = CARD_DISPLAY_TEMPLATE.instantiate()
    card_display.set_meta("card_instance", card_instance)
    card_display.setup(card_instance.base_data)
    
    # Cargar imagen desde caché
    if CardsManager._image_cache.has(card_instance.base_data.id):
        card_display.set_card_image(CardsManager._image_cache[card_instance.base_data.id])
```

---

## 📋 Paso 3: Modificar CardSlot para emitir señales en vez de modificar estado

### Cambios en CardSlot.gd:

**Antes (MAL):**
```gdscript
func _drop_data(pos, data):
    # Coloca la carta directamente
    place_card(data["card_display"])
```

**Después (BIEN):**
```gdscript
signal card_play_attempted(card_instance: CardInstance, slot_index: int)

func _drop_data(pos, data):
    if not _can_drop_data(pos, data):
        return
    
    var card_instance = data["card_display"].get_meta("card_instance")
    card_play_attempted.emit(card_instance, slot_index)
```

### Conectar señal en GameBoard:

```gdscript
func _connect_all_slots():
    for i in range(player_knight_slots.size()):
        var slot = player_knight_slots[i]
        slot.card_play_attempted.connect(_on_card_play_attempted)

func _on_card_play_attempted(card_instance: CardInstance, slot_index: int):
    # Validar localmente
    if not game_state.can_play_card(card_instance):
        print("⚠ No puedes jugar esta carta ahora")
        return
    
    # Enviar al servidor via WebSocket
    WebSocketManager.play_card(card_instance.instance_id, slot_index)
```

---

## 📋 Paso 4: Integrar con WebSocketManager

### Agregar función en WebSocketManager.gd:

```gdscript
func play_card(instance_id: String, slot_index: int):
    send_action("play_card", {
        "instance_id": instance_id,
        "slot": slot_index
    })
```

### El servidor responde con nuevo `game_state`:

```gdscript
# En WebSocketManager al recibir "game_state_update"
{
    "type": "game_state_update",
    "state": { ... }  # Estado completo
}

# GameBoard recibe y actualiza
func _on_websocket_message(data: Dictionary):
    if data["type"] == "game_state_update":
        update_board(data["state"])
```

---

## 📋 Paso 5: Mostrar stats actuales en CardDisplay

### Modificar CardDisplay.setup():

**Antes:**
```gdscript
func setup(card: CardData):
    card_data = card
    # Solo imagen, sin texto
```

**Después (opcional, para mostrar HP actual):**
```gdscript
func setup(card: CardData, instance: CardInstance = null):
    card_data = card
    
    # Si es una instancia en juego, mostrar stats actuales
    if instance and instance.base_data.type == "caballero":
        # Opcional: crear label de HP/Stats dinámico
        var stats_text = "%d❤" % instance.current_health
        # Agregar label temporal si es necesario
```

---

## 📋 Paso 6: Modo de defensa/evasión en CardInstance

### Cuando el jugador activa modo defensa:

```gdscript
func _on_knight_action_selected(action: String, card_instance: CardInstance):
    match action:
        "defense_mode":
            WebSocketManager.send_action("set_mode", {
                "instance_id": card_instance.instance_id,
                "mode": "defense"
            })
        "evade_mode":
            WebSocketManager.send_action("set_mode", {
                "instance_id": card_instance.instance_id,
                "mode": "evade"
            })
```

### El servidor actualiza el `mode` del `CardInstance` y lo devuelve en el `game_state`.

---

## ✅ Resumen de Cambios

| Archivo | Cambio |
|---------|--------|
| `GameBoard.gd` | Usar `GameState` en vez de `Dictionary`, renderizar `CardInstance` |
| `CardSlot.gd` | Emitir `card_play_attempted` en vez de modificar directamente |
| `CardDisplay.gd` | Guardar `card_instance` en metadata |
| `WebSocketManager.gd` | Agregar `play_card()`, `send_action()` |
| `_add_card_to_hand()` | Recibir `CardInstance` en vez de `CardData` |
| `render_all_zones()` | Iterar sobre `game_state.player_hand` |

---

## 🚀 Orden de Implementación

1. ✅ **Crear `CardInstance.gd` y `GameState.gd`** (ya hecho)
2. Modificar `GameBoard.update_board()` para usar `GameState`
3. Modificar `_add_card_to_hand()` para recibir `CardInstance`
4. Modificar `CardSlot` para emitir señales
5. Integrar con `WebSocketManager`
6. Probar flujo completo: drag → signal → WS → servidor → update → render

---

## 🔥 Beneficios Inmediatos

✅ **Estado centralizado** en `GameState` - una sola fuente de verdad  
✅ **CardInstance** permite buffs, modos, estados alterados  
✅ **Separación clara** entre datos base (`CardData`) y estado en juego (`CardInstance`)  
✅ **Validaciones locales** antes de enviar al servidor  
✅ **Hover funciona correctamente** porque cada carta tiene su propio `instance_id`  

---

## 🎮 Próximo Paso

Empezar con **Paso 2**: Modificar `GameBoard.gd` para usar `GameState`.

¿Quieres que implemente eso ahora o prefieres hacerlo tú?
