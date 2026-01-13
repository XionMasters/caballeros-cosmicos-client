# Arquitectura de Card Collections

## Resumen

Se creó una nueva arquitectura basada en herencia para manejar colecciones visuales de cartas de forma más limpia y extensible.

## Jerarquía de Clases

```
Control
└── CardCollection (clase base abstracta)
    ├── HandLayout (cartas en mano, horizontal con hover)
    ├── DeckDisplay (stack de dorsos con contador)
    └── [Futuro] DiscardPile, ExiledCards, etc.
```

## CardCollection (Clase Base)

**Ubicación**: `scripts/models/CardCollection.gd`

### Responsabilidades
- ✅ Administrar lista interna de nodos de carta (`_cards`)
- ✅ Proveer API común: `add_card()`, `remove_card()`, `clear_cards()`, `get_cards()`
- ✅ Emitir señales cuando cambia la colección
- ✅ Llamar a `_update_layout()` (template method) cuando hay cambios
- ❌ NO posiciona cartas (eso lo hacen las subclases)
- ❌ NO conoce lógica de juego (solo maneja nodos visuales)

### Señales
```gdscript
signal card_added(card_node)
signal card_removed(card_node)
signal layout_changed()
```

### Métodos Principales
```gdscript
func add_card(card_node: Node) -> void
func remove_card(card_node: Node) -> void
func clear_cards() -> void
func get_cards() -> Array
func _update_layout() -> void  # Template method (override en hijos)
```

---

## HandLayout (Hereda de CardCollection)

**Ubicación**: `scripts/game/HandLayout.gd`

### Características
- Layout horizontal con solapamiento automático si hay muchas cartas
- Hover: eleva carta y la agranda
- Drag & drop: soporta arrastrar cartas
- Centrado automático en el contenedor

### Parámetros Exportados
```gdscript
@export var card_width: float = 120.0
@export var max_total_width: float = 800.0
@export var min_spacing: float = 10.0
@export var card_scale: float = 0.85
@export var hover_scale: float = 1.1
@export var hover_offset_y: float = -50.0
```

### Uso en GameBoard
```gdscript
# Agregar carta a la mano
var card_display = CARD_DISPLAY_TEMPLATE.instantiate()
card_display.setup(card_data)
player_hand.add_card(card_display)  # HandLayout maneja el layout automáticamente

# Limpiar mano
player_hand.clear_cards()
```

### Métodos Clave
```gdscript
func arrange_cards() -> void  # Calcula posiciones
func hover_card(card: Control) -> void
func unhover_card(card: Control) -> void
func notify_drag_start(card: Control) -> void
func notify_drag_end(card: Control) -> void
```

### Override de CardCollection
```gdscript
func _update_layout() -> void:
    arrange_cards()  # Recalcula posiciones
    super._update_layout()  # Emite señal
```

---

## DeckDisplay (Hereda de CardCollection)

**Ubicación**: `scripts/models/DeckDisplay.gd`

### Características
- Muestra stack de cartas boca abajo (dorsos)
- Muestra contador visual del total de cartas
- Solo muestra N cartas visibles superpuestas (configurable)
- API específica para mazos (push/pop)

### Parámetros Exportados
```gdscript
@export var max_visible_cards: int = 3
@export var card_back_scene: PackedScene  # Escena de CardBack
@export var stack_offset: float = 6.0     # Offset vertical por carta
@export var show_counter: bool = true
```

### Uso en GameBoard
```gdscript
# PlayerDeck y OpponentDeck ya son instancias de DeckDisplay en GameBoard.tscn
@onready var player_deck = $MainContainer/LeftColumn/PlayerDeck/DeckPile
@onready var opponent_deck = $MainContainer/LeftColumn/OpponentDeck/DeckPile

# Actualizar contador
player_deck.set_count(40)

# Robar carta (decrementar)
player_deck.pop_card_back()

# Devolver carta (incrementar)
player_deck.push_card_back()

# Resetear mazo
player_deck.reset_deck(40)
```

### Métodos Específicos
```gdscript
func set_count(n: int) -> void
func reset_deck(n: int) -> void
func push_card_back() -> void  # Agrega una carta
func pop_card_back() -> void   # Quita una carta
```

### Advertencia
❌ No usar `add_card()` / `remove_card()` directamente (están deshabilitados)
✅ Usar `set_count()`, `push_card_back()`, `pop_card_back()`

---

## Migración desde el Sistema Anterior

### Antes (manual)
```gdscript
# Limpiar mano
for child in player_hand.get_children():
    child.queue_free()

# Agregar carta
var card = CARD_DISPLAY_TEMPLATE.instantiate()
player_hand.add_child(card)
# Luego llamar a algún método de layout manualmente
```

### Ahora (con CardCollection)
```gdscript
# Limpiar mano
player_hand.clear_cards()

# Agregar carta
var card = CARD_DISPLAY_TEMPLATE.instantiate()
player_hand.add_card(card)  # Auto-layout
```

---

## Ventajas de la Nueva Arquitectura

1. ✅ **Consistencia**: Todas las colecciones usan la misma API base
2. ✅ **Extensibilidad**: Fácil crear nuevas colecciones (DiscardPile, BanishZone, etc.)
3. ✅ **Separación de responsabilidades**: UI visual separada de lógica de juego
4. ✅ **Señales**: Fácil reaccionar a cambios en colecciones
5. ✅ **Menos código**: No repetir lógica de add/remove en cada layout
6. ✅ **Auto-layout**: Los cambios disparan automáticamente re-layout

---

## Próximos Pasos Sugeridos

1. ✅ **COMPLETADO**: PlayerDeck y OpponentDeck ahora son DeckDisplay en GameBoard.tscn
2. ✅ **COMPLETADO**: OpponentHand ahora usa HandLayout con dorsos de cartas
3. Crear `DiscardPile` extendiendo CardCollection para yomotsu/cementerio
4. Crear `ExiledPile` para cartas exiliadas/cositos
5. Agregar animaciones en `_update_layout()` para transiciones suaves
6. Implementar drag & drop entre colecciones (HandLayout → Field)

---

## Notas Técnicas

### Mouse Filter
- **CardCollection**: `MOUSE_FILTER_PASS` (deja pasar eventos a hijos)
- **CardDisplay**: `MOUSE_FILTER_STOP` (captura eventos para interacción)

### Señales de CardDisplay
HandLayout se conecta a:
- `mouse_entered` / `mouse_exited` (para hover)
- `drag_started` / `drag_ended` (para drag & drop)

### Performance
- `call_deferred("arrange_cards")` evita múltiples recalculos por frame
- `clear_cards()` usa `queue_free()` para liberar memoria correctamente
