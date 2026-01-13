# Card Framework Integration Plan - CCG Project

## Framework Overview

El card-framework usa patrones profesionales para drag-and-drop y gestión de cartas:

### 1. **State Machine en DraggableObject**
```
IDLE → HOVERING → HOLDING → MOVING → IDLE
```

**Estados**:
- **IDLE**: Estado por defecto, listo para interacción
- **HOVERING**: Ratón sobre la carta con efectos visuales (escala, rotación, posición)
- **HOLDING**: Activamente arrastrando, sigue el ratón
- **MOVING**: Movimiento programático, ignora input del usuario

**Validación de Transiciones**: Solo transiciones permitidas en `allowed_transitions`

### 2. **Contador Global de Estado**
```gdscript
static var hovering_card_count: int = 0
static var holding_card_count: int = 0
```

**Propósito**: Prevenir múltiples cartas en estado HOVERING/HOLDING simultáneamente

**Método de Validación**:
```gdscript
func _can_start_hovering() -> bool:
    return hovering_card_count == 0 and holding_card_count == 0
```

### 3. **Drag-and-Drop System**

**Componentes**:
- **Card**: Extiende DraggableObject con lógica de cartas específica
- **CardContainer**: Clase abstracta para colecciones (Hand, Pile, etc.)
- **DropZone**: Sistema de sensores para detección de drop con particiones
- **HandLayout**: Fan-shaped arrangement con curvas matemáticas

**Flujo**:
1. Usuario mueve ratón sobre carta → `_can_start_hovering()` valida
2. Si válido → IDLE → HOVERING (animación hover)
3. Click y hold → HOVERING → HOLDING (sigue ratón)
4. Release → HOLDING → IDLE, luego `CardContainer.release_holding_cards()`

### 4. **Tween Animations**
- Hover animation con `move_tween` (posición, escala, rotación paralelas)
- Move animation con interpolación smooth
- Z-index manejo automático durante drag

### 5. **CardContainer System**
```gdscript
# Métodos virtuales a sobrescribir
func _card_can_be_added(cards: Array) -> bool
func _update_target_positions() -> void
func on_card_move_done() -> void
func hold_card(card: Card) -> void
func release_holding_cards() -> void
```

### 6. **DropZone Partitioning**
- Sistema de particiones verticales/horizontales para precisión
- Detección inteligente de zona válida para drop
- Visual debugging con outlines de colores

## Diferencias con Proyecto CCG Actual

| Aspecto | Framework | CCG Actual |
|--------|-----------|-----------|
| **State Machine** | IDLE/HOVERING/HOLDING/MOVING explícito | CardState enum sin transiciones |
| **Global Tracking** | Static counters (hovering/holding_count) | card_drag_ongoing (solo drag) |
| **Validación** | `_can_start_hovering()` + allowed_transitions | Estado + global flag |
| **Tween Management** | Separados (hover_tween, move_tween) | Mezcla en _process |
| **Container** | CardContainer abstracto con métodos virtuales | HandLayout simple |
| **Drop Detection** | DropZone con particiones | Básico por zona |

## Plan de Integración (Fase 2)

### Paso 1: Refactorizar CardDisplay → Card (Herencia de DraggableObject)

```gdscript
# Actual:
extends PanelContainer
class_name CardDisplay

# Framework:
extends DraggableObject
class_name Card
```

**Cambios**:
- Heredar estado machine de DraggableObject
- Implementar `_can_start_hovering()` para validación global
- Usar tweens separados para hover vs move
- Agregar `_enter_state()` y `_exit_state()` overrides para lógica CCG

### Paso 2: Mejorar MatchManager → CardManager

Agregar métodos como:
```gdscript
static var hovering_card_count: int = 0
static var holding_card_count: int = 0
var card_containers: Dictionary[int, CardContainer] = {}

func add_card_container(id: int, container: CardContainer) -> void
func remove_card_container(id: int) -> void
func get_container(id: int) -> CardContainer
```

### Paso 3: HandLayout → Hand (Herencia de CardContainer)

```gdscript
extends CardContainer
class_name Hand

func _card_can_be_added(cards: Array) -> bool
func _update_target_positions() -> void  # Fan arrangement
func hold_card(card: Card) -> void
func release_holding_cards() -> void
```

### Paso 4: Crear DropZone para GameBoard

```gdscript
class_name DropZone
extends Control

var sensor_size: Vector2
var sensor_position: Vector2
var sensor_outline_visible: bool

func check_mouse_is_in_drop_zone() -> bool
func set_vertical_partitions(partitions: Array) -> void
```

## Beneficios de Adoptar Framework Patterns

1. ✅ **State Machine**: Elimina bugs de estados conflictivos
2. ✅ **Global Validation**: Previene múltiples drags simultáneos
3. ✅ **Tween Management**: Animaciones smooth sin conflictos
4. ✅ **Extensibilidad**: Nuevos containers heredando CardContainer
5. ✅ **Visual Debugging**: DropZone outlines para testing
6. ✅ **Escalabilidad**: Patrones probados para múltiples tipos de cartas

## Implementación Mínima (Próximos 2-3 horas)

1. Crear `DraggableObject.gd` (copiar lógica core del framework)
2. Refactorizar `CardDisplay.gd` → `Card.gd` (heredar DraggableObject)
3. Agregar static counters a `MatchManager.gd`
4. Mejorar `HandLayout.gd` con template methods
5. Crear `DropZone.gd` básico para field slots

---

**Estado**: Análisis completado  
**Próximos pasos**: Implementación de DraggableObject base  
**Tiempo estimado**: 3-4 horas para integración completa
