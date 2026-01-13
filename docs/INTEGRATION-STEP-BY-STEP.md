# ✅ GUÍA CORREGIDA: Integración Paso a Paso

**Fecha**: Diciembre 15, 2025
**Estado**: ✅ LISTO PARA IMPLEMENTAR

---

## 🎯 Objetivo
Integrar los 7 managers en tu GameBoard.gd sin errores.

---

## 📋 Método Recomendado: Paso a Paso

**NO copies todo el archivo de ejemplo de una vez.**
**Hazlo función por función, testeando cada paso.**

---

## PASO 1: Declarar Variables (5 minutos)

Abre tu `GameBoard.gd` y agrega estas variables:

```gdscript
# ======== MANAGERS (Agrega al inicio del archivo) ========
var deck_loader: DeckLoadingManager = null
var card_play_manager: CardPlayManager = null
var animation_manager: CardAnimationManager = null
var card_factory: CardDisplayFactory = null
var player_state: PlayerState = null
var opponent_state: PlayerState = null
var player_knight_slots_group: SlotGroup = null
var player_technique_slots_group: SlotGroup = null
var opponent_knight_slots_group: SlotGroup = null
var opponent_technique_slots_group: SlotGroup = null

# Scenes (verifica que existen)
const CARD_DISPLAY_SCENE = preload("res://scenes/components/cards/CardDisplay.tscn")
const CARD_BACK_TEMPLATE = preload("res://scenes/components/cards/CardBack.tscn")
```

**Testear**: `F5` → Debe compilar sin errores

---

## PASO 2: Crear Función de Setup de Managers (10 minutos)

Agrega esta función:

```gdscript
func _setup_managers() -> void:
    print("[GameBoard] Configurando managers...")
    
    # 1. DeckLoadingManager
    deck_loader = DeckLoadingManager.new()
    add_child(deck_loader)
    
    # 2. CardPlayManager
    card_play_manager = CardPlayManager.new()
    add_child(card_play_manager)
    
    # 3. CardAnimationManager
    animation_manager = CardAnimationManager.new()
    add_child(animation_manager)
    animation_manager.card_play_duration = 0.4
    animation_manager.hover_scale = 1.1
    
    # 4. CardDisplayFactory
    card_factory = CardDisplayFactory.new(CARD_DISPLAY_SCENE, CARD_BACK_TEMPLATE)
    
    print("[GameBoard] ✓ Managers creados")
```

**Testear**:
```gdscript
func _ready() -> void:
    _setup_managers()
    # (Comenta el resto por ahora)
```

Debe imprimir: `[GameBoard] ✓ Managers creados`

---

## PASO 3: Setup de PlayerState (10 minutos)

Agrega esta función:

```gdscript
func _setup_player_states() -> void:
    print("[GameBoard] Configurando estado del jugador...")
    
    var current_user_id = AuthManager.get_user_id()
    
    # Player 1
    player_state = PlayerState.new(current_user_id, 1)
    player_state.max_cosmos = 10
    player_state.current_cosmos = 3
    player_state.current_health = 20
    
    # Opponent
    opponent_state = PlayerState.new("opponent-id", 2)
    opponent_state.max_cosmos = 10
    opponent_state.current_cosmos = 3
    opponent_state.current_health = 20
    
    print("[GameBoard] ✓ PlayerState creados")
```

**Testear**:
```gdscript
func _ready() -> void:
    _setup_managers()
    _setup_player_states()
```

---

## PASO 4: Setup de SlotGroups (15 minutos)

Agrega esta función:

```gdscript
func _setup_slot_groups() -> void:
    print("[GameBoard] Configurando slot groups...")
    
    # Obtener referencias a slots desde la escena
    # ⚠️ IMPORTANTE: Ajusta estas rutas según tu escena
    var knight_slots_container = $MainContainer/CenterColumn/PlayerArea/KnightsRow
    var technique_slots_container = $MainContainer/CenterColumn/PlayerArea/TechRow
    
    # Para obtener slots, itera sobre children que sean CardSlot
    var player_knights: Array = []
    var player_techniques: Array = []
    
    for child in knight_slots_container.get_children():
        if child is CardSlot:
            player_knights.append(child)
    
    for child in technique_slots_container.get_children():
        if child is CardSlot:
            player_techniques.append(child)
    
    # Crear groups
    player_knight_slots_group = SlotGroup.new("knights", 5)
    player_knight_slots_group.initialize_from_nodes(player_knights)
    
    player_technique_slots_group = SlotGroup.new("techniques", 5)
    player_technique_slots_group.initialize_from_nodes(player_techniques)
    
    # Similar para opponent
    var opp_knight_slots_container = $MainContainer/CenterColumn/OpponentArea/KnightsRow
    var opp_technique_slots_container = $MainContainer/CenterColumn/OpponentArea/TechRow
    
    var opponent_knights: Array = []
    var opponent_techniques: Array = []
    
    for child in opp_knight_slots_container.get_children():
        if child is CardSlot:
            opponent_knights.append(child)
    
    for child in opp_technique_slots_container.get_children():
        if child is CardSlot:
            opponent_techniques.append(child)
    
    opponent_knight_slots_group = SlotGroup.new("knights", 5)
    opponent_knight_slots_group.initialize_from_nodes(opponent_knights)
    
    opponent_technique_slots_group = SlotGroup.new("techniques", 5)
    opponent_technique_slots_group.initialize_from_nodes(opponent_techniques)
    
    print("[GameBoard] ✓ SlotGroups creados")
```

**⚠️ IMPORTANTE**: Verifica que las rutas de containers coinciden con tu escena:
- `$MainContainer/CenterColumn/PlayerArea/KnightsRow`
- `$MainContainer/CenterColumn/PlayerArea/TechRow`
- `$MainContainer/CenterColumn/OpponentArea/KnightsRow`
- `$MainContainer/CenterColumn/OpponentArea/TechRow`

Si no existen, abre GameBoard.tscn y ajusta los nombres.

---

## PASO 5: Cargar Mazo (15 minutos)

Agrega esta función:

```gdscript
func _load_deck() -> void:
    print("[GameBoard] Cargando mazo...")
    
    # Llamar DeckLoadingManager
    await deck_loader.fetch_and_load_active_deck()
    
    print("[GameBoard] ✓ Mazo cargado")
    
    # Dibujar mano inicial
    await _draw_initial_hand()


func _draw_initial_hand() -> void:
    print("[GameBoard] Dibujando mano inicial...")
    
    # Obtener 7 cartas
    var initial_cards = deck_loader.draw_cards_from_deck(7)
    if initial_cards.size() == 0:
        push_error("No hay cartas en el mazo")
        return
    
    # Crear CardDisplay para cada una
    var card_displays = await card_factory.create_batch(initial_cards, true)
    
    # Agregar a la mano
    for card_display in card_displays:
        player_hand.add_card(card_display)
        # Conectar click (lo haremos después)
    
    print("[GameBoard] ✓ Mano inicial dibujada (%d cartas)" % card_displays.size())
```

**Testear**:
```gdscript
func _ready() -> void:
    _setup_managers()
    _setup_player_states()
    _setup_slot_groups()
    await _load_deck()  # ← Esperar a que cargue
    print("GameBoard inicializado")
```

---

## PASO 6: Conectar Señales (10 minutos)

Agrega esta función:

```gdscript
func _connect_signals() -> void:
    print("[GameBoard] Conectando señales...")
    
    # PlayerState signals
    player_state.cosmos_changed.connect(_on_player_cosmos_changed)
    player_state.health_changed.connect(_on_player_health_changed)
    
    opponent_state.cosmos_changed.connect(_on_opponent_cosmos_changed)
    opponent_state.health_changed.connect(_on_opponent_health_changed)
    
    # CardPlayManager signals
    card_play_manager.card_played.connect(_on_card_played)
    card_play_manager.cost_not_affordable.connect(_on_cost_not_affordable)
    
    # Server signals (si tienes MatchManager)
    if MatchManager:
        MatchManager.match_state_updated.connect(_on_match_state_updated)
    
    print("[GameBoard] ✓ Señales conectadas")
```

Y agrega estos handlers básicos:

```gdscript
func _on_player_cosmos_changed(new_amount: int, old_amount: int) -> void:
    print("[GameBoard] Cosmos: %d → %d" % [old_amount, new_amount])
    # TODO: Actualizar label de cosmos en UI

func _on_player_health_changed(new_amount: int, old_amount: int) -> void:
    print("[GameBoard] HP: %d → %d" % [old_amount, new_amount])
    # TODO: Actualizar barra de HP en UI

func _on_opponent_cosmos_changed(new_amount: int, old_amount: int) -> void:
    print("[GameBoard] Cosmos oponente: %d → %d" % [old_amount, new_amount])

func _on_opponent_health_changed(new_amount: int, old_amount: int) -> void:
    print("[GameBoard] HP oponente: %d → %d" % [old_amount, new_amount])

func _on_card_played(card_instance: CardInstance, success: bool) -> void:
    print("[GameBoard] Carta jugada: %s (%s)" % [card_instance.base_data.name, "éxito" if success else "fallo"])

func _on_cost_not_affordable(card_instance: CardInstance, required: int, available: int) -> void:
    print("[GameBoard] Cosmos insuficiente: requiere %d, tiene %d" % [required, available])

func _on_match_state_updated(match_data: Dictionary) -> void:
    print("[GameBoard] Actualización del servidor recibida")
    # TODO: Sincronizar UI con servidor
```

---

## PASO 7: Actualizar _ready() (5 minutos)

Reemplaza tu `_ready()` con esto:

```gdscript
func _ready() -> void:
    print("\n[GameBoard] ============ INICIALIZANDO PARTIDA ============")
    
    # 1. Managers
    _setup_managers()
    
    # 2. Estado jugador
    _setup_player_states()
    
    # 3. Slot groups
    _setup_slot_groups()
    
    # 4. Cargar mazo
    await _load_deck()
    
    # 5. Conectar señales
    _connect_signals()
    
    print("[GameBoard] ✓ PARTIDA INICIALIZADA CORRECTAMENTE\n")
```

---

## 🧪 TESTEAR TODO

```gdscript
# En _ready() agrega al final:
print("\n=== ESTADO INICIAL ===")
print("Cosmos: %d/%d" % [player_state.current_cosmos, player_state.max_cosmos])
print("HP: %d" % player_state.current_health)
print("Mano: %d cartas" % player_hand.get_cards().size())
print(player_knight_slots_group.get_debug_status())
print("===================\n")
```

**Esperado**:
```
[GameBoard] ✓ Managers creados
[GameBoard] ✓ PlayerState creados
[GameBoard] ✓ SlotGroups creados
[GameBoard] ✓ Mazo cargado
[GameBoard] ✓ Mano inicial dibujada (7 cartas)
[GameBoard] ✓ Señales conectadas

=== ESTADO INICIAL ===
Cosmos: 3/10
HP: 20
Mano: 7 cartas
KNIGHTS: 0/5 (□□□□□)
===================
```

---

## 🚀 Una Vez que Funciona...

Puedes agregar:
1. Click en cartas → Jugar
2. Animaciones
3. Actualización desde servidor
4. Más lógica de juego

Pero primero, **verifica que todo esto compila sin errores.**

---

## ⚠️ Errores Comunes

### "Method not found: add_card"
→ HandLayout no tiene el método → Verifica el nombre correcto

### "Node not found"
→ Rutas @onready incorrectas → Abre GameBoard.tscn y verifica

### "Signal not connected"
→ Referencia a nodo inexistente → Verifica que MatchManager existe

### "CardSlot no existe"
→ Los slots se llaman diferente → Busca en GameBoard.tscn qué clase usan

---

## 💡 Consejo: Usa print() para Debug

```gdscript
func _setup_slot_groups() -> void:
    print("Knight container: %s" % $MainContainer/CenterColumn/PlayerArea/KnightsRow)
    print("Children: %d" % $MainContainer/CenterColumn/PlayerArea/KnightsRow.get_child_count())
    
    for child in $MainContainer/CenterColumn/PlayerArea/KnightsRow.get_children():
        print("  - %s (tipo: %s)" % [child.name, child.get_class()])
```

Esto te ayuda a ver si la ruta es correcta.

---

**Guía de Integración Paso a Paso v1.0**
**Fecha**: Diciembre 15, 2025
**Estado**: ✅ LISTO PARA SEGUIR

