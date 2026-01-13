# 🔧 Diagnóstico: Por qué NO funciona el Drag-Drop

## El Problema
```
Logs observados:
✅ [CardDisplay] Drag started: Seiya de Pegaso
✅ [CardDisplay] Drag ended: Seiya de Pegaso

Logs que DEBERÍAN aparecer pero NO aparecen:
❌ [CardDisplay] 🎴 get_drag_data(): preparado...
❌ [CardSlot:PlayerKnight1] 🔍 _can_drop_data: LLAMADO...
❌ [CardSlot:PlayerKnight1] 🎯 _drop_data: LLAMADO
```

## La Causa Raíz

En Godot 4.x, existen **DOS sistemas diferentes de drag**:

### Sistema 1: Godot's Built-in Drag-Drop (Automático)
```gdscript
# Se activa AUTOMÁTICAMENTE cuando:
1. El usuario presiona mouse sobre un Control
2. Godot espera ~0.5 segundos
3. Si el mouse se movió, Godot llama get_drag_data()
4. Godot detecta targets con _can_drop_data()
5. Godot llamaa _drop_data() en el target

# Implementación mínima:
func get_drag_data(at_position: Vector2) -> Variant:
    return {"data": "aqui"}
```

### Sistema 2: Manual Drag (Lo que TÚ implementaste)
```gdscript
# Se activa cuando:
1. El usuario presiona mouse
2. TÚ cambias el estado a HOLDING
3. TÚ emittes drag_started.emit()
4. TÚ mueves la tarjeta en _process()
5. TÚ emittes drag_ended.emit()

# Implementación:
func _handle_mouse_pressed():
    change_state(DraggableState.HOLDING)
    start_dragging()

func start_dragging():
    drag_started.emit(card_data)  # <- Aquí está lo que ves en logs
```

## El Conflicto

Godot tiene un **DELAY de ~0.5 segundos** antes de activar `get_drag_data()`. 

En tu implementación:
```gdscript
func _handle_mouse_pressed() -> void:
    if current_state == DraggableState.HOVERING or current_state == DraggableState.IDLE:
        change_state(DraggableState.HOLDING)  # <- TÚ cambias estado INMEDIATAMENTE
        start_dragging()                      # <- TÚ emittes INMEDIATAMENTE
```

**PROBLEMA:** TÚ activas tu sistema manual ANTES de que Godot llame a `get_drag_data()`.

Godot está esperando, pero tu sistema ya se tomó el control del evento.

---

## La Solución

**Opción A: Confiar en Godot (Recomendado)**
```gdscript
# Eliminar TODO el sistema manual de drag
# Eliminar: drag_started, drag_ended, cambio de estados, etc.

func get_drag_data(_at_position: Vector2) -> Variant:
    if not can_be_dragged():
        return null
    
    # Godot automaticamente detectará targets y llamará _can_drop_data()
    return {
        "card_type": card_data.type,
        "card_instance": card_instance,
    }
```

**Opción B: Sistema Mixto (Híbrido)**
```gdscript
# Mantener visual feedback (HOLDING state)
# Pero permitir que Godot maneje el drop

func get_drag_data(_at_position: Vector2) -> Variant:
    # AQUI es donde se activa el drag-drop REAL
    print("[CardDisplay] 🎴 get_drag_data() - iniciando drag-drop REAL")
    return {
        "card_type": card_data.type,
        "card_instance": card_instance,
    }

# Godot maneja el drop automáticamente
```

**Opción C: Forzar Godot a activar drag-drop**
```gdscript
# Agregar esto al _ready():
func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP

# En _handle_mouse_pressed():
func _handle_mouse_pressed() -> void:
    # NO cambiar estado
    # NO emitir drag_started
    # DEJAR que Godot llame a get_drag_data()
```

---

## Debug Inmediato: ¿Cuál es el problema?

### Test 1: ¿Se llama get_drag_data()?

Modifica CardDisplay así:
```gdscript
func get_drag_data(_at_position: Vector2) -> Variant:
    print("=== GET_DRAG_DATA LLAMADO ===")  # <- Megaobvio
    push_error("GET_DRAG_DATA LLAMADO")     # <- Rojo en consola
    
    if not can_be_dragged():
        return null
    
    # ... resto del código
```

**Prueba:** Arrastra una carta. ¿Ves "GET_DRAG_DATA LLAMADO"?
- **SÍ** → El problema es en CardSlot/targets
- **NO** → El problema es en activación de drag-drop

---

## Mi Hipótesis

Basándome en los logs que viste:
```
[CardDisplay] Drag started: Seiya  ← Este es drag_started.emit()
[CardDisplay] Drag ended: Seiya    ← Este es drag_ended.emit()
```

**Nunca** viste:
```
[CardDisplay] 🎴 get_drag_data():...  ← Nunca se llama
```

**Conclusión:** `get_drag_data()` **NUNCA se llama** porque:
1. Tu sistema manual toma control ANTES de que Godot lo haga
2. O el mouse_filter no es correcto
3. O hay algo en la jerarquía (HandLayout) que bloquea Godot drag-drop

---

## Pasos para Arreglarlo

### Paso 1: Confirmar el diagnóstico
En CardDisplay, agrega esto al inicio de `_ready()`:
```gdscript
func _ready() -> void:
    print("[CardDisplay] %s - mouse_filter=%s" % [card_data.name if card_data else "?", mouse_filter])
    mouse_filter = Control.MOUSE_FILTER_STOP
    print("[CardDisplay] %s - mouse_filter AHORA=%s" % [card_data.name if card_data else "?", mouse_filter])
```

También agrega a `get_drag_data()`:
```gdscript
func get_drag_data(_at_position: Vector2) -> Variant:
    push_error("!!!!! GET_DRAG_DATA LLAMADO !!!!!")  # En ROJO para que no se pierda
    # ... resto
```

### Paso 2: Probar
```
1. Run TestBoard.tscn
2. Ver en Output:
   - ¿Aparece "mouse_filter=STOP"?
   - ¿Aparece "!!!!! GET_DRAG_DATA LLAMADO !!!!!" en ROJO?
```

### Paso 3: Basándome en eso
Si aparece → El drag-drop funciona, problema está en CardSlot
Si NO aparece → Necesitamos cambiar estrategia

---

## Cambios Recomendados AHORA

En `scripts/cards/CardDisplay.gd`, modifica:

```gdscript
func _ready() -> void:
    # ... código existente ...
    
    # MEGA-IMPORTANTE para Godot drag-drop
    mouse_filter = Control.MOUSE_FILTER_STOP
    
    # Debug
    if card_data:
        print("[CardDisplay] %s ready - mouse_filter=%s, can_be_dragged=%s" % [
            card_data.name,
            mouse_filter,
            can_be_dragged()
        ])
```

Y en `get_drag_data()`:
```gdscript
func get_drag_data(_at_position: Vector2) -> Variant:
    if not can_be_dragged():
        return null
    
    push_error("!!!!! GET_DRAG_DATA LLAMADO - card=%s !!!!!" % card_data.name)
    
    var drag_data = {
        "card_type": card_data.type,
        "card_display": self,
        "card_instance": card_instance,
        "source_zone": "hand"
    }
    
    print("[CardDisplay] 🎴 get_drag_data(): preparado %s con type=%s" % [
        card_data.name, card_data.type
    ])
    return drag_data
```

---

## Próximo Paso

Haz estos cambios y corre TestBoard nuevamente. Luego:
1. Tira logs completos
2. Busca por "GET_DRAG_DATA"
3. Si aparece → Le damos a CardSlot
4. Si NO aparece → Buscamos causa raíz en jerarquía de nodos
