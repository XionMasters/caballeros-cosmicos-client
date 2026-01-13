# Plan de Reconstrucción: TestBoard desde Cero

**Objetivo**: Crear un TestBoard funcional paso a paso con pruebas en cada fase.

**Problema Actual**: Las cartas no son interactuables. Vamos a desmontar y reconstruir de forma modular.

---

## Estrategia General

```
Phase 1: Core Rendering
  └─ Cargar GameState del servidor
  └─ Renderizar mazos (solo contadores)
  └─ Renderizar manos vacías

Phase 2: Card Animation from Deck
  └─ Animar cartas del mazo a la mano (deal animation)
  └─ Verificar que las cartas aparecen en la mano
  └─ Prueba: ¿Se ven las cartas en la mano con animación?

Phase 3: Field Rendering
  └─ Renderizar zonas de campo (slots vacíos)
  └─ Renderizar cartas que están en el campo

Phase 4: Card Interactivity
  └─ Conectar eventos drag/drop a CardDisplay
  └─ Implementar validación de UX
  └─ Enviar al servidor

Phase 5: Server Integration
  └─ Recibir actualizaciones del servidor
  └─ Re-renderizar tablero
  └─ Mostrar feedback de acciones
```

---

## FASE 1: Core Rendering ✅

### Paso 1.1: Cargar GameState
**Archivo**: `TestBoard.gd`
**Responsable**: `MatchManager` (ya listo)
**Validación**:
```gdscript
# Verificar que game_state tiene datos
print("Player hand count: %d" % game_state.player_hand.size())
print("Opponent hand count: %d" % game_state.opponent_hand_count)
print("Player deck: %d cartas" % game_state.player_deck_count)
```

### Paso 1.2: Renderizar Mazos (Contadores)
**Archivos**: `TestBoard.gd`, `DeckDisplay.gd`
**Responsable**: `TestBoard._on_match_started()`

**Código**:
```gdscript
func _render_decks() -> void:
    """Mostrar solo contadores de mazo"""
    player_deck.set_count(game_state.player_deck_count)
    opponent_deck.set_count(game_state.opponent_deck_count)
    print("✅ Mazos renderizados: P1=%d, P2=%d" % [
        game_state.player_deck_count,
        game_state.opponent_deck_count
    ])
```

**Prueba**: 
- ¿Se ven los números en los mazos (35, 40, etc)?
- ¿Los números son correctos?

### Paso 1.3: Renderizar Manos Vacías
**Archivos**: `TestBoard.gd`, `HandLayout.gd`
**Responsable**: `TestBoard.render_all_zones()`

**Código**:
```gdscript
func _render_hands() -> void:
    """Limpiar y preparar manos"""
    player_hand.clear_cards()
    opponent_hand.clear_cards()
    print("✅ Manos limpias y listas")
```

**Prueba**:
- ¿Las áreas de mano están visibles pero vacías?

---

## FASE 2: Card Animation from Deck ⭐ KEY PHASE

### Paso 2.1: Crear CardAnimationManager
**Archivos**: Ya existe `CardAnimationManager.gd`
**Método clave**: `animate_flip_from_deck()`

```gdscript
func animate_flip_from_deck(
    card_display: Control,
    deck_position: Vector2,
    target_position: Vector2 = Vector2.ZERO,
    duration: float = -1.0
) -> void:
    # 1. Posiciona carta en mazo
    # 2. Escala pequeño (0.1, 0.1)
    # 3. Anima hacia target_position
    # 4. Crece a escala normal (1.0, 1.0)
```

### Paso 2.2: Animar Cartas desde Mazo a Mano
**Archivo**: `TestBoard.gd`
**Responsable**: Método nuevo `_animate_initial_hand_draw()`

**Pseudocódigo**:
```
Para cada carta en game_state.player_hand:
    1. Crear CardDisplay
    2. Obtener posición del mazo (player_deck.global_position)
    3. Obtener posición final en mano
    4. Animar con CardAnimationManager.animate_flip_from_deck()
    5. Esperar animación
    6. Agregar a player_hand (HandLayout)
    7. Conectar eventos de interacción
```

**Código esqueleto**:
```gdscript
func _animate_initial_hand_draw() -> void:
    """Animar 7 cartas del mazo a la mano"""
    if not game_state:
        return
    
    var anim_mgr = CardAnimationManager.new()
    add_child(anim_mgr)
    
    var deck_pos = player_deck.global_position
    var delay = 0.0
    
    for i in range(game_state.player_hand.size()):
        var card_instance = game_state.player_hand[i]
        var card_display = CARD_DISPLAY_TEMPLATE.instantiate()
        card_display.setup(card_instance.base_data)
        
        # Calcular posición final en mano
        var hand_pos = player_hand.global_position
        hand_pos.y += 50  # Ajustar según necesidad
        
        # Agregar al tablero pero invisible
        add_child(card_display)
        
        # Animar después de delay
        await get_tree().create_timer(delay).timeout
        anim_mgr.animate_flip_from_deck(card_display, deck_pos, hand_pos, 0.5)
        delay += 0.1  # Delay entre cartas
    
    print("✅ Animación de robo completada")
```

**Validación**:
- ¿Se ven las cartas animándose desde el mazo?
- ¿Llegan a la mano con la escala correcta?
- ¿Se ve fluido o entrecortado?

### Paso 2.3: Agregar Cartas a HandLayout Después de Animación
**Archivo**: `TestBoard.gd`
**Cambio en el código anterior**:

```gdscript
# Después de que termina la animación (await tween):
await anim_mgr.get_tween_completed(card_display)  # O similar
player_hand.add_card(card_display)
print("✅ Carta %s agregada a mano" % card_instance.base_data.name)
```

**Validación**:
- ¿Las cartas están en la mano después de animarse?
- ¿Los números en la mano son correctos (7)?
- ¿Se solapan correctamente según HandLayout logic?

---

## FASE 3: Field Rendering

### Paso 3.1: Renderizar Slots Vacíos
**Archivos**: `CardSlot.gd`, `TestBoard.gd`

```gdscript
func _render_field_slots() -> void:
    """Mostrar slots vacíos para jugador"""
    for i in range(5):
        player_knight_slots[i].clear()
        player_knight_slots[i].show_empty()
    
    for i in range(5):
        player_tech_slots[i].clear()
        player_tech_slots[i].show_empty()
```

**Validación**: ¿Se ven los 5+5 slots vacíos?

### Paso 3.2: Renderizar Cartas en Campo
**Archivos**: `TestBoard.gd`, `BoardRenderer.gd`

```gdscript
func _render_field_cards() -> void:
    """Mostrar cartas que están en el campo"""
    # Jugador 1 - Caballeros
    for i in range(game_state.player_field_knights.size()):
        var card = game_state.player_field_knights[i]
        var display = CARD_DISPLAY_TEMPLATE.instantiate()
        display.setup(card.base_data)
        player_knight_slots[i].set_card(display)
    
    # Jugador 1 - Técnicas
    for i in range(game_state.player_field_techniques.size()):
        var card = game_state.player_field_techniques[i]
        var display = CARD_DISPLAY_TEMPLATE.instantiate()
        display.setup(card.base_data)
        player_tech_slots[i].set_card(display)
```

**Validación**: ¿Se muestran correctamente las cartas en campo?

---

## FASE 4: Card Interactivity

### Paso 4.1: Conectar Eventos a CardDisplay
**Archivo**: `MatchPlayController.gd`

```gdscript
func setup_card_interactions() -> void:
    """Conectar drag/drop a TODAS las cartas visibles"""
    # En player_hand
    for card_display in player_hand.get_cards():
        if not card_display.drag_started.is_connected(_on_card_drag_started):
            card_display.drag_started.connect(_on_card_drag_started)
        if not card_display.drag_ended.is_connected(_on_card_drag_ended):
            card_display.drag_ended.connect(_on_card_drag_ended)
    
    print("✅ Eventos de carta conectados")
```

**Validación**: ¿Se imprime "Eventos de carta conectados"?

### Paso 4.2: Validar Drag Básico
**Archivo**: `MatchPlayController.gd`

```gdscript
func _on_card_drag_started(card_display: Control) -> void:
    """Usuario empezó a arrastrar"""
    print("🟢 Drag started: %s" % card_display.get_meta("card_instance", "???"))
    current_dragging_card = card_display

func _on_card_drag_ended(card_display: Control) -> void:
    """Usuario soltó el arrastre"""
    print("🔴 Drag ended: %s" % card_display.get_meta("card_instance", "???"))
    current_dragging_card = null
```

**Validación**:
- Arrastra una carta
- ¿Se imprime "Drag started"?
- Suelta
- ¿Se imprime "Drag ended"?

### Paso 4.3: Detectar Zona de Suelta
**Archivo**: `MatchPlayController.gd`

```gdscript
func _on_card_drag_ended(card_display: Control) -> void:
    """Detectar a dónde se soltó"""
    var drop_pos = card_display.get_global_mouse_position()
    var target_slot = _detect_drop_slot(drop_pos)
    
    if target_slot:
        print("✅ Soltado en slot: %s" % target_slot)
    else:
        print("❌ No soltado en zona válida")

func _detect_drop_slot(pos: Vector2) -> Control:
    """Buscar si se soltó sobre un slot"""
    for slot in player_knight_slots + player_tech_slots:
        if slot.get_global_rect().has_point(pos):
            return slot
    return null
```

**Validación**:
- Arrastra carta a un slot
- ¿Se imprime "Soltado en slot"?
- Arrastra fuera
- ¿Se imprime "No soltado"?

### Paso 4.4: Enviar al Servidor
**Archivo**: `MatchEventBridge.gd`

```gdscript
func _on_card_play_requested(
    card_instance: CardInstance,
    target_zone: String,
    target_slot: int
) -> void:
    """Solicitud de juego → Servidor"""
    print("📤 Enviando al servidor: %s → %s[%d]" % [
        card_instance.base_data.name,
        target_zone,
        target_slot
    ])
    
    MatchManager.play_card(
        card_instance.instance_id,
        target_zone,
        target_slot
    )
```

**Validación**: 
- Arrastra carta a slot
- ¿Se imprime el mensaje de envío?

---

## FASE 5: Server Integration

### Paso 5.1: Recibir Respuesta del Servidor
**Archivo**: `TestBoard.gd`

```gdscript
func _on_match_state_updated(_data: Dictionary) -> void:
    """Servidor actualizó el estado"""
    print("🔄 Estado actualizado desde servidor")
    
    # Limpiar todo
    player_hand.clear_cards()
    for slot in player_knight_slots + player_tech_slots:
        slot.clear()
    
    # Re-renderizar
    render_all_zones()
```

**Validación**:
- Juega carta
- ¿Se imprime "Estado actualizado"?
- ¿Se renderiza de nuevo?

### Paso 5.2: Mostrar Feedback Visual
**Archivo**: `TestBoard.gd`

```gdscript
func _show_action_feedback(message: String) -> void:
    """Mostrar feedback flotante"""
    var label = Label.new()
    label.text = message
    label.global_position = get_viewport().get_mouse_position()
    add_child(label)
    
    await get_tree().create_timer(2.0).timeout
    label.queue_free()
```

**Validación**: ¿Se ve mensaje temporal?

---

## Checklist de Validación

### Cada fase debe cumplir:
- [ ] Se compila sin errores
- [ ] Se ejecuta sin crashes
- [ ] Se ve algo en pantalla
- [ ] Logs muestran progreso correcto
- [ ] Transición limpia a siguiente fase

### Fase 1
- [ ] Mazos muestran números
- [ ] Manos están vacías y listas

### Fase 2
- [ ] Cartas se animan desde mazo
- [ ] Cartas llegan a mano correctamente
- [ ] 7 cartas en player_hand
- [ ] Cartas están visibles

### Fase 3
- [ ] Slots vacíos visibles
- [ ] Cartas en campo renderizadas

### Fase 4
- [ ] Logs de drag/drop
- [ ] Detecta slots correctamente
- [ ] Mensaje de envío al servidor

### Fase 5
- [ ] Servidor responde
- [ ] Tablero se re-renderiza
- [ ] Acciones se aplican

---

## Archivos Clave a Usar

| Archivo | Propósito | Estado |
|---------|-----------|--------|
| `CardAnimationManager.gd` | Animaciones | ✅ Existe |
| `DeckDisplay.gd` | Mostrar mazo | ✅ Existe |
| `HandLayout.gd` | Layout de mano | ✅ Existe |
| `CardSlot.gd` | Slot de campo | ✅ Existe |
| `TestBoard.gd` | Orquestador | 🔧 Refactorizar |
| `MatchPlayController.gd` | Input de cartas | ✅ Existe |
| `MatchEventBridge.gd` | Server comms | ✅ Existe |

---

## Plan de Refactorización TestBoard.gd

Estructura recomendada:

```gdscript
# TestBoard.gd

# 1. MÉTODOS DE CICLO DE VIDA
func _ready() -> void
func _on_match_started(state: GameState) -> void
func _on_match_state_updated(_data: Dictionary) -> void

# 2. MÉTODOS DE RENDERIZADO (FASE A FASE)
func _render_phase_1_decks() -> void           # Fase 1
func _render_phase_2_hands() -> void            # Fase 2 (antes de animar)
func _animate_initial_hand_draw() -> void      # Fase 2 (animación)
func _render_phase_3_field() -> void            # Fase 3

# 3. MÉTODOS DE INTERACTIVIDAD
func _setup_card_interactions() -> void         # Fase 4
func _setup_server_integration() -> void        # Fase 5

# 4. HELPERS
func _clear_all_zones() -> void
func render_all_zones() -> void  # Llamar en estado actualizado
```

---

## Cómo Ejecutar el Plan

1. **Implementa Fase 1** → Prueba décks y manos vacías
2. **Implementa Fase 2** → Prueba animación de robo
3. **Implementa Fase 3** → Prueba slots y campo
4. **Implementa Fase 4** → Prueba drag/drop
5. **Implementa Fase 5** → Prueba comunicación servidor

Después de **cada fase**, ejecuta TestBoard y valida:
```bash
# En Godot
Presiona Play
Mira Output panel
Verifica logs
Comprueba visual
```

---

## Señales Clave

```gdscript
# MatchManager
signal match_started(state: GameState)
signal match_state_updated(data: Dictionary)
signal match_error(error: String)

# MatchPlayController
signal card_play_requested(card: CardInstance, zone: String, slot: int)
signal card_play_failed(reason: String)

# CardDisplay
signal drag_started(card: CardData)
signal drag_ended(card: CardData)
signal card_clicked(card: CardData)
```

---

## Debugging Tips

Si algo no funciona:

1. **Cartas no se ven**: Revisar `CardDisplay.setup()` y visibilidad
2. **Animación entrecortada**: Revisar `CardAnimationManager` tweens
3. **Drag no funciona**: Revisar `mouse_filter` en nodos padres
4. **No se conecta servidor**: Revisar logs de WebSocket
5. **Slots no detectan**: Revisar `get_global_rect()` en CardSlot

---

**Próximo paso**: Implementar Fase 1 paso a paso
