# REFERENCIA RÁPIDA: Todos los Managers

**Última actualización**: Diciembre 15, 2025

---

## 🎯 Managers Disponibles

### 1. DeckLoadingManager
**Propósito**: Cargar mazo desde servidor con deduplicación de imágenes
**Ubicación**: `scripts/managers/DeckLoadingManager.gd`

```gdscript
# Uso básico
deck_loader = DeckLoadingManager.new()
add_child(deck_loader)
await deck_loader.fetch_and_load_active_deck()

# Señales
deck_loader.deck_loading_started.connect(...)
deck_loader.deck_cards_loaded.connect(...)
deck_loader.all_images_loaded.connect(...)
deck_loader.loading_complete.connect(...)

# Métodos
var cards: Array[CardInstance] = deck_loader.draw_cards_from_deck(7)
var remaining: int = deck_loader.get_remaining_deck_count()
deck_loader.reset_deck()
```

---

### 2. CardCostValidator
**Propósito**: Validar si jugador tiene recursos para jugar carta
**Ubicación**: `scripts/game/CardCostValidator.gd`

```gdscript
# Uso básico
validator = CardCostValidator.new()
validator.player_resources[CardCostValidator.ResourceType.COSMOS] = 10

# Validar costo
if validator.can_afford_card(card_instance):
    validator.play_card(card_instance)

# Gestionar recursos manualmente
validator.add_player_resource(CardCostValidator.ResourceType.COSMOS, 5)
validator.subtract_player_resource(CardCostValidator.ResourceType.COSMOS, 3)

# Obtener costo aplicando modificadores
var cost: int = validator.get_card_cost(card_instance)

# Debug
validator.debug_print_resources()
# Output: COSMOS: 2/10 | ENERGY: 0/20 | HEALTH: 15/20
```

**Tipos de recursos**:
- `MANA` - Azul, regenera cada turno
- `COSMOS` - Violeta, límite variable
- `ENERGY` - Verde, costo de ataques
- `HEALTH` - Rojo, costo de sacrificios
- `GENERIC` - Gris, cualquier recurso

---

### 3. CardPlayManager
**Propósito**: Orquestar todo el proceso de jugar una carta
**Ubicación**: `scripts/game/CardPlayManager.gd`

```gdscript
# Uso básico
play_manager = CardPlayManager.new()
add_child(play_manager)

# Jugar carta
play_manager.play_card_to_field(card_instance, "field_knight", 0)

# Con mano
play_manager.play_card_from_hand(card_display, "field_technique", 2)

# Validar antes
if play_manager.can_play_card(card_instance, player_cosmos):
    play_manager.play_card_to_field(card_instance, "field_knight", 0)

# Señales
play_manager.card_played.connect(_on_card_played)
play_manager.cost_not_affordable.connect(_on_cost_not_affordable)
play_manager.card_played_feedback.connect(_on_feedback)
```

**Zonas válidas**:
- `field_knight` - Caballeros en batalla
- `field_technique` - Técnicas activadas
- `field_item` - Ítems equippados
- `field_helper` - Ayudante activado
- `field_scenario` - Escenario activo

---

### 4. PlayerState
**Propósito**: Gestionar estado completo del jugador
**Ubicación**: `scripts/models/PlayerState.gd`

```gdscript
# Crear instancia para cada jugador
player1 = PlayerState.new("player-id-123", 1)
player1.max_cosmos = 10
player1.current_cosmos = 3
player1.current_health = 20

# Gestionar cosmos
player1.add_cosmos(5)          # Sube a 8
player1.subtract_cosmos(2)     # Baja a 6
if not player1.subtract_cosmos(10):
    print("Sin cosmos suficiente")

# Gestionar salud
player1.take_damage(5)         # Pierde 5 HP
player1.heal(3)                # Recupera 3 HP

# Registrar acciones
player1.draw_cards(7)
player1.play_card()

# Obtener porcentajes (para UI)
var cosmos_pct: float = player1.get_cosmos_percentage()
var health_pct: float = player1.get_health_percentage()

# Señales
player1.cosmos_changed.connect(_on_cosmos_changed)
player1.health_changed.connect(_on_health_changed)
player1.cards_drawn.connect(_on_cards_drawn)
player1.player_defeated.connect(_on_player_defeated)
```

---

### 5. CardDisplayFactory
**Propósito**: Crear CardDisplay sin duplicación de código
**Ubicación**: `scripts/factories/CardDisplayFactory.gd`

```gdscript
# Inicializar factory
factory = CardDisplayFactory.new(CARD_DISPLAY_SCENE, CARD_BACK_SCENE)

# Crear desde instancia (con animación)
var card = factory.create_from_instance(card_instance, deck_position, true)

# Crear con animación de mazo
var card = await factory.create_with_deck_animation(card_instance, deck_pos)

# Crear lote (varias cartas)
var cards = await factory.create_batch(card_instances, true)  # true = animar

# Crear para preview (sin instancia en juego)
var preview = factory.create_from_data(card_data, true)

# Resetear para reutilizar
factory.reset_card_display(card_display)
```

---

### 6. CardAnimationManager
**Propósito**: Centralizar todas las animaciones de cartas
**Ubicación**: `scripts/managers/CardAnimationManager.gd`

```gdscript
# Inicializar
anim_mgr = CardAnimationManager.new()
add_child(anim_mgr)

# Configurar duración (opcional)
anim_mgr.card_play_duration = 0.5
anim_mgr.hover_scale = 1.15

# Animaciones comunes
anim_mgr.animate_card_hover(card, true)           # Elevar al hover
anim_mgr.animate_card_hover(card, false)          # Volver a normal

anim_mgr.animate_card_play(card, slot_position)   # Jugar (vuela al slot)
anim_mgr.animate_card_discard(card, discard_pos)  # Descartar (rota + fade)

anim_mgr.animate_flip_from_deck(card, deck_pos)   # Dibujar (crece desde mazo)
anim_mgr.animate_card_removed(card)               # Eliminada (escala a 0)

# Animaciones de batalla
anim_mgr.animate_mode_change(card, "defense")     # Entrar defensa
anim_mgr.animate_mode_change(card, "evasion")     # Entrar evasión
anim_mgr.animate_mode_change(card, "exhausted")   # Agotar
anim_mgr.animate_mode_change(card, "normal")      # Resetear

anim_mgr.animate_attack_pulse(card, target_pos)   # Atacar
anim_mgr.animate_take_damage(card)                # Recibir daño

# Animaciones en lote
await anim_mgr.animate_batch_draw(cards)          # Dibujar mano inicial
```

**Modos de battle animados**:
- `defense` - Gris, inclinación
- `evasion` - Cyan, escala hacia arriba
- `exhausted` - Desaturado
- `normal` - Blanco, normal

---

### 7. SlotGroup
**Propósito**: Gestionar grupos de slots unificados
**Ubicación**: `scripts/models/SlotGroup.gd`

```gdscript
# Crear y inicializar
knights = SlotGroup.new("knights", 5)
knights.initialize_from_nodes(board.player_knight_slots)

# Obtener slots
var empty: Array[CardSlot] = knights.get_empty_slots()
var first_empty: CardSlot = knights.get_first_empty_slot()
var occupied: Array[CardSlot] = knights.get_occupied_slots()
var at_index: CardSlot = knights.get_slot_at(0)

# Información de estado
var available: int = knights.get_available_count()
var occupied: int = knights.get_occupied_count()
var is_full: bool = knights.is_full()

# Operaciones en lote
knights.clear_all()
knights.for_each(func(slot): print(slot.name))
knights.for_each_empty(func(slot): slot.highlight())
knights.for_each_occupied(func(slot): slot.dim())

# Conectar señales a todos los slots
knights.connect_signal_all("card_placed", _on_card_placed)
knights.disconnect_signal_all("card_placed", _on_card_placed)

# Debug
print(knights.get_debug_status())
# Output: KNIGHTS: 2/5 (■■□□□)
knights.debug_print()
```

---

## 🔗 Cómo Integrarlos

### Patrón Básico en GameBoard

```gdscript
extends Node

# 1. Declarar
var deck_loader: DeckLoadingManager
var card_play_manager: CardPlayManager
var animation_manager: CardAnimationManager
var player_state: PlayerState

func _ready() -> void:
	# 2. Crear
	deck_loader = DeckLoadingManager.new()
	add_child(deck_loader)
	
	card_play_manager = CardPlayManager.new()
	add_child(card_play_manager)
	
	animation_manager = CardAnimationManager.new()
	add_child(animation_manager)
	
	player_state = PlayerState.new("player-id", 1)
	
	# 3. Conectar señales
	player_state.cosmos_changed.connect(_on_cosmos_changed)
	card_play_manager.card_played.connect(_on_card_played)
	
	# 4. Usar
	await deck_loader.fetch_and_load_active_deck()
	_draw_initial_hand()

func _draw_initial_hand() -> void:
	var cards = deck_loader.draw_cards_from_deck(7)
	for card in cards:
		var display = CARD_SCENE.instantiate()
		display.setup_from_instance(card)
		player_hand.add_card(display)
		animation_manager.animate_flip_from_deck(display, deck_pos)
```

---

## 📊 Flujo Completo: Jugar Una Carta

```
Usuario click en carta en mano
    ↓
GameBoard._on_card_clicked() llama CardPlayManager
    ↓
CardPlayManager.can_play_card() valida cosmos
    ↓
Si NO tiene cosmos:
    CardPlayManager emite: cost_not_affordable()
    GameBoard muestra: "Sin cosmos suficiente"
    ↓ FIN
    
Si SÍ tiene cosmos:
    CardPlayManager envía HTTPRequest a servidor
    ↓
Servidor valida y responde OK
    ↓
CardPlayManager emite: card_played(card, true)
    ↓
GameBoard:
    - PlayerState.subtract_cosmos(costo)
    - CardAnimationManager.animate_card_play(card, slot)
    - player_hand.remove_card(card)
    ↓
UI actualiza automáticamente (señal cosmos_changed)
    ↓ FIN
```

---

## 🚨 Errores Comunes

### Error 1: "Manager no inicializado"
```gdscript
# ❌ MALO
animation_manager.animate_card_play(card, pos)  # No exists!

# ✅ CORRECTO
animation_manager = CardAnimationManager.new()
add_child(animation_manager)
animation_manager.animate_card_play(card, pos)
```

### Error 2: "Signal no emitida"
```gdscript
# ❌ MALO
play_manager.card_played.connect(_on_card_played)
# ... no pasa nada

# ✅ CORRECTO
play_manager = CardPlayManager.new()
add_child(play_manager)
play_manager.card_played.connect(_on_card_played)
play_manager.play_card_from_hand(card, "knights", 0)  # Ahora emite
```

### Error 3: "Slot group vacío"
```gdscript
# ❌ MALO
knights_group = SlotGroup.new("knights", 5)
print(knights_group.all_slots.size())  # Output: 0

# ✅ CORRECTO
knights_group = SlotGroup.new("knights", 5)
knights_group.initialize_from_nodes(board.knight_slots)
print(knights_group.all_slots.size())  # Output: 5
```

---

## 📞 Contacto Rápido

| Necesito... | Uso... | Método |
|------------|--------|--------|
| Cargar mazo | DeckLoadingManager | `fetch_and_load_active_deck()` |
| Validar costo | CardCostValidator | `can_afford_card()` |
| Jugar carta | CardPlayManager | `play_card_to_field()` |
| Actualizar UI | PlayerState | `cosmos_changed` signal |
| Animar carta | CardAnimationManager | `animate_*()` |
| Gestionar slots | SlotGroup | `get_empty_slots()` |
| Crear CardDisplay | CardDisplayFactory | `create_from_instance()` |

---

## ✅ Checklist Rápido

- [ ] ¿Importé todas las clases? (class_name al inicio de archivo)
- [ ] ¿Inicialicé los managers en _ready()?
- [ ] ¿Agregué los managers como children con add_child()?
- [ ] ¿Conecté las señales?
- [ ] ¿Probé que los managers funcionen sin errores?
- [ ] ¿Verifiqué que las animaciones se reproducen?
- [ ] ¿Probé el flujo completo (click → validación → servidor)?

---

**Documento de referencia rápida**
**Mantener actualizado mientras se agregan nuevos managers**
**Última revisión**: Diciembre 15, 2025

