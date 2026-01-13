# Copilot Instructions: Caballeros Cósmicos - Godot Client

## Project Overview
This is a Godot 4.x client for the Saint Seiya-themed card game "Caballeros Cósmicos". The game connects to a TypeScript/Express backend via HTTP and WebSocket.

## Architecture & Tech Stack

### Core Technologies
- **Engine**: Godot 4.x (GDScript with strict typing)
- **Backend**: Node.js Express API + WebSocket
- **Config**: `GameConfig.gd` - Centralized API/WS URLs
- **Managers**: Singleton pattern (autoloads)

### Key Managers (Autoloads)
```
NetworkManager     → HTTP requests (cards, decks, auth)
WebSocketManager   → Real-time match events
CardsManager       → Card data cache + image loading
MatchManager       → Match state synchronization
LocalizationManager → i18n (es/en/pt)
AudioManager       → Sound effects + music
```

### Card Game Domain
- **Card Types**: `knight`, `technique`, `item`, `stage`, `helper`, `event` (English internally)
- **Rarities**: `common`, `rare`, `epic`, `legendary`, `divine` (English internally)
- **Factions**: `Athena`, `Poseidon`, `Hades`, etc.
- **Elements**: `steel`, `fire`, `water`, `earth`, `wind`, `light`, `dark`

**Important**: All enum values are stored in English internally, translated via LocalizationManager for UI.

---

## UI Architecture: CardCollection Pattern

### Inheritance Hierarchy
```
Control
└── CardCollection (abstract base class)
    ├── HandLayout (horizontal card layout with hover/drag)
    ├── DeckDisplay (stack-based deck with counter)
    └── [Future] DiscardPile, ExiledPile, etc.
```

### CardCollection Base Class
**Location**: `scripts/models/CardCollection.gd`

**Purpose**: Abstract base for visual card collections (not game logic)

**Responsibilities**:
- ✅ Manage internal array of card nodes (`_cards`)
- ✅ Provide common API: `add_card()`, `remove_card()`, `clear_cards()`, `get_cards()`
- ✅ Emit signals on changes
- ✅ Call `_update_layout()` template method (override in subclasses)
- ❌ Does NOT position cards (subclass responsibility)
- ❌ Does NOT handle game logic

**Key Methods**:
```gdscript
func add_card(card_node: Node) -> void
func remove_card(card_node: Node) -> void
func clear_cards() -> void
func get_cards() -> Array
func _update_layout() -> void  # Template method - override in subclasses
```

**Signals**:
```gdscript
signal card_added(card_node)
signal card_removed(card_node)
signal layout_changed()
```

---

## HandLayout (Player/Opponent Hand)

**Location**: `scripts/game/HandLayout.gd`

**Purpose**: Horizontal card layout with smart spacing and hover effects

**Features**:
- Horizontal layout with automatic overlapping if many cards
- Hover: elevates and scales card
- Drag & drop support
- Auto-centering in container

**Exported Parameters**:
```gdscript
@export var card_width: float = 120.0
@export var max_total_width: float = 800.0
@export var min_spacing: float = 10.0
@export var card_scale: float = 0.85
@export var hover_scale: float = 1.1
@export var hover_offset_y: float = -50.0
```

**Usage in GameBoard**:
```gdscript
# Player hand (known cards)
@onready var player_hand = $MainContainer/CenterColumn/PlayerHand

var card_display = CARD_DISPLAY_TEMPLATE.instantiate()
card_display.setup(card_data)
player_hand.add_card(card_display)  # Auto-layout

# Opponent hand (card backs)
@onready var opponent_hand = $MainContainer/.../OpponentHand

var card_back = CARD_BACK_TEMPLATE.instantiate()
opponent_hand.add_card(card_back)  # Shows card count, not content
```

**Current Instances**:
- `PlayerHand`: `card_width=120`, `card_scale=0.85`, `hover_scale=1.1` (full interaction)
- `OpponentHand`: `card_width=100`, `card_scale=0.7`, `hover_scale=0.7` (no hover, just display)

---

## DeckDisplay (Deck Stacks)

**Location**: `scripts/models/DeckDisplay.gd`

**Purpose**: Stack-based visual representation of decks (draw pile, graveyard, etc.)

**Features**:
- Shows up to `max_visible_cards` (default 3) with `stack_offset` (6px vertical)
- Counter label overlay
- Methods: `set_count()`, `reset_deck()`, `push_card_back()`, `pop_card_back()`

**Exported Parameters**:
```gdscript
@export var max_visible_cards: int = 3
@export var card_back_scene: PackedScene  # res://scenes/ui/CardBack.tscn
@export var stack_offset: float = 6.0
@export var show_counter: bool = true
```

**Usage in GameBoard**:
```gdscript
@onready var player_deck = $MainContainer/LeftColumn/PlayerDeck/DeckPile
@onready var opponent_deck = $MainContainer/LeftColumn/OpponentDeck/DeckPile

# Update counts
player_deck.set_count(35)
opponent_deck.set_count(32)

# Draw card animation
player_deck.pop_card_back()  # Visual decrement

# Shuffle card back to deck
player_deck.push_card_back()  # Visual increment
```

**Warning**: Do NOT use `add_card()` / `remove_card()` directly on DeckDisplay. Use `set_count()`, `push_card_back()`, `pop_card_back()` instead.

**Current Instances**:
- `PlayerDeck/DeckPile`: DeckDisplay with card_back_scene assigned
- `OpponentDeck/DeckPile`: DeckDisplay with card_back_scene assigned

---

## Data Models

### CardData
**Location**: `scripts/cards/CardData.gd`

Basic card information from backend:
```gdscript
var id: String
var name: String
var type: String           # "knight", "technique", etc.
var rarity: String         # "common", "rare", etc.
var faction: String        # "Athena", "Poseidon", etc.
var element: String        # "steel", "fire", etc.
var image_url: String
var description: String
var cost: int
var card_knight: CardKnightData  # If type == "knight"
```

### CardInstance
**Location**: `scripts/models/CardInstance.gd`

Instance of a card in play (includes status):
```gdscript
var instance_id: String
var base_data: CardData
var zone: String           # "hand", "field_knight", "field_support", etc.
var position: int          # Index in zone
var field_slot: int        # Deprecated (use position)
var player_number: int     # 1 or 2
var mode: String          # "normal", "defense", "evasion"
var is_exhausted: bool
var status_effects: Array
var buffs: Dictionary
```

### GameState
**Location**: `scripts/models/GameState.gd`

Snapshot of match state (read-only data model):
```gdscript
var match_id: String
var current_turn: int
var current_phase: String
var player_number: int
var opponent_id: String

# Player zones
var player_hand: Array[CardInstance]
var player_field_knights: Array[CardInstance]  # Max 5
var player_field_techniques: Array[CardInstance]  # Max 5
var player_helper: CardInstance
var player_deck_count: int

# Opponent zones (limited info)
var opponent_hand_count: int  # ⚠️ Count only, not cards themselves
var opponent_field_knights: Array[CardInstance]
var opponent_field_techniques: Array[CardInstance]
var opponent_deck_count: int

# Shared
var scenario: CardInstance
```

**Factory Method**:
```gdscript
static func from_server_data(data: Dictionary, local_player_id: String) -> GameState
```

---

## GameBoard Integration

**File**: `scenes/game/GameBoard.gd` (755+ lines)

### Key Methods

#### `render_all_zones()`
Called when `MatchManager.match_state_updated` fires:
```gdscript
func render_all_zones():
    _clear_all_zones()
    
    # Player hand (known cards)
    for card in game_state.player_hand:
        _add_card_to_hand(card)
    
    # Opponent hand (card backs)
    _render_opponent_hand(game_state.opponent_hand_count)
    
    # Field knights/techniques
    # ...
```

#### `_render_opponent_hand(card_count: int)`
```gdscript
func _render_opponent_hand(card_count: int):
    opponent_hand.clear_cards()
    for i in range(card_count):
        var card_back = CARD_BACK_TEMPLATE.instantiate()
        opponent_hand.add_card(card_back)
```

#### `_update_pile_counts()`
```gdscript
func _update_pile_counts():
    if player_number == 1:
        player_deck.set_count(current_match.get("player1_deck_size", 40))
        opponent_deck.set_count(current_match.get("player2_deck_size", 40))
    else:
        player_deck.set_count(current_match.get("player2_deck_size", 40))
        opponent_deck.set_count(current_match.get("player1_deck_size", 40))
```

#### `_clear_all_zones()`
```gdscript
func _clear_all_zones():
    # Clear field slots
    for slot in player_knight_slots:
        slot.clear()
    
    # Clear hands
    player_hand.clear_cards()
    opponent_hand.clear_cards()
```

---

## WebSocket Events

**File**: `scripts/managers/WebSocketManager.gd`

### Key Events
- `match_found` → Navigate to GameBoard
- `match_updated` → `MatchManager.match_state_updated.emit(data)`
- `card_played` → Update game state
- `turn_changed` → Audio + UI feedback
- `chat_message` → Display in chat

**Match State Payload**:
```json
{
  "id": "uuid",
  "current_turn": 3,
  "current_player": 1,
  "player1_life": 12,
  "player1_cosmos": 5,
  "player1_hand_count": 4,
  "player1_deck_size": 35,
  "player2_hand_count": 3,
  "player2_deck_size": 32,
  "cards_in_play": [
    {
      "instance_id": "uuid",
      "card_id": "uuid",
      "player_number": 1,
      "zone": "field_knight",
      "position": 0,
      "mode": "normal",
      "is_exhausted": false,
      ...
    }
  ]
}
```

---

## Scene Structure (GameBoard.tscn)

### Layout
```
GameBoard (Control)
└── MainContainer (HBoxContainer)
    ├── LeftColumn (VBoxContainer)
    │   ├── OpponentDeck/DeckPile (DeckDisplay)
    │   └── PlayerDeck/DeckPile (DeckDisplay)
    ├── CenterColumn (VBoxContainer)
    │   ├── OpponentArea
    │   │   ├── OpponentHeader
    │   │   │   ├── OpponentAvatar
    │   │   │   └── OpponentHand (HandLayout)
    │   │   ├── KnightsRow (5 slots)
    │   │   └── TechRow (5 slots + helper/occasion)
    │   └── PlayerArea
    │       ├── KnightsRow (5 slots)
    │       ├── TechRow (5 slots + helper/occasion)
    │       └── PlayerHeader
    │           ├── PlayerAvatar
    │           └── PlayerHand (HandLayout)
    └── RightColumn
        ├── OpponentPiles (Yomotsu/Cositos)
        ├── ScenarioSlot
        └── PlayerPiles (Yomotsu/Cositos)
```

### Mouse Filter Chain
- **GameBoard**: `MOUSE_FILTER_IGNORE` (passes to children)
- **PlayerHand/OpponentHand**: `MOUSE_FILTER_PASS` (passes to cards)
- **CardDisplay**: `MOUSE_FILTER_STOP` (captures events)

---

## Development Patterns

### Mouse Events
HandLayout connects to card signals:
```gdscript
card_display.mouse_entered.connect(hover_card.bind(card_display))
card_display.mouse_exited.connect(unhover_card.bind(card_display))
card_display.drag_started.connect(notify_drag_start.bind(card_display))
card_display.drag_ended.connect(notify_drag_end.bind(card_display))
```

### Card Images
Cards load images async via `CardsManager`:
```gdscript
# CardDisplay checks cache
if CardsManager._image_cache.has(card_id):
    card_display.set_card_image(CardsManager._image_cache[card_id])
else:
    CardsManager.fetch_card_image(card_id, image_url)
    # CardsManager emits card_image_loaded when ready
```

### CardBack Global Cache
**File**: `scripts/cards/CardBack.gd`

All CardBack instances share a single texture:
```gdscript
static var cached_back_texture: Texture2D = null
static var is_loading: bool = false
static var pending_cards: Array[CardBack] = []
```

Only one HTTP request to `/assets/cards/card_back.png` for all instances.

---

## Localization (i18n)

**File**: `scripts/managers/LocalizationManager.gd`

### Supported Languages
- Spanish (es) - Default
- English (en)
- Portuguese (pt)

### Translation Files
- `assets/translations/es.json`
- `assets/translations/en.json`
- `assets/translations/pt.json`

### Usage
```gdscript
# Get translated text
var text = LocalizationManager.tr("ui.start_game")

# Get translated card name
var name = LocalizationManager.get_card_name(card_data)

# Translate card type/rarity (internal "knight" → "Caballero")
var type_text = LocalizationManager.translate_card_type("knight")
var rarity_text = LocalizationManager.translate_rarity("legendary")
```

### Card Translation
Cards store English values internally:
```json
// Backend sends:
{ "type": "knight", "rarity": "legendary" }

// LocalizationManager translates:
"knight" → "Caballero" (es) / "Knight" (en) / "Cavaleiro" (pt)
"legendary" → "Legendaria" (es) / "Legendary" (en) / "Lendária" (pt)
```

---

## Common Tasks

### Adding a New Card Collection Type
1. Create new class extending `CardCollection` in `scripts/models/`
2. Override `_update_layout()` to implement positioning logic
3. Add signals/methods as needed
4. Use in scene via script assignment

Example:
```gdscript
# scripts/models/DiscardPile.gd
extends CardCollection
class_name DiscardPile

func _update_layout() -> void:
    # Stack cards vertically with slight rotation
    for i in range(_cards.size()):
        var card = _cards[i]
        card.position = Vector2(i * 2, i * 2)
        card.rotation_degrees = randf_range(-5, 5)
    super._update_layout()  # Emit signal
```

### Updating Match State from WebSocket
Already handled by `MatchManager`:
```gdscript
# In WebSocketManager
func _on_match_updated(data: Dictionary):
    MatchManager._set_current_match(data)
    MatchManager.match_state_updated.emit(data)

# GameBoard listens
MatchManager.match_state_updated.connect(_on_match_updated)
```

### Playing a Card from Hand
```gdscript
# GameBoard.gd
func _on_card_placed_in_slot(slot: CardSlot, card: Control):
    var card_instance: CardInstance = card.get_meta("card_instance")
    var slot_type = slot.slot_type  # 0=knight, 1=technique, etc.
    
    # Send to backend
    MatchManager.play_card_to_field(
        card_instance.instance_id,
        get_zone_from_slot_type(slot_type),
        slot.slot_index
    )
    
    # Remove from hand (will be re-rendered on match_updated)
    player_hand.remove_card(card)
```

---

## Testing Checklist

### CardCollection Architecture
- [ ] HandLayout arranges cards horizontally
- [ ] Hover effects work on individual cards
- [ ] Drag and drop from hand to field
- [ ] DeckDisplay shows stack + counter
- [ ] Opponent hand shows correct number of card backs
- [ ] clear_cards() properly frees memory

### Match Flow
- [ ] Match search → WebSocket → match_found event
- [ ] GameBoard loads with correct player_number
- [ ] Hands render correctly (player = cards, opponent = backs)
- [ ] Decks show correct counts
- [ ] Playing a card updates state via WebSocket
- [ ] Turn changes trigger audio/visual feedback

### Localization
- [ ] Language selector works
- [ ] Card names translate correctly
- [ ] UI elements translate (buttons, labels)
- [ ] Language persists across scenes

---

## Known Issues & Limitations

1. **No Animations**: Card movements are instant (no tween/animation yet)
2. **No Drag Preview**: Dragging cards doesn't show ghost/preview
3. **Yomotsu/Cositos**: Still use Label counters (not DeckDisplay)
4. **No Card Hover Info**: Hovering opponent cards doesn't show details
5. **Chat Scroll**: Manual scroll required (no auto-scroll to bottom)

---

## File Organization

```
ccg/
├── scenes/
│   ├── game/
│   │   ├── GameBoard.tscn       # Main game scene
│   │   └── GameBoard.gd         # Game controller (755 lines)
│   ├── ui/
│   │   ├── CardDisplay.tscn     # Card visual (120x168)
│   │   ├── CardBack.tscn        # Card back (80x120)
│   │   ├── DeckBuilder.tscn     # Deck editor
│   │   └── ...
│   └── menus/
│       ├── LoginScreen.tscn
│       └── MatchSearch.tscn
├── scripts/
│   ├── cards/
│   │   ├── CardData.gd
│   │   ├── CardDisplay.gd
│   │   └── CardBack.gd
│   ├── models/
│   │   ├── CardCollection.gd    # Base class
│   │   ├── CardInstance.gd
│   │   ├── GameState.gd
│   │   └── DeckDisplay.gd
│   ├── game/
│   │   ├── HandLayout.gd
│   │   ├── CardSlot.gd
│   │   └── MatchEffectsManager.gd
│   ├── managers/
│   │   ├── NetworkManager.gd
│   │   ├── WebSocketManager.gd
│   │   ├── CardsManager.gd
│   │   ├── MatchManager.gd
│   │   ├── LocalizationManager.gd
│   │   └── AudioManager.gd
│   └── utils/
│       └── GameConfig.gd
└── assets/
    ├── fonts/
    ├── images/
    ├── sounds/
    └── translations/
```

---

## Recent Changes (December 2025)

### CardCollection Architecture (v1.0)
- ✅ Created `CardCollection` base class (template method pattern)
- ✅ Refactored `HandLayout` to extend `CardCollection`
- ✅ Created `DeckDisplay` for deck stacks
- ✅ Integrated `DeckDisplay` into `PlayerDeck` and `OpponentDeck`
- ✅ Implemented opponent hand with card backs via `HandLayout`
- ✅ Updated `GameBoard` to use `clear_cards()` and `add_card()` API

### Documentation
- ✅ `docs/CARD-COLLECTIONS-ARCHITECTURE.md` - Architecture guide
- ✅ `docs/DECK-AND-OPPONENT-HAND-VISUAL-CHANGES.md` - Implementation details
- ✅ `docs/LANGUAGE-PERSISTENCE-EXPLAINED.md` - i18n persistence
- ✅ `docs/MATCH-VALIDATION.md` - Match system validation

---

## Next Steps

1. **Animations**: Add tweens for card draw/play/discard
2. **Yomotsu/Cositos**: Convert to `DeckDisplay` or `DiscardPile` class
3. **Drag Preview**: Show ghost card while dragging
4. **Battle Animations**: Combat effects via `CombatAnimator`
5. **Sound Effects**: Card play, draw, attack sounds
6. **Card Details Popup**: Click opponent field cards to see details

---

**Last Updated**: December 1, 2025
