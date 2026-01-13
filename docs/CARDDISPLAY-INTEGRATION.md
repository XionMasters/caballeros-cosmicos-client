# CardDisplay - Guía de Integración

## 🎯 Responsabilidades de CardDisplay

CardDisplay es un **componente visual + entradas del jugador**, NO contiene lógica de juego.

### ✅ SÍ hace:
- Mostrar imagen de carta
- Capturar clicks, doble clicks, drag
- Animaciones visuales (hover, highlight, spawn)
- Estados visuales (disabled, exhausted, highlighted)
- Sincronización con CardInstance

### ❌ NO hace:
- Validar si puede jugarse (eso es GameBoard)
- Cambiar su posición (eso es HandLayout/CardSlot)
- Manejar lógica de turnos (eso es GameState)
- Comunicarse con servidor (eso es MatchManager)

---

## 🔌 Integración con HandLayout

HandLayout controla el **layout físico** de las cartas en la mano.

### Responsabilidades de HandLayout:
- Posicionar cartas en abanico
- Escalar cartas en hover
- Elevar carta activa (z-index)
- Animar transiciones

### Cómo HandLayout usa CardDisplay:

```gdscript
# HandLayout.gd
func add_card(card_display: CardDisplay):
    # Desactivar hover interno de CardDisplay
    card_display.disable_hover_animation = true
    
    # Conectar señales de hover (HandLayout controla)
    card_display.mouse_entered.connect(_on_card_hover.bind(card_display))
    card_display.mouse_exited.connect(_on_card_hover_end.bind(card_display))
    
    add_child(card_display)
    arrange_cards()

func _on_card_hover(card_display: CardDisplay):
    # HandLayout escala la carta, no CardDisplay
    card_display.z_index = 100
    var tween = create_tween()
    tween.tween_property(card_display, "scale", Vector2(1.1, 1.1), 0.15)
```

**Flujo correcto:**
1. CardDisplay solo muestra la carta
2. HandLayout captura mouse_entered/exited
3. HandLayout controla animaciones de posición/escala
4. CardDisplay mantiene estados lógicos (disabled, exhausted)

---

## 🎮 Integración con GameBoard

GameBoard es el **controlador maestro** de la partida.

### Responsabilidades de GameBoard:
- Actualizar estado según turnos
- Validar qué cartas son jugables
- Comunicarse con servidor
- Aplicar efectos de CardInstance

### Cómo GameBoard usa CardDisplay:

```gdscript
# GameBoard.gd
func update_hand_state():
    """Actualizar estado de todas las cartas en mano"""
    var is_my_turn = game_state.is_my_turn()
    
    for card_display in player_hand.get_children():
        var card_instance = card_display.get_instance()
        
        # Estado lógico: ¿puede jugarse?
        var can_afford = player_cosmos >= card_instance.base_data.cost
        var is_playable = is_my_turn and can_afford
        
        # Actualizar visual
        card_display.set_disabled(not is_my_turn)  # No es mi turno
        card_display.highlight(is_playable)        # Resaltar si jugable
        card_display.set_exhausted(card_instance.is_exhausted)

func _on_turn_changed():
    """Callback cuando cambia el turno"""
    update_hand_state()
    
    # Reset exhausted de todas las cartas
    for card_display in get_all_cards_in_play():
        card_display.set_exhausted(false)

func _on_server_card_update(card_data: Dictionary):
    """Callback cuando servidor envía update de carta"""
    var instance_id = card_data.get("instance_id", "")
    var card_display = _find_card_by_instance_id(instance_id)
    
    if card_display:
        # Crear CardInstance desde datos servidor
        var card_instance = CardInstance.from_server_data(card_data)
        
        # Actualizar visual (dirty flag interno)
        card_display.update_from_instance(card_instance)
```

**Flujo correcto:**
1. GameBoard recibe update del servidor
2. GameBoard actualiza GameState
3. GameBoard llama `update_hand_state()` o `update_from_instance()`
4. CardDisplay actualiza SOLO su visual

---

## 🗂️ Integración con CardInstance

CardInstance representa el **estado de una carta en partida**.

### Cómo CardDisplay usa CardInstance:

```gdscript
# Configurar carta inicial
var card_instance = CardInstance.new()
card_instance.base_data = CardData.from_json(server_data)
card_instance.instance_id = "abc-123"
card_instance.current_health = 1000
card_instance.is_exhausted = false

var card_display = CARD_DISPLAY_TEMPLATE.instantiate()
card_display.setup_from_instance(card_instance)

# Actualizar stats modificados
card_instance.current_health -= 300  # Daño recibido
card_instance.is_exhausted = true

card_display.update_from_instance(card_instance)  # Aplica cambios visuales
```

**Separación clara:**
- **CardData** = Template estático (ataque base, defensa base)
- **CardInstance** = Estado en partida (ataque actual, vida actual, buffs)
- **CardDisplay** = Visual del CardInstance

---

## 🌐 Integración con Servidor

El servidor envía actualizaciones de cartas en formato JSON.

### Flujo completo:

```gdscript
# 1. Servidor envía update via WebSocket
{
  "event": "card_updated",
  "data": {
    "instance_id": "abc-123",
    "current_health": 700,
    "current_attack": 850,
    "is_exhausted": true,
    "buffs": [{"type": "attack", "value": 100}]
  }
}

# 2. MatchManager parsea y emite señal
func _on_server_card_update(data: Dictionary):
    match_card_updated.emit(data)

# 3. GameBoard recibe señal
func _on_card_updated(data: Dictionary):
    var instance_id = data.get("instance_id")
    var card_display = _find_card_by_instance_id(instance_id)
    
    if card_display:
        var card_instance = card_display.get_instance()
        
        # Actualizar CardInstance con datos servidor
        card_instance.current_health = data.get("current_health")
        card_instance.current_attack = data.get("current_attack")
        card_instance.is_exhausted = data.get("is_exhausted", false)
        
        # Actualizar visual (dirty flag evita redundancia)
        card_display.update_from_instance(card_instance)
```

**Sin tocar nada más** - la arquitectura funciona end-to-end.

---

## 🎨 Estados Visuales y sus Usos

### Estados disponibles:

| Estado | Cuándo usarlo | Quién lo controla |
|--------|--------------|-------------------|
| `is_disabled` | No se puede usar (falta energía, no es turno) | GameBoard |
| `is_exhausted` | Ya actuó este turno | GameBoard (desde server) |
| `is_highlighted` | Es jugable en este momento | GameBoard |
| `interaction_enabled` | Permitir/bloquear eventos | CardSlot (durante drop) |

### Ejemplo de uso combinado:

```gdscript
# Carta jugable (mi turno, suficiente energía)
card_display.set_disabled(false)
card_display.highlight(true)

# Carta no jugable (no es mi turno)
card_display.set_disabled(true)
card_display.highlight(false)

# Carta que ya actuó
card_display.set_exhausted(true)

# Carta bloqueada temporalmente (durante animación)
card_display.disable_interaction()
await animation.finished
card_display.enable_interaction()
```

---

## 🔄 Métodos Clave del API

### Setup y Configuración:
```gdscript
setup(card_data: CardData)                    # Carta desde template
setup_from_instance(instance: CardInstance)   # Carta en partida
bind_instance(instance: CardInstance)         # Vincular instancia
```

### Estados Visuales:
```gdscript
set_disabled(disabled: bool)      # No se puede usar
set_exhausted(exhausted: bool)    # Ya actuó
highlight(enable: bool)           # Resaltar como jugable
update_visual_state()             # Aplicar todos los estados
```

### Queries de Estado:
```gdscript
can_be_dragged() -> bool          # ¿Puede arrastrarse?
is_playable() -> bool             # ¿Es jugable?
get_highlighted() -> bool         # ¿Está resaltada?
get_instance() -> CardInstance    # Obtener instancia
get_instance_id() -> String       # Obtener ID
```

### Animaciones:
```gdscript
play_spawn_animation()            # Entrada al campo
play_select_animation()           # Rebote al seleccionar
play_hover_animation()            # Hover (si HandLayout no controla)
stop_hover_animation()            # Detener hover
```

### Limpieza:
```gdscript
reset_visuals()                   # Reset visual completo
clear()                           # Limpiar datos (pooling)
safe_cleanup()                    # Limpiar antes de queue_free()
```

---

## ⚠️ Anti-Patrones (NO hacer)

### ❌ CardDisplay NO debe:

```gdscript
# MAL: CardDisplay validando lógica
func _get_drag_data(pos):
    if GameBoard.player_cosmos < card_data.cost:  # ❌ NO
        return null

# BIEN: GameBoard controla estado
func update_hand_state():
    card_display.set_disabled(player_cosmos < card.cost)  # ✅
```

```gdscript
# MAL: CardDisplay cambiando su posición
func on_card_played():
    position = Vector2(500, 300)  # ❌ NO

# BIEN: CardSlot o HandLayout controlan posición
func place_card(card_display):
    card_display.position = slot_position  # ✅
```

```gdscript
# MAL: CardDisplay comunicándose con servidor
func on_card_clicked():
    MatchManager.play_card(instance_id)  # ❌ NO

# BIEN: GameBoard maneja servidor
func _on_card_slot_card_placed(slot, card_display):
    MatchManager.play_card(instance_id)  # ✅
```

---

## 🏆 Checklist de Integración Perfecta

Al integrar CardDisplay en tu proyecto, verifica:

- [ ] HandLayout controla posición/escala, no CardDisplay
- [ ] GameBoard actualiza estados (disabled, highlighted)
- [ ] Servidor envía updates → GameBoard → CardDisplay.update_from_instance()
- [ ] CardDisplay NO valida lógica de juego
- [ ] CardDisplay NO se comunica con servidor
- [ ] CardDisplay NO cambia su propia posición
- [ ] Estados separados: disabled ≠ exhausted ≠ interaction_enabled
- [ ] Tweens se limpian correctamente (sin fugas)
- [ ] safe_cleanup() llamado antes de queue_free()
- [ ] clear() usado si hay object pooling

---

## 📚 Ejemplo Completo

```gdscript
# GameBoard.gd - Ejemplo de uso completo

func _ready():
    # Conectar señales servidor
    MatchManager.match_updated.connect(_on_match_updated)
    MatchManager.card_updated.connect(_on_card_updated)

func _on_match_updated(match_data: Dictionary):
    # Actualizar GameState
    game_state = GameState.from_server_data(match_data, player_id)
    
    # Renderizar todas las zonas
    render_all_zones()
    
    # Actualizar estado de mano
    update_hand_state()

func render_all_zones():
    # Limpiar mano
    for child in player_hand.get_children():
        child.safe_cleanup()
        child.queue_free()
    
    # Renderizar cartas
    for card_instance in game_state.player_hand:
        var card_display = CARD_DISPLAY_TEMPLATE.instantiate()
        card_display.setup_from_instance(card_instance)
        
        # HandLayout gestiona layout
        await player_hand.add_card(card_display)
        
        # Conectar señales
        card_display.card_double_clicked.connect(_on_card_detail_requested)

func update_hand_state():
    var is_my_turn = game_state.is_my_turn()
    
    for card_display in player_hand.get_children():
        var card_instance = card_display.get_instance()
        
        # Validar jugabilidad
        var can_play = game_state.can_play_card(card_instance)
        
        # Actualizar estados
        card_display.set_disabled(not is_my_turn)
        card_display.highlight(can_play)
        card_display.set_exhausted(card_instance.is_exhausted)

func _on_card_updated(data: Dictionary):
    var instance_id = data.get("instance_id")
    var card_display = _find_card_by_instance_id(instance_id)
    
    if card_display:
        var updated_instance = CardInstance.from_server_data(data)
        card_display.update_from_instance(updated_instance)
```

---

**Conclusión:** CardDisplay es ahora un componente UI profesional, totalmente encapsulado, que se integra perfectamente con HandLayout, GameBoard, CardInstance y el servidor sin necesitar modificaciones adicionales.
