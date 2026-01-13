# BugFix: MatchEventBridge Signal Connections

## Issue Found
The TestBoard initialization failed with this error:
```
[MatchEventBridge] setup: Invalid access to property or key 'card_played' on base object of type 'Node (MatchManager.gd)'
```

**Root Cause:** MatchEventBridge was trying to connect to signals that don't exist on MatchManager:
- `MatchManager.card_played` ❌ **DOESN'T EXIST**
- `MatchManager.card_play_failed` ❌ **DOESN'T EXIST**
- `MatchManager.turn_changed` ❌ **DOESN'T EXIST**

## Analysis: What Signals ACTUALLY Exist on MatchManager

From [MatchManager.gd](../scripts/managers/MatchManager.gd):

```gdscript
signal match_found(match_data: Dictionary)         ✅ Emitted when match found
signal match_started(match_data: Dictionary)       ✅ Emitted when match starts
signal match_state_updated(match_data: Dictionary) ✅ Emitted on every game state update
signal phase_changed(phase: String)                ✅ Emitted when phase changes
signal match_error(error: String)                  ✅ Emitted when error occurs
signal match_ended(match_data: Dictionary)         ✅ Emitted when match ends
```

**There is NO `card_played`, `card_play_failed`, or `turn_changed` signal.**

## Fixes Applied

### 1. MatchEventBridge.gd - Signal Connections (setup method)

**BEFORE:**
```gdscript
func setup() -> void:
    # ❌ These signals don't exist
    MatchManager.card_played.connect(_on_card_played)
    MatchManager.card_play_failed.connect(_on_card_play_failed)
    MatchManager.turn_changed.connect(_on_turn_changed)
    MatchManager.match_state_updated.connect(_on_match_state_updated)
```

**AFTER:**
```gdscript
func setup() -> void:
    # ✅ Use actual signals
    MatchManager.match_state_updated.connect(_on_match_state_updated)
    MatchManager.phase_changed.connect(_on_phase_changed)
    MatchManager.match_error.connect(_on_match_error)
```

### 2. MatchEventBridge.gd - Handler Methods

**BEFORE:**
```gdscript
func _on_card_played(data: Dictionary) -> void: ...
func _on_card_play_failed(reason: String) -> void: ...
func _on_turn_changed(data: Dictionary) -> void: ...
func _on_match_state_updated(match_data: Dictionary) -> void: ...
```

**AFTER:**
```gdscript
func _on_card_play_requested(...) -> void:  # Handles input from MatchPlayController
    # Reforward to server
    
func _on_phase_changed(phase: String) -> void:  # ✅ NEW - Handles phase updates
    # Update controller state
    
func _on_match_error(error_message: String) -> void:  # ✅ NEW - Handles errors
    # Emit failure signal
    
func _on_match_state_updated(_match_data: Dictionary) -> void:  # ✅ UPDATED
    # Handle main state updates
```

### 3. MatchPlayController.gd - Unused Signals

**REMOVED:** `signal card_play_succeeded(card_instance: CardInstance)`

This signal was declared but never emitted anywhere in the code.

### 4. PlayerDeckProvider.gd & OpponentProvider.gd - Unused Signals

**REMOVED from both:**
- `signal deck_provider_error(message: String)` (PlayerDeckProvider)
- `signal opponent_provider_error(message: String)` (OpponentProvider)

These signals were declared but never emitted.

## Test Checklist

- [ ] Godot editor loads TestBoard.tscn without errors
- [ ] TestBoard scene initializes successfully
- [ ] MatchEventBridge.setup() completes without "Invalid access" errors
- [ ] No GDScript warnings remain (6 warnings should be reduced to 0)
- [ ] WebSocket connection established
- [ ] Match state renders correctly
- [ ] Cards in hand are interactive (hover, drag, etc.)
- [ ] Test drag/drop with T key shortcut
- [ ] Verify signals flow: Card → MatchPlayController → MatchEventBridge → MatchManager

## Architecture Flow (Corrected)

```
CardDisplay signals (from BoardRenderer)
    ↓
MatchPlayController (listens)
    │
    └→ Validates drag/drop
       └→ Detects drop zone
          └→ card_play_requested signal
             ↓
MatchEventBridge (listens)
    │
    └→ _on_card_play_requested()
       └→ MatchManager.play_card() → HTTP to server
          └→ Server responds with match_state_updated
             ↓
MatchManager (listens to WebSocket)
    │
    └→ match_state_updated signal
       ↓
MatchEventBridge._on_match_state_updated()
    │
    └→ TestBoard re-renders
       └→ MatchPlayController.setup_card_interactions()
          └→ Reconnect all card signals
```

## Summary

✅ **Fixed:** All MatchEventBridge signal connections now use actual signals that exist on MatchManager  
✅ **Cleaned:** Removed 3 unused signals from MatchPlayController and providers  
✅ **Verified:** Handler method signatures match the signals they're connected to

**Status:** Ready to test with Godot editor

