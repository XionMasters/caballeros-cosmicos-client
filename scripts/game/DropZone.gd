## DropZone - Interactive drop zone system with sensor partitioning
## Provides drag-and-drop target detection with configurable sensor areas
extends Control
class_name DropZone

# Signals
@warning_ignore("unused_signal")
signal card_drop_attempted(card: CardDisplay, position: Vector2)
@warning_ignore("unused_signal")
signal card_drop_valid(card: CardDisplay, partition_index: int)

# Sensor properties
var sensor_size: Vector2:
	set(value):
		sensor.size = value
		sensor_outline.size = value

var sensor_position: Vector2:
	set(value):
		sensor.position = value
		sensor_outline.position = value

var sensor_outline_visible: bool:
	set(value):
		sensor_outline.visible = value

# Configuration
var accept_types: Array = ["card"]
var parent_container: Node = null

# UI components
var sensor: Control = null
var sensor_outline: ReferenceRect = null

# Partitioning system
var vertical_partitions: Array = []  # For left-right ordering
var horizontal_partitions: Array = []  # For up-down layering
var partition_outlines: Array = []

# Stored values for restoration
var stored_sensor_size: Vector2 = Vector2.ZERO
var stored_sensor_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Create invisible sensor
	if sensor == null:
		sensor = Control.new()
		sensor.name = "Sensor"
		sensor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sensor.z_index = -100
		add_child(sensor)
	
	# Create debug outline
	if sensor_outline == null:
		sensor_outline = ReferenceRect.new()
		sensor_outline.name = "SensorOutline"
		sensor_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sensor_outline.border_color = Color.YELLOW
		sensor_outline.z_index = -99
		add_child(sensor_outline)
	
	print("[DBG] DropZone initialized")


## Initialize drop zone with parent and accepted types
func init(parent: Node, accept_types_array: Array = ["card"]) -> void:
	parent_container = parent
	accept_types = accept_types_array


## Configure sensor with size and position
func set_sensor(newsize: Vector2, newposition: Vector2, texture: Texture = null, _visible: bool = false) -> void:
	sensor_size = newsize
	sensor_position = newposition
	stored_sensor_size = newsize
	stored_sensor_position = newposition
	
	if texture:
		sensor.texture = texture
	
	sensor_outline.visible = visible


## Adjust sensor size temporarily
func set_sensor_size_flexibly(newsize: Vector2, newposition: Vector2) -> void:
	sensor_size = newsize
	sensor_position = newposition


## Check if mouse is inside drop zone
func check_mouse_is_in_drop_zone() -> bool:
	var mouse_pos = get_global_mouse_position()
	return sensor.get_global_rect().has_point(mouse_pos)


## Set vertical partitions for card ordering
func set_vertical_partitions(partitions: Array) -> void:
	vertical_partitions = partitions
	_draw_partition_outlines()


## Set horizontal partitions for layering
func set_horizontal_partitions(partitions: Array) -> void:
	horizontal_partitions = partitions
	_draw_partition_outlines()


## Get partition index for mouse position
func get_partition_index_from_mouse() -> int:
	var mouse_pos = get_global_mouse_position()
	var sensor_rect = sensor.get_global_rect()
	
	if not sensor_rect.has_point(mouse_pos):
		return -1
	
	# Calculate position within sensor (0.0 to 1.0)
	var local_x = (mouse_pos.x - sensor_rect.position.x) / sensor_rect.size.x
	
	# Find partition
	for i in range(vertical_partitions.size()):
		if local_x < vertical_partitions[i]:
			return i
	
	return vertical_partitions.size() - 1


## Draw partition outlines for debugging
func _draw_partition_outlines() -> void:
	# Clear existing outlines
	for outline in partition_outlines:
		outline.queue_free()
	partition_outlines.clear()
	
	if not sensor_outline_visible:
		return
	
	# Draw vertical partition lines
	for partition_x in vertical_partitions:
		var line = Line2D.new()
		line.name = "PartitionLine"
		line.add_point(Vector2(partition_x, 0))
		line.add_point(Vector2(partition_x, sensor_size.y))
		line.default_color = Color.RED
		line.width = 1.0
		line.z_index = -98
		add_child(line)
		partition_outlines.append(line)


## Restore original sensor size and position
func restore_sensor() -> void:
	sensor_size = stored_sensor_size
	sensor_position = stored_sensor_position


## Visibility toggle for sensor outline
func toggle_sensor_visibility() -> void:
	sensor_outline.visible = not sensor_outline.visible


## Clean up on exit
func _exit_tree() -> void:
	for outline in partition_outlines:
		if is_instance_valid(outline):
			outline.queue_free()
