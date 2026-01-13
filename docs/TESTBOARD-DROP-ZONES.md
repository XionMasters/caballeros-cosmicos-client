# TestBoard - Multiple Drop Zones Integration

## Overview
TestBoard ha sido actualizado para incluir múltiples drop zones donde se pueden arrastrar y soltar cartas. Esto permite probar interacciones complejas de drag-and-drop sin depender del GameBoard.

## Architecture

### Components

#### 1. Player Hand
- Contenedor de cartas conocidas (HBoxContainer)
- Usa HandLayout para organización automática
- Contiene instancias de `Card` (clase nueva)

#### 2. Drop Zones
- 3 zonas de drop separadas: "Zona 1", "Zona 2", "Zona 3"
- Cada zona tiene:
  - **PanelContainer**: Visual container con label
  - **DropZone**: Sistema de sensores para detección
  - **HBoxContainer**: Contenedor para cartas soltadas

#### 3. Card Management
- **cards_in_hand**: Array de cartas en mano
- **dropped_cards**: Array de cartas en zonas
- Dinámico: cartas se mueven entre contenedores

## Implementation Details

### Setup Drop Zones

```gdscript
func _setup_drop_zones() -> void:
    # Define 3 zonas con tamaño 120x180
    var zone_configs = {
        "Zona 1": Vector2(120, 180),
        "Zona 2": Vector2(120, 180),
        "Zona 3": Vector2(120, 180),
    }
    
    # Para cada zona:
    # 1. Crear PanelContainer visual
    # 2. Crear DropZone system
    # 3. Crear contenedor para cartas
    # 4. Conectar señales de drop
```

### Card Creation

```gdscript
func _add_card_to_hand(card_data: Dictionary) -> void:
    # Instanciar desde plantilla Card.tscn
    var card = CARD_TEMPLATE.instantiate() as Card
    
    # Configurar desde diccionario
    var card_info = CardData.new()
    # ... copiar datos ...
    
    card.setup(card_info)
    
    # Conectar señales de click
    card.card_clicked.connect(_on_card_clicked.bind(card))
    card.card_double_clicked.connect(_on_card_double_clicked.bind(card))
    
    # Agregar a mano
    player_hand.add_child(card)
    cards_in_hand.append(card)
```

### Card Drop Handling

```gdscript
func _on_card_dropped(card: Card, zone_name: String) -> void:
    # Cuando se suelta una carta en una zona:
    
    # 1. Remover de mano si estaba
    if cards_in_hand.has(card):
        cards_in_hand.erase(card)
    
    # 2. Re-parent al contenedor de zona
    var zone_container = drop_zone_containers[zone_name]
    card.get_parent().remove_child(card)
    zone_container.add_child(card)
    
    # 3. Registrar en dropped_cards
    dropped_cards.append(card)
```

## Testing Workflow

### 1. Basic Interaction
```
Iniciar TestBoard
→ Crear 5 cartas de prueba
→ Cartas aparecen en Player Hand
→ Hovering en una carta (animación smooth)
→ Dragging sigue el ratón
```

### 2. Drop Zone Testing
```
Dragging carta desde hand
→ Mover sobre Zona 1
→ Soltar (release)
→ Carta se mueve a Zona 1
→ Status label muestra confirmación
```

### 3. Multi-Zone Testing
```
Arrastrar carta A a Zona 1
Arrastrar carta B a Zona 2
Arrastrar carta C a Zona 3
→ Cada zona contiene su carta
→ Cartas no se mezclan
```

### 4. State Machine Testing
```
Cuando carta está en estado HOLDING:
→ Intentar hover en otra carta
→ Validación global previene (hovering_card_count > 0)
→ Solo la carta actual responde a input
```

## Key Features

### ✅ Dynamic Drop Zone Creation
- 3 zonas creadas en _ready()
- Almacenadas en diccionarios para acceso rápido
- Labels para identificar cada zona

### ✅ Smart Card Movement
- Cartas se mueven automáticamente entre contenedores
- Parent actualizado en drop
- Arrays sincronizados (cards_in_hand, dropped_cards)

### ✅ Visual Feedback
- Status label muestra acción actual
- Drop zone labels identifican destino
- Console logging para debugging

### ✅ State Machine Integration
- DraggableObject maneja todo el drag
- Card.gd valida con global counters
- DropZone detecta zona válida

## Debugging

### Enable Visual Outlines
```gdscript
# En TestBoard._setup_drop_zones():
drop_zone.sensor_outline_visible = true
```

Muestra:
- Contornos amarillos de sensores
- Líneas rojas de particiones
- Muy útil para ver dónde cae el drop

### Console Output
```
[TEST] Drop zones creadas: ["Zona 1", "Zona 2", "Zona 3"]
[TEST] Card clicked: TestCard1
[TEST] Card dropped in Zona 1: TestCard1
[TEST] All cards cleared
```

## Próximos Pasos

1. ✅ Crear múltiples drop zones
2. ✅ Implementar drag-and-drop entre zonas
3. ⏳ Agregar criterios de validación (por tipo de carta, rarity, etc.)
4. ⏳ Crear animaciones de drop
5. ⏳ Integrar con GameBoard

## Files Modified

- `scripts/game/TestBoard.gd` - Rewrite completo
- `scripts/core/DraggableObject.gd` - Base class
- `scripts/cards/Card.gd` - Nueva clase
- `scripts/game/DropZone.gd` - Sistema de zonas

## Testing Checklist

- [ ] 5 cartas cargan en hand
- [ ] Solo una carta puede hover al mismo tiempo
- [ ] Solo una carta puede ser dragged al mismo tiempo
- [ ] Drag sigue el ratón suavemente
- [ ] Release en zona valida mueve la carta
- [ ] Status label actualiza en cada acción
- [ ] Double-click en carta funciona
- [ ] Clear button limpia todo
- [ ] Reload button trae nuevas cartas

---

**Estado**: TestBoard actualizado con drop zones dinámicas  
**Próximo**: Integración con GameBoard  
**Tiempo estimado**: 30 minutos
