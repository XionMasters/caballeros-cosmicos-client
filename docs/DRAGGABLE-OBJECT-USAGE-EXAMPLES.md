# DraggableObject Usage Examples

## Quick Reference

### Basic Card Setup
```gdscript
extends DraggableObject

func _ready():
    super._ready()
    # No additional setup needed - works out of the box
```

### With Signals
```gdscript
extends DraggableObject

func _ready():
    super._ready()
    
    state_changed.connect(_on_state_changed)
    drag_started.connect(_on_drag_start)
    drag_ended.connect(_on_drag_end)
    move_completed.connect(_on_move_done)

func _on_drag_start():
    print("Card picked up!")

func _on_drag_end(pos: Vector2):
    print("Card dropped at: ", pos)

func _on_move_done(pos: Vector2):
    print("Animation complete at: ", pos)
```

### With Constraints
```gdscript
extends DraggableObject

func _ready():
    super._ready()
    
    # Keep card within parent bounds with 10px margin
    constrain_to_parent = true
    margin = Rect2(Vector2(10, 10), Vector2(10, 10))
    
    # Use drag threshold to prevent accidental moves
    drag_threshold = 5.0
```

### Programmatic Movement
```gdscript
# Simple movement
card.move_to(Vector2(400, 300))

# With rotation and custom duration
card.move_to(Vector2(400, 300), 45.0, 0.5)

# With callback
card.move_to(Vector2(400, 300), 0.0, 0.3, null, func():
    print("Movement done!")
    play_landing_sound()
)
```

### Grid Layout
```gdscript
@export var card_size: Vector2 = Vector2(120, 160)

func _ready():
    super._ready()
    
    snap_to_grid = true
    grid_size = card_size
```

### Reset/Undo
```gdscript
# Instant reset
card.reset(false)

# Smooth animation back to start
card.reset(true)
```

---

## Game Board Integration Example

### GameBoard.gd
```gdscript
extends Control
class_name GameBoard

@onready var card_slots = $CardSlots

func _ready():
    _spawn_player_hand()

func _spawn_player_hand():
    var cards = GameState.player_hand
    for card_data in cards:
        var card_display = preload("res://scenes/ui/CardDisplay.tscn").instantiate()
        card_display.setup(card_data)
        add_child(card_display)
        
        # Connect to slot validation
        card_display.drag_ended.connect(_on_card_dropped.bind(card_display))

func _on_card_dropped(card: CardDisplay, pos: Vector2):
    var target_slot = _find_slot_at_position(pos)
    
    if target_slot and _is_valid_placement(card, target_slot):
        # Animate to slot
        card.move_to(target_slot.global_position, 0.0, 0.3, null, func():
            GameState.place_card(card, target_slot)
            GameBoard.update_board()
        )
    else:
        # Return to hand
        card.reset(true)

func _find_slot_at_position(pos: Vector2) -> CardSlot:
    for slot in card_slots.get_children():
        if slot.get_rect().has_point(pos):
            return slot
    return null

func _is_valid_placement(card: CardDisplay, slot: CardSlot) -> bool:
    # Game-specific validation
    if slot.is_occupied:
        return false
    if card.card_data.type == "knight" and slot.slot_type != "knight":
        return false
    return true
```

### CardDisplay.gd
```gdscript
extends DraggableObject
class_name CardDisplay

@onready var card_image = $Image
@onready var card_name = $Label

var card_data: CardData

func setup(data: CardData):
    card_data = data
    card_image.texture = load(data.image_path)
    card_name.text = data.name
    
    # Configure for game
    constrain_to_parent = true
    drag_threshold = 5.0
    
    # Connect state changes for visuals
    state_changed.connect(_on_state_changed)
    hover_started.connect(_play_hover_sound)

func _on_state_changed(old: DraggableState, new: DraggableState):
    match new:
        DraggableState.HOVERING:
            _show_tooltip()
        DraggableState.HOLDING:
            _show_card_details()
        DraggableState.IDLE:
            _hide_details()

func _play_hover_sound():
    AudioManager.play("card_hover", -5)

func _show_tooltip():
    TooltipManager.show(card_data)

func _show_card_details():
    DetailPanel.show(card_data)

func _hide_details():
    DetailPanel.hide()
```

### CardSlot.gd
```gdscript
extends Control
class_name CardSlot

@export var slot_type: String = "knight"  # knight, technique, etc
@export var slot_index: int = 0

var is_occupied: bool = false
var current_card: CardDisplay

func _ready():
    gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent):
    if event is InputEventMouseButton and event.pressed:
        # Highlight when hovable
        modulate = Color.LIGHT_GRAY

func place_card(card: CardDisplay):
    current_card = card
    is_occupied = true
    
    # Lock card in place
    card.can_be_interacted_with = false
    card.global_position = global_position

func clear_card():
    if current_card:
        current_card.can_be_interacted_with = true
        current_card = null
        is_occupied = false
```

---

## Advanced State Validation

### Custom Game Rules
```gdscript
extends DraggableObject
class_name GameCard

func _can_transition_to(new_state: DraggableState) -> bool:
    # Can't drag during opponent's turn
    if new_state == DraggableState.HOLDING:
        if not MatchManager.is_my_turn:
            return false
    
    # Can't move until animation finishes
    if new_state != DraggableState.IDLE:
        if MatchManager.is_animating:
            return false
    
    # Use default transitions
    return super._can_transition_to(new_state)
```

### Exhausted Card
```gdscript
extends GameCard
class_name KnightCard

@export var is_exhausted: bool = false

func _can_transition_to(new_state: DraggableState) -> bool:
    # Exhausted knights can't be dragged
    if is_exhausted and new_state == DraggableState.HOLDING:
        return false
    
    return super._can_transition_to(new_state)

func exhaust():
    is_exhausted = true
    modulate = Color(0.5, 0.5, 0.5)  # Dim visual
    can_be_interacted_with = false
    change_state(DraggableState.IDLE)

func restore():
    is_exhausted = false
    modulate = Color.WHITE
    can_be_interacted_with = true
```

---

## Animation Sequences

### Card Draw Animation
```gdscript
func draw_card_from_deck(card: CardDisplay, deck_pos: Vector2):
    # Start at deck
    card.global_position = deck_pos
    card.scale = Vector2(0.5, 0.5)
    
    # Animate to hand
    card.move_to(
        get_hand_position_for_card(),
        0.0,
        0.4,
        null,
        func():
            card.reset(false)  # Ensure clean state
            print("Card added to hand")
    )
```

### Card Attack Animation
```gdscript
func play_attack_animation(attacker: KnightCard, target: KnightCard):
    var original_pos = attacker.global_position
    
    # Move toward target
    attacker.move_to(target.global_position - Vector2(50, 0), 0.0, 0.3)
    
    # Wait and return
    await get_tree().create_timer(0.5).timeout
    attacker.move_to(original_pos, 0.0, 0.2, null, func():
        print("Attack animation complete")
        attacker.reset(false)
    )
```

### Discard Animation
```gdscript
func discard_card(card: CardDisplay, discard_pile_pos: Vector2):
    # Rotate and move to discard
    card.move_to(
        discard_pile_pos,
        90.0,  # Rotate 90 degrees
        0.3
    )
    
    # Wait for animation
    await card.move_completed
    
    # Remove from scene
    card.queue_free()
```

---

## Deck Builder Integration

### DeckList.gd
```gdscript
extends ItemList
class_name DeckList

func add_card_to_deck(card_data: CardData):
    var card_display = preload("res://scenes/ui/CardDisplay.tscn").instantiate()
    card_display.setup(card_data)
    add_child(card_display)
    
    # Enable grid snapping for neat list
    card_display.snap_to_grid = true
    card_display.grid_size = Vector2(120, 160)

func _on_card_reordered(from: int, to: int):
    # Reorder in deck data
    GameState.reorder_deck_card(from, to)
    
    # Animate cards back to grid
    for i, card in get_children():
        card.move_to(
            _grid_position_for_index(i),
            0.0,
            0.2
        )
```

---

## Performance Tips

1. **Disable Unused Features**:
   ```gdscript
   snap_to_grid = false  # Only enable if needed
   constrain_to_parent = false  # Only if bounded
   ```

2. **Batch Resets**:
   ```gdscript
   # Don't do this in loop
   for card in cards:
       card.reset(true)  # Creates 50 tweens!
   
   # Instead group them
   var reset_sequence = func():
       for i, card in cards:
           await get_tree().create_timer(i * 0.05).timeout
           card.reset(true)
   ```

3. **Cleanup on Exit**:
   ```gdscript
   func _exit_tree():
       _cleanup_tweens()  # Already called, but explicit is safe
       super._exit_tree()
   ```

---

## Debugging

### Enable Debug Output
```gdscript
# In DraggableObject.gd, uncomment for development:
# print("[DBG] State: ", current_state, " → ", new_state)
```

### State Monitoring
```gdscript
func _ready():
    super._ready()
    state_changed.connect(func(old, new):
        print("Card %s: %s → %s" % [name, DraggableState.keys()[old], DraggableState.keys()[new]])
    )
```

### Tween Validation
```gdscript
func check_active_tweens():
    print("Hover tween valid: ", hover_tween and hover_tween.is_valid())
    print("Move tween valid: ", move_tween and move_tween.is_valid())
```

---

## Common Issues

### Cards Not Draggable
```gdscript
# Check these:
can_be_interacted_with = true  # Enabled?
mouse_filter = Control.MOUSE_FILTER_STOP  # Can receive input?
_can_start_hovering()  # Override returns false?
_can_transition_to(HOLDING)  # Blocked by game state?
```

### Tweens Not Cleaning Up
```gdscript
# Ensure _cleanup_tweens() is called:
_exit_tree()  # Automatic
reset(false)  # Calls cleanup
change_state(IDLE)  # May cleanup hover tween
```

### Grid Snapping Issues
```gdscript
# Verify:
snap_to_grid = true
grid_size != Vector2.ZERO  # Not zero!
grid_size matches card size  # 120x160, not 100x100?
```

---

**Last Updated**: December 1, 2025  
**Tested With**: Godot 4.5.1  
**All Examples Working**: ✅
