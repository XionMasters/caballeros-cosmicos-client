# Card Animation System - Caballeros Cósmicos

## Overview

Implemented a comprehensive card animation system for smooth transitions when cards move between game zones (deck → hand, hand → field, field → graveyard, etc.).

## Components

### 1. CardDisplay.gd - Three New Animation Methods

#### `animate_from_position(start_global_pos: Vector2, duration: float = 0.4)`
**Purpose**: Animate card movement from a source position to its current position.

**Features**:
- Starts from `start_global_pos` (e.g., deck pile location)
- Animates to the card's current position (set by HandLayout)
- Fade-in effect: `modulate.a` from 0.3 → 1.0
- Random rotation: -0.3 to +0.3 radians (slight tilt)
- Scale animation: 0.85 → 1.0 (grows slightly)
- Duration: configurable (default 0.4 seconds)
- Tween settings: TRANS_QUAD + EASE_OUT (smooth, natural motion)

**Usage Example**:
```gdscript
var deck_position = player_deck.global_position
card_display.animate_from_position(deck_position, 0.4)
```

**Log Output**:
```
[CardDisplay] Animation started: Seya (Knight) from Vector2(120, 400) to Vector2(400, 550)
```

---

#### `animate_to_position(target_global_pos: Vector2, duration: float = 0.4)`
**Purpose**: Animate card movement to a target position.

**Features**:
- Animates position to `target_global_pos`
- Fade-out effect: `modulate.a` from 1.0 → 0.7
- Random rotation: -0.2 to +0.2 radians
- Tween settings: TRANS_QUAD + EASE_IN (decelerating motion)
- Used for: card→discard, card→field, card→exchange zone

**Usage Example**:
```gdscript
var graveyard_position = player_graveyard.global_position
card_display.animate_to_position(graveyard_position, 0.3)
```

---

#### `animate_spawn(duration: float = 0.3)`
**Purpose**: Play spawn animation for newly created cards (draw, generate, etc.).

**Features**:
- Starts transparent and small: `modulate.a = 0.0`, `scale = 0.5`
- Grows and fades in: to `scale = 1.0` and `modulate.a = 1.0`
- Tween settings: TRANS_BACK + EASE_OUT (bouncy, energetic)
- Duration: default 0.3 seconds (quick pop-in effect)

**Usage Example**:
```gdscript
card_display.animate_spawn(0.3)
```

---

### 2. TestBoard.gd - Updated `_add_card_to_hand()`

**Changes**:
1. Captures deck position: `player_deck.global_position`
2. Adds card to HandLayout via `player_hand.add_card(card_display)`
3. Waits one frame for HandLayout to calculate card position
4. Triggers animation: `card_display.animate_from_position(deck_global_pos, 0.4)`

**Code Flow**:
```gdscript
func _add_card_to_hand(card_instance: CardInstance) -> void:
    var card_display = CARD_DISPLAY_SCENE.instantiate()
    # ... setup card_display ...
    
    player_hand.add_card(card_display)  # Calculates position
    
    await get_tree().process_frame     # Wait for layout to finish
    
    # Animate from deck to hand
    card_display.animate_from_position(player_deck.global_position, 0.4)
```

**Visual Result**:
- Card appears at deck pile position
- Smoothly translates to final position in hand
- Rotates slightly during movement
- Fades in from 30% to 100% opacity

---

## Animation Timings

| Animation | Duration | Easing | Use Case |
|-----------|----------|--------|----------|
| `animate_from_position` | 0.4s | QUAD/OUT | Deck → Hand |
| `animate_to_position` | 0.4s | QUAD/IN | Hand → Discard |
| `animate_spawn` | 0.3s | BACK/OUT | New card creation |

---

## Tween Management

All animation methods properly manage tweens to prevent conflicts:

```gdscript
if move_tween and move_tween.is_valid():
    move_tween.kill()  # Stop previous animation

move_tween = create_tween()
move_tween.set_parallel(true)
move_tween.set_trans(Tween.TRANS_QUAD)
move_tween.set_ease(Tween.EASE_OUT)
# ... tween properties ...
```

**Cleanup**: `_notification(NOTIFICATION_PREDELETE)` kills all tweens when card is freed.

---

## Integration Points

### Current Implementation
- ✅ Deck → Hand animation (`_add_card_to_hand`)
- ✅ Methods ready for: Hand → Field, Hand → Discard, Field → Graveyard

### Future Integrations
- [ ] `_on_card_placed_in_slot()` → Use `animate_to_position()` to field
- [ ] Discard operations → Use `animate_to_position()` to graveyard
- [ ] Battle effects → Use `animate_spawn()` + `animate_to_position()` for damage/healing
- [ ] Multiple card movements → Chain animations with `await` 

---

## Testing

### Visual Validation
1. Load TestBoard
2. Observe cards animating from deck pile into hand
3. Check:
   - Cards start at deck position ✓
   - Smooth movement to hand ✓
   - Rotation is subtle (not jarring) ✓
   - Fade-in effect visible ✓
   - Final position matches hand layout ✓

### Debug Output
```
[CardDisplay] Animation started: Seya (Knight) from Vector2(120, 400) to Vector2(400, 550)
[CardDisplay] Animation started: Shun (Knight) from Vector2(120, 400) to Vector2(450, 550)
```

---

## Performance Notes

- **Tweens are parallel** (`set_parallel(true)`) - position, opacity, rotation all animate simultaneously
- **No frame skipping** - animations use `create_tween()` (not custom loop)
- **Memory efficient** - tweens are killed on card deletion
- **No garbage collection pauses** - small number of simultaneous tweens (~5-7 when drawing)

---

## Known Limitations

1. **No drag animation during holding** - Card moves instantly while being dragged (can be added)
2. **No return animation if drop rejected** - Card stays where dropped (feature request)
3. **No sound effects** - Animation is visual only (would need AudioManager)

---

**Last Updated**: December 15, 2025
**Status**: ✅ Complete and tested
