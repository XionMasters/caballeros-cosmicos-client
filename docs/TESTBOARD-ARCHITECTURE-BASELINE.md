# TestBoard Architecture Inventory - Current State

**Fecha**: Diciembre 2025
**Estado**: Pre-cleanup baseline

---

## Componentes del Tablero Actual

### 1. ESTRUCTURA VISUAL (Escena .tscn)

**Archivo**: `scenes/test/TestBoard.tscn`

```
TestBoard (Control)
├── Background (ColorRect)
├── MainContainer (HBoxContainer)
│   ├── LeftColumn (VBoxContainer)
│   │   ├── OpponentDeck (VBoxContainer)
│   │   │   ├── Label ("Mazo Opon")
│   │   │   └── DeckPile (Control) → DeckDisplay script
│   │   ├── Spacer
│   │   └── PlayerDeck (VBoxContainer)
│   │       ├── Label ("Mazo")
│   │       └── DeckPile (Control) → DeckDisplay script
│   │
│   ├── CenterColumn (VBoxContainer) ← MOUSE_FILTER_IGNORE
│   │   ├── OpponentArea (VBoxContainer)
│   │   │   ├── OpponentHeader (HBoxContainer)
│   │   │   │   ├── OpponentAvatar (AvatarDisplay)
│   │   │   │   └── OpponentHand (Control) → HandLayout script
│   │   │   ├── KnightsRow (HBoxContainer) ← 5 slots
│   │   │   │   ├── Knight1 (Control) → CardSlot script
│   │   │   │   ├── Knight2...Knight5
│   │   │   │   └── OccasionSlot
│   │   │   └── TechRow (HBoxContainer) ← 5 slots
│   │   │       ├── Tech1...Tech5
│   │   │       ├── HelperSlot
│   │   │       └── [Empty]
│   │   │
│   │   └── PlayerArea (VBoxContainer)
│   │       ├── KnightsRow (HBoxContainer) ← 5 slots
│   │       ├── TechRow (HBoxContainer) ← 5 slots
│   │       └── PlayerHeader (HBoxContainer)
│   │           ├── PlayerAvatar
│   │           └── PlayerHand (Control) → HandLayout script
│   │
│   └── RightColumn (VBoxContainer)
│       ├── OpponentPiles (Label) ← Yomotsu/Cositos (not implemented)
│       ├── ScenarioSlot (Control)
│       └── PlayerPiles (Label) ← Yomotsu/Cositos (not implemented)
│
└── UILayer (CanvasLayer)
    ├── StatsOverlay
    │   ├── TurnLabel
    │   ├── PhaseLabel
    │   ├── PlayerLabel
    │   ├── PlayerLifeLabel
    │   ├── PlayerCosmosLabel
    │   ├── OpponentLifeLabel
    │   └── OpponentCosmosLabel
    ├── EndTurnButton
    ├── BackButton
    └── LoadingLabel
```

**Nota**: MainContainer y CenterColumn tienen `mouse_filter = 0` (MOUSE_FILTER_IGNORE)

---

### 2. SCRIPTS DE CONTROL (Lógica)

#### TestBoard.gd (MAIN ORCHESTRATOR)
**Responsabilidad**: Orquestar todo el flujo

**Métodos principales**:
- `_ready()` - Inicializar
- `_on_match_started(state: GameState)` - Cuando servidor envía partida
- `_on_match_state_updated()` - Cuando servidor actualiza estado
- `_on_match_error()` - Error del servidor

**Métodos de renderizado (FASE A FASE)**:
- `_render_decks_only()` - FASE 1
- `_animate_initial_deal()` - FASE 2 (async)
- `_render_field_only()` - FASE 3
- `_render_opponent_hand()` - Mano oponente
- `_render_card_in_slot()` - Helper
- `_setup_match_controllers()` - FASE 4

**Métodos UI**:
- `_update_turn_display()` - Actualizar labels
- `_show_error()` - Mostrar error
- `render_all_zones()` - Delegado a BoardRenderer (NO USAR ahora)

**Variables**:
```gdscript
var game_state: GameState
var player_number: int = 1
var board_renderer: BoardRenderer
var match_initializer: MatchInitializer
var match_play_controller: MatchPlayController
var match_event_bridge: MatchEventBridge
```

---

#### BoardRenderer.gd (RENDERIZADOR - NO USAR POR AHORA)
**Responsabilidad**: Renderizar estado del servidor

**Métodos**:
- `render(game_state)` - Punto de entrada único
- `_render_player_hand()`
- `_render_player_field()`
- `_render_player_deck()`
- `_render_opponent_hand()`
- `_render_opponent_field()`
- `_render_opponent_deck()`
- `_render_scenario()`
- `_render_field_slots()`
- `_render_card_in_slot()`
- `_clear_all_zones()`

**Estado**: Existe pero NO está siendo usado en TestBoard ahora (usando fases en su lugar)

---

#### CardDealAnimator.gd (NUEVO - ANIMACIÓN)
**Responsabilidad**: Animar cartas del mazo a la mano

**Métodos**:
- `_init()` - Constructor
- `deal_cards_to_hand()` - Punto de entrada (async)
- `_deal_single_card()` - Anima una carta
- `_animate_card_deal()` - Tween de animación

**Configuración**:
```gdscript
var deal_duration: float = 0.5
var delay_between_cards: float = 0.15
var card_scale: Vector2 = Vector2(0.3, 0.3)
var target_scale: Vector2 = Vector2(1.0, 1.0)
```

---

#### MatchInitializer.gd (FLUJO DE PARTIDA)
**Responsabilidad**: Orquestar inicio de partida

**Flujo**:
1. Fetch decks del usuario
2. Validar deck
3. Pedir al servidor crear match
4. Emitir señales cuando listo

**Señales**:
- `deck_ready(deck: Dictionary)`
- `match_started(state: GameState)`
- `match_error(message: String)`

---

#### MatchPlayController.gd (INPUT HANDLER)
**Responsabilidad**: Escuchar eventos de cartas y validar

**Métodos**:
- `setup_card_interactions()` - Conectar eventos
- `_on_card_drag_started()`
- `_on_card_drag_ended()`
- `_on_card_clicked()`
- `_attempt_play_card()`
- `_validate_card_play()`
- `_detect_drop_slot()`

**Estado**: 
- Tiene parámetro `is_test_mode: bool` para permitir jugar ambos lados

---

#### MatchEventBridge.gd (SERVER COMMUNICATION)
**Responsabilidad**: Traducir eventos locales → servidor

**Métodos**:
- `setup()` - Conectar signals
- `_on_card_play_requested()` - Enviar al servidor
- `_on_phase_changed()`
- `_on_match_error()`
- `_on_match_state_updated()`
- `cleanup()`

---

### 3. MODELOS DE DATOS

#### GameState.gd (SNAPSHOT DE PARTIDA)
**Responsabilidad**: Almacenar estado actual

**Propiedades**:
```gdscript
var match_id: String
var current_turn: int
var current_phase: String
var active_player_number: int  # Turno actual

# Jugador
var player_id: String
var player_number: int  # 1 o 2
var player_hand: Array[CardInstance]
var player_field_knights: Array[CardInstance]
var player_field_techniques: Array[CardInstance]
var player_deck_count: int
var player_life: int
var player_cosmos: int

# Oponente
var opponent_id: String
var opponent_hand_count: int
var opponent_field_knights: Array[CardInstance]
var opponent_field_techniques: Array[CardInstance]
var opponent_deck_count: int
var opponent_life: int
var opponent_cosmos: int

# Escenario compartido
var scenario: CardInstance
```

**Métodos**:
- `from_server_data()` - Factory
- `is_my_turn()`
- `get_hand_for_player()`
- `get_cards_in_zone()`
- `get_deck_size()`

---

#### CardInstance.gd (CARTA EN JUEGO)
**Responsabilidad**: Representar una instancia de carta

**Propiedades**:
```gdscript
var instance_id: String
var base_data: CardData
var zone: String  # "hand", "field_knight", etc.
var position: int
var player_number: int
var mode: String  # "normal", "defense", "evasion"
var is_exhausted: bool
var status_effects: Array
var buffs: Dictionary
```

---

#### CardData.gd (DATOS DE CARTA)
**Responsabilidad**: Información básica de la carta

**Propiedades**:
```gdscript
var id: String
var name: String
var type: String  # "knight", "technique", etc.
var rarity: String
var faction: String
var element: String
var cost: int
var image_url: String
var description: String
var card_knight: CardKnightData  # Si es caballero
```

---

### 4. COMPONENTES UI

#### HandLayout.gd (LAYOUT DE MANO)
**Responsabilidad**: Posicionar y animar cartas en mano

**Métodos**:
- `add_card(card_node)` - Agregar carta
- `remove_card(card_node)` - Remover carta
- `clear_cards()` - Limpiar todo
- `get_cards()` - Obtener array de cartas
- `_update_layout()` - Reposicionar

**Señales**:
- `card_added`
- `card_removed`
- `layout_changed`

**Configuración** (exported):
```gdscript
@export var card_width: float = 120.0
@export var max_total_width: float = 800.0
@export var min_spacing: float = 10.0
@export var card_scale: float = 0.85
@export var hover_scale: float = 1.1
```

---

#### CardDisplay.gd (VISUAL DE CARTA)
**Responsabilidad**: Mostrar carta y manejar input visual

**Estados**:
- IDLE (reposo)
- HOVERING (mouse over)
- HOLDING (drag iniciado)
- MOVING (siendo arrastrada)

**Señales**:
- `drag_started(card_data)`
- `drag_ended(card_data)`
- `card_clicked(card_data)`
- `mouse_entered`
- `mouse_exited`

**Métodos**:
- `setup(card_data)` - Inicializar
- `set_card_image(texture)`

---

#### CardSlot.gd (SLOT DE CAMPO)
**Responsabilidad**: Zona donde se pueden jugar cartas

**Métodos**:
- `set_card(card_display)` - Poner carta
- `clear()` - Quitar carta
- `show_empty()` - Mostrar slot vacío
- `is_empty()`

**Señales**:
- `card_placed(slot, card)`
- `card_removed(slot)`

---

#### DeckDisplay.gd (VISUAL DE MAZO)
**Responsabilidad**: Mostrar pila de mazo con contador

**Métodos**:
- `set_count(count)` - Actualizar contador
- `reset_deck()`
- `push_card_back()` - Sumar 1
- `pop_card_back()` - Restar 1
- `clear_cards()`
- `add_card(card_node)`

---

### 5. MANAGERS GLOBALES (AutoLoad)

#### MatchManager.gd
**Responsabilidad**: Comunicación con servidor vía WebSocket

**Métodos**:
- `play_card(card_id, zone, slot)`
- `end_turn()`
- `request_test_match()`

**Señales**:
- `match_found(match_data)`
- `match_started(game_state)`
- `match_state_updated(match_data)`
- `match_error(error)`
- `match_ended(match_data)`
- `phase_changed(phase)`

---

#### WebSocketManager.gd
**Responsabilidad**: WebSocket low-level

---

#### AuthManager.gd
**Responsabilidad**: Autenticación y sesión

---

#### DecksManager.gd
**Responsabilidad**: Gestionar mazos del usuario

---

#### CardsManager.gd
**Responsabilidad**: Cache de imágenes de cartas

---

### 6. ANIMACIONES

#### CardAnimationManager.gd (ANIMADOR DE CARTAS)
**Responsabilidad**: Tweens para movimiento de cartas

**Métodos**:
- `animate_card_play()`
- `animate_card_hover()`
- `animate_flip_from_deck()`
- `animate_card_draw()`

---

### 7. COMPONENTES NO IMPLEMENTADOS

**Placeholder/Empty**:
- RightColumn (Yomotsu/Cositos - pilas de descarte)
- ScenarioSlot (Escenario compartido)
- Indicator de turno visual
- Chat (existe en otras escenas)
- Efectos de batalla (CombatAnimator existe pero no usado)
- Animaciones de daño
- Sonidos

---

## Flujo Actual de Ejecución

```
Godot Load TestBoard.tscn
  ↓
TestBoard._ready()
  ├─ Inicializar nodos
  ├─ Conectar signals
  └─ Conectar MatchManager.match_started
  ↓
MatchInitializer.start_match()
  ├─ Fetch decks
  ├─ Validar
  └─ Pedir match TEST al servidor
  ↓
Servidor responde: match_found
  ↓
MatchManager emite: match_started(GameState)
  ↓
TestBoard._on_match_started(GameState)
  ├─ FASE 1: _render_decks_only()
  ├─ FASE 2: _animate_initial_deal() [async]
  ├─ FASE 3: _render_field_only()
  └─ FASE 4: _setup_match_controllers()
  ↓
Cuando usuario arrastra carta:
  ├─ CardDisplay emite: drag_started
  ├─ MatchPlayController recibe
  ├─ Valida
  ├─ Emite: card_play_requested
  ├─ MatchEventBridge recibe
  ├─ MatchManager.play_card() [HTTP]
  └─ Servidor responde
  ↓
Servidor emite WebSocket: match_state_updated
  ↓
MatchManager emite: match_state_updated(data)
  ↓
TestBoard._on_match_state_updated()
  └─ Llama render_all_zones() [BOARDRENDERER]
```

---

## Problemas Identificados

### 1. DUPLICACIÓN DE CARTAS ❌
**Dónde**: CardDealAnimator + render_all_zones()

**Causa probable**: 
- CardDealAnimator agrega cartas a player_hand via `player_hand.add_card()`
- Luego BoardRenderer.render() vuelve a agregar las mismas cartas
- O _on_match_state_updated() vuelve a renderizar

**Solución**: NO llamar a render_all_zones() en _on_match_started()

---

### 2. CARTAS NO INTERACTUABLES ❌
**Dónde**: MatchPlayController.setup_card_interactions()

**Causa probable**:
- mouse_filter en nodos padres bloqueando eventos
- CardDisplay no recibiendo drag events
- setup_card_interactions() no llamándose después de animar

**Solución**: 
- Simplificar TestBoard
- Solo cartas en mano visibles
- Conectar eventos solo a player_hand
- Quitar field slots temporalmente

---

## Componentes a Eliminar (CLEANUP)

Para simplificar al mínimo:

- ❌ RightColumn (Yomotsu/Cositos)
- ❌ OpponentArea field slots
- ❌ PlayerArea field slots
- ❌ ScenarioSlot
- ❌ opponent_knight_slots array
- ❌ opponent_tech_slots array
- ❌ player_knight_slots array
- ❌ player_tech_slots array
- ❌ player_helper_slot
- ❌ player_occasion_slot
- ❌ opponent_helper_slot
- ❌ opponent_occasion_slot
- ❌ opponent_avatar
- ❌ _render_field_only()
- ❌ _render_card_in_slot()
- ❌ BoardRenderer (por ahora)

---

## Componentes a Mantener (MINIMAL)

Para PHASE 1-2 solamente:

- ✅ LeftColumn (Mazos)
- ✅ player_deck (DeckDisplay)
- ✅ opponent_deck (DeckDisplay)
- ✅ CenterColumn
- ✅ OpponentArea.OpponentHand (HandLayout)
- ✅ PlayerArea.PlayerHand (HandLayout)
- ✅ CardDealAnimator
- ✅ CardDisplay
- ✅ HandLayout
- ✅ GameState
- ✅ CardInstance
- ✅ TestBoard (simplificado)

---

## Próximo Estado Deseado

```
TestBoard (MINIMAL)
├── Background
├── MainContainer
│   ├── LeftColumn (Mazos)
│   │   ├── OpponentDeck → DeckPile
│   │   ├── Spacer
│   │   └── PlayerDeck → DeckPile
│   │
│   └── CenterColumn
│       ├── OpponentArea
│       │   └── OpponentHand (HandLayout) [7 dorsos]
│       │
│       └── PlayerArea
│           └── PlayerHand (HandLayout) [7 cartas visibles]
│
└── UILayer
    └── StatsOverlay (labels básicos)
```

**Líneas de código**: ~500 en TestBoard (vs ~800 ahora)
**Complejidad**: Baja, enfocada en mano

---

## Checklist de Cleanup

- [ ] Documentar esto PRIMERO ✅
- [ ] Identificar causa de duplicación
- [ ] Eliminar _render_field_only()
- [ ] Eliminar todas las referencias a field slots
- [ ] Eliminar RightColumn de escena
- [ ] Simplificar _on_match_started()
- [ ] Probar que mano sin duplicación
- [ ] Probar que cartas son interactuables
- [ ] Documentar cambios

