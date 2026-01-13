## DraggableObject.gd
## Base class for draggable objects with state machine and animation system.
##
## Provides robust drag-and-drop behavior with state management, smooth animations,
## and extensible design for card-based games.
##
## State Machine:
## - IDLE: Default state, ready for interaction
## - HOVERING: Mouse over with visual feedback (scale, rotation, position)
## - HOLDING: Active drag state following mouse movement
## - MOVING: Programmatic movement ignoring user input
##
extends Control
class_name DraggableObject

# State enumeration
enum DraggableState {
	IDLE,
	HOVERING,
	HOLDING,
	MOVING
}

# ============================================================================
# SIGNALS
# ============================================================================
signal state_changed(old_state: DraggableState, new_state: DraggableState)
signal drag_started()
signal drag_ended(position: Vector2)
signal hover_started()
signal hover_ended()
signal move_started(destination: Vector2, duration: float)
signal move_completed(destination: Vector2)

# Configuration exports
@export var moving_speed: int = 300
@export var can_be_interacted_with: bool = true
@export var hover_distance: int = 30
@export var hover_scale: float = 1.1
@export var hover_rotation: float = 0.0
@export var hover_duration: float = 0.2

# Z-index management
@export var hover_z_index_offset: int = 10
@export var holding_z_index_offset: int = 20
@export var moving_z_index_offset: int = 15

# Drag threshold (píxeles necesarios para activar drag)
@export var drag_threshold: float = 5.0

# Constraints and grid
@export var constrain_to_parent: bool = false
@export var margin: Rect2 = Rect2(0, 0, 0, 0)
@export var snap_to_grid: bool = false
@export var grid_size: Vector2 = Vector2(100, 100)

# State machine
var current_state: DraggableState = DraggableState.IDLE

# Mouse tracking
var is_mouse_inside: bool = false
var current_holding_mouse_position: Vector2

# Drag threshold tracking
var _initial_mouse_pos: Vector2 = Vector2.ZERO
var _initial_position: Vector2 = Vector2.ZERO
var _has_moved_threshold: bool = false

# Position and animation tracking
var original_position: Vector2
var original_scale: Vector2
var original_rotation: float
var current_hover_position: Vector2

# Movement state
var is_moving_to_destination: bool = false
var is_returning_to_original: bool = false
var target_destination: Vector2
var target_rotation: float
var original_destination: Vector2
var original_z: int

# Tween objects
var move_tween: Tween
var hover_tween: Tween

# State transition validation
var allowed_transitions = {
	DraggableState.IDLE: [DraggableState.HOVERING, DraggableState.HOLDING, DraggableState.MOVING],
	DraggableState.HOVERING: [DraggableState.IDLE, DraggableState.HOLDING, DraggableState.MOVING],
	DraggableState.HOLDING: [DraggableState.IDLE, DraggableState.MOVING],
	DraggableState.MOVING: [DraggableState.IDLE]
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Connect signals
	mouse_entered.connect(_on_mouse_enter)
	mouse_exited.connect(_on_mouse_exit)
	gui_input.connect(_on_gui_input)
	
	# Store original state
	original_position = position
	original_scale = scale
	original_rotation = rotation
	original_destination = global_position
	original_z = z_index


## Safely transition between states with validation
func change_state(new_state: DraggableState) -> bool:
	if new_state == current_state:
		return true
	
	# Use new method-based validation instead of static dict
	if not _can_transition_to(new_state):
		print("[DBG] Invalid transition: ", current_state, " → ", new_state)
		return false
	
	# Exit previous state
	_exit_state(current_state)
	
	var old_state = current_state
	current_state = new_state
	
	# Emit state changed signal
	state_changed.emit(old_state, new_state)
	
	# Enter new state
	_enter_state(new_state, old_state)
	
	return true


## Validate if transition is allowed (override in subclasses for custom logic)
func _can_transition_to(new_state: DraggableState) -> bool:
	# Define allowed transitions
	var allowed = {
		DraggableState.IDLE: [DraggableState.HOVERING, DraggableState.HOLDING, DraggableState.MOVING],
		DraggableState.HOVERING: [DraggableState.IDLE, DraggableState.HOLDING, DraggableState.MOVING],
		DraggableState.HOLDING: [DraggableState.IDLE, DraggableState.MOVING],
		DraggableState.MOVING: [DraggableState.IDLE]
	}
	
	return new_state in allowed[current_state]


## Handle state entry logic
func _enter_state(state: DraggableState, from_state: DraggableState) -> void:
	match state:
		DraggableState.IDLE:
			z_index = original_z
			mouse_filter = Control.MOUSE_FILTER_STOP
			
		DraggableState.HOVERING:
			z_index = original_z + hover_z_index_offset
			_start_hover_animation()
			hover_started.emit()
			
		DraggableState.HOLDING:
			# Preserve hover position if coming from HOVERING
			if from_state == DraggableState.HOVERING:
				_preserve_hover_position()
			
			current_holding_mouse_position = get_local_mouse_position()
			z_index = original_z + holding_z_index_offset
			rotation = 0
			drag_started.emit()
			
		DraggableState.MOVING:
			# Stop hover animations
			_cleanup_tweens()
			z_index = original_z + moving_z_index_offset
			mouse_filter = Control.MOUSE_FILTER_IGNORE
			move_started.emit(target_destination, hover_duration)


## Handle state exit logic
func _exit_state(state: DraggableState) -> void:
	match state:
		DraggableState.HOVERING:
			z_index = original_z
			_stop_hover_animation()
			hover_ended.emit()
			
		DraggableState.HOLDING:
			z_index = original_z
			scale = original_scale
			rotation = original_rotation
			drag_ended.emit(global_position)
			
		DraggableState.MOVING:
			mouse_filter = Control.MOUSE_FILTER_STOP


## Process frame - handle HOLDING state mouse tracking with drag threshold
func _process(_delta: float) -> void:
	if current_state == DraggableState.HOLDING:
		var new_position = get_global_mouse_position() - current_holding_mouse_position
		
		# Apply constraints
		new_position = _apply_constraints(new_position)
		
		# Apply grid snapping if enabled
		if snap_to_grid:
			new_position = _snap_to_grid(new_position)
		
		global_position = new_position


## Handle mouse input events
func _on_gui_input(event: InputEvent) -> void:
	if not can_be_interacted_with:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_handle_mouse_pressed()
		else:
			_handle_mouse_released()


## Handle mouse press event with drag threshold
func _handle_mouse_pressed() -> void:
	if current_state == DraggableState.HOVERING or current_state == DraggableState.IDLE:
		_initial_mouse_pos = get_global_mouse_position()
		_initial_position = global_position
		_has_moved_threshold = false
		change_state(DraggableState.HOLDING)


## Handle mouse release event
func _handle_mouse_released() -> void:
	if current_state == DraggableState.HOLDING:
		change_state(DraggableState.IDLE)
		_has_moved_threshold = false


## Handle mouse enter
func _on_mouse_enter() -> void:
	is_mouse_inside = true
	
	if current_state == DraggableState.IDLE and _can_start_hovering():
		change_state(DraggableState.HOVERING)


## Handle mouse exit
func _on_mouse_exit() -> void:
	is_mouse_inside = false
	
	if current_state == DraggableState.HOVERING:
		change_state(DraggableState.IDLE)


## Override this to implement custom hover validation
func _can_start_hovering() -> bool:
	return true


## Start hover animation with tween
func _start_hover_animation() -> void:
	# Kill existing tween
	if hover_tween and hover_tween.is_valid():
		hover_tween.kill()
	
	# Reset to original before animating
	position = original_position
	scale = original_scale
	rotation = original_rotation
	
	# Create new tween with parallel animations
	hover_tween = create_tween()
	hover_tween.set_parallel(true)
	
	# Animate position (hover up)
	var target_position = Vector2(position.x, position.y - hover_distance)
	hover_tween.tween_property(self, "position", target_position, hover_duration)
	
	# Animate scale
	hover_tween.tween_property(self, "scale", original_scale * hover_scale, hover_duration)
	
	# Animate rotation if set
	if hover_rotation != 0:
		hover_tween.tween_property(self, "rotation", deg_to_rad(hover_rotation), hover_duration)


## Stop hover animation
func _stop_hover_animation() -> void:
	if hover_tween and hover_tween.is_valid():
		hover_tween.kill()
		hover_tween = null
	
	position = original_position
	scale = original_scale
	rotation = original_rotation


## Preserve hover position when transitioning to HOLDING
func _preserve_hover_position() -> void:
	original_position = position
	original_scale = scale
	original_rotation = rotation


## Programmatically move object to destination with customization
func move_to(destination: Vector2, rotation_deg: float = 0.0, duration: float = -1.0, custom_curve: Curve = null, callback: Callable = Callable()) -> void:
	if is_moving_to_destination:
		return
	
	# Use default duration if not specified
	if duration < 0:
		duration = hover_duration
	
	# Store destination and rotation
	target_destination = destination
	target_rotation = deg_to_rad(rotation_deg)
	original_destination = destination
	
	# Transition to MOVING state
	change_state(DraggableState.MOVING)
	is_moving_to_destination = true
	
	# Create movement tween with optional custom curve
	_cleanup_tweens()
	move_tween = create_tween()
	move_tween.set_trans(Tween.TRANS_CUBIC)
	move_tween.set_ease(Tween.EASE_OUT)
	
	# Apply custom curve if provided
	if custom_curve:
		move_tween.set_trans(Tween.TRANS_CUBIC)
		# Note: Godot 4.x doesn't have direct curve support in tweens
		# Use ease/trans for predefined curves
	
	move_tween.tween_property(self, "global_position", destination, duration)
	
	# Also animate rotation if needed
	if rotation_deg != 0:
		move_tween.set_parallel(true)
		move_tween.tween_property(self, "rotation", target_rotation, duration)
		move_tween.set_parallel(false)
	
	# Execute callback if provided
	if callback.is_valid():
		move_tween.tween_callback(callback)
	
	move_tween.tween_callback(_finish_move)


## Backward compatibility wrapper
func move(destination: Vector2, rotation_deg: float = 0.0) -> void:
	move_to(destination, rotation_deg)


## Complete movement and return to IDLE
func _finish_move() -> void:
	is_moving_to_destination = false
	rotation = target_rotation
	
	change_state(DraggableState.IDLE)
	_on_move_done()


## Override this for move completion logic
func _on_move_done() -> void:
	pass


## Return to original position with smooth animation
func return_to_original() -> void:
	if is_moving_to_destination:
		return
	
	is_returning_to_original = true
	move(original_destination, rad_to_deg(original_rotation))


## Clean up tweens on exit
func _exit_tree() -> void:
	_cleanup_tweens()


## Cleanup all active tweens
func _cleanup_tweens() -> void:
	if hover_tween and hover_tween.is_valid():
		hover_tween.kill()
		hover_tween = null
	
	if move_tween and move_tween.is_valid():
		move_tween.kill()
		move_tween = null


## Apply position constraints (bounding box + margins)
func _apply_constraints(new_position: Vector2) -> Vector2:
	if not constrain_to_parent:
		return new_position
	
	var parent_rect = get_parent().get_rect()
	var this_size = size
	
	# Apply margins
	var min_x = parent_rect.position.x + margin.position.x
	var min_y = parent_rect.position.y + margin.position.y
	var max_x = parent_rect.end.x - this_size.x - margin.size.x
	var max_y = parent_rect.end.y - this_size.y - margin.size.y
	
	new_position.x = clamp(new_position.x, min_x, max_x)
	new_position.y = clamp(new_position.y, min_y, max_y)
	
	return new_position


## Snap position to grid
func _snap_to_grid(position_to_snap: Vector2) -> Vector2:
	if grid_size == Vector2.ZERO:
		return position_to_snap
	
	return (position_to_snap / grid_size).round() * grid_size


## Reset object to initial state (optionally with animation)
func reset(animated: bool = false) -> void:
	if animated:
		# Animate back to original position with tween
		_cleanup_tweens()
		var reset_tween = create_tween()
		reset_tween.set_trans(Tween.TRANS_CUBIC)
		reset_tween.set_ease(Tween.EASE_OUT)
		reset_tween.set_parallel(true)
		reset_tween.tween_property(self, "global_position", original_destination, 0.3)
		reset_tween.tween_property(self, "scale", original_scale, 0.3)
		reset_tween.tween_property(self, "rotation", original_rotation, 0.3)
		reset_tween.set_parallel(false)
		reset_tween.tween_callback(func(): change_state(DraggableState.IDLE))
	else:
		# Instant reset
		global_position = original_destination
		scale = original_scale
		rotation = original_rotation
		change_state(DraggableState.IDLE)
