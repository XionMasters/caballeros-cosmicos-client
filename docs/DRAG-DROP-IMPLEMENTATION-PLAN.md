# 🎯 Plan de Implementación: Drag-Drop + Card Play

**Estado Actual:** CardSlot → TestBoard → MatchManager ❌
**Estado Ideal:** CardSlot → MatchPlayController → MatchManager ✅

---

## 📋 Arquitectura Correcta

```
Usuario ARRASTRA carta
    ↓
CardDisplay._get_drag_data()
    └─ Retorna: {card_type, card_display, card_instance}
    ↓
CardSlot._can_drop_data()
    └─ Valida: ¿tipo correcto? ¿slot vacío?
    ↓
CardSlot._drop_data()
    └─ Emite: card_dropped signal
    ↓
MatchPlayController._ on_card_dropped()  [← FALTA ESTO]
    └─ Valida intención completa
    └─ Emite: card_play_requested signal
    ↓
MatchEventBridge._on_card_play_requested()
    └─ Forwardea a MatchManager
    ↓
MatchManager.play_card()
    └─ HTTP/WebSocket al servidor
    ↓
Servidor responde
    ↓
MatchManager.match_state_updated.emit()
    ↓
TestBoard._on_match_state_updated()
    └─ Re-renderiza
    └─ Llama a MatchPlayController.setup_card_interactions()
```

---

## 📦 Cambios Necesarios

### 1. CardDisplay: Implementar get_drag_data()
**Archivo:** `scripts/cards/CardDisplay.gd`

```gdscript
func get_drag_data(at_position: Vector2) -> Variant:
	"""Godot drag-drop system: preparar data para soltar en drop zones"""
	if not can_be_dragged():
		return null
	
	return {
		"card_type": card_data.type,           # "knight", "technique", etc.
		"card_display": self,
		"card_instance": card_instance,
		"source_zone": "hand"
	}
```

**Responsabilidad:** Proveer datos para el sistema drag-drop de Godot

---

### 2. CardSlot: Ya tiene _can_drop_data() y _drop_data()
**Archivo:** `scripts/game/CardSlot.gd`

✅ Ya implementado correctamente:
- `_can_drop_data()` - Valida tipo de carta
- `_drop_data()` - Emite `card_dropped` signal

**Señal que emite:**
```gdscript
signal card_dropped(payload: Dictionary)
# payload = {
#   "card_display": Control,
#   "card_instance": CardInstance,
#   "target_slot": CardSlot,
#   "slot_type": CardSlot.SlotType,
#   "slot_index": int
# }
```

---

### 3. MatchPlayController: Agregar handler para card_dropped
**Archivo:** `scripts/controllers/MatchPlayController.gd`

**Qué Agregar:**
1. Conectar a las señales `card_dropped` de los slots
2. Agregar handler `_on_card_dropped_in_slot()`
3. Validar intención completa
4. Emitir `card_play_requested`

**Pseudocódigo:**
```gdscript
# En setup_card_interactions():
_connect_slot_signals()

# Nueva función:
func _connect_slot_signals() -> void:
	"""Conectar card_dropped signals de todos los slots"""
	var knight_slots = board_renderer.player_knight_slots
	var tech_slots = board_renderer.player_tech_slots
	# ... etc
	
	for slot in all_slots:
		if not slot.card_dropped.is_connected(_on_card_dropped_in_slot):
			slot.card_dropped.connect(_on_card_dropped_in_slot)

# Nuevo handler:
func _on_card_dropped_in_slot(payload: Dictionary) -> void:
	"""CardSlot recibió una carta → validar y enviar al servidor"""
	var card_instance = payload.get("card_instance")
	var target_slot = payload.get("target_slot")
	
	if not card_instance or not target_slot:
		return
	
	# Obtener zona basada en el slot_type
	var target_zone = _slot_type_to_zone(target_slot.slot_type)
	var target_slot_index = target_slot.slot_index
	
	# Usar validación existente
	_attempt_play_card_in_slot(card_instance, target_zone, target_slot_index)
```

---

### 4. TestBoard: Simplificar (NO hacer trabajo aquí)
**Archivo:** `scripts/game/TestBoard.gd`

✅ Ya correcto. Solo:
- Inicializa `MatchPlayController`
- Inicializa `MatchEventBridge`
- Escucha `MatchManager.match_state_updated`
- Re-renderiza cuando llega actualización

❌ NO hace:
- Conectar slots directamente
- Validar cartas
- Enviar al servidor

---

## 🔧 Orden de Implementación

1. **CardDisplay.get_drag_data()** → 10 líneas
2. **MatchPlayController._connect_slot_signals()** → 20 líneas
3. **MatchPlayController._on_card_dropped_in_slot()** → 15 líneas
4. **MatchPlayController._ slot_type_to_zone()** → 10 líneas
5. **Verificación:** Press T en TestBoard para simular drag

---

## ✅ Validación

Después de implementar, verificar:

1. **Log Output** debe mostrar:
   ```
   [CardDisplay] get_drag_data() called
   [CardSlot] _can_drop_data() returns true
   [CardSlot] _drop_data() emitted card_dropped
   [MatchPlayController] _on_card_dropped_in_slot() received
   [MatchPlayController] ✅ Enviando al servidor: ...
   [MatchEventBridge] 📤 Reenviando al servidor...
   [MatchManager] 📡 HTTP: play_card()
   ```

2. **TestBoard Diagnostics** (Press D):
   ```
   ✅ Slot signals connected
   ✅ Card drag/drop ready
   ```

---

## 🎯 Beneficio Final

- **Responsabilidades claras:**
  - CardSlot: Valida tipo de carta
  - MatchPlayController: Valida intención
  - MatchManager: Envía al servidor
  - Servidor: Ejecuta y responde

- **Sin lógica duplicada**
- **Sin HTTPRequest en TestBoard**
- **Sin validación de reglas en cliente**

