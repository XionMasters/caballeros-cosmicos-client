# AvatarDisplay.gd
# Muestra el avatar del jugador con barras circulares de vida y cosmos
extends Control
class_name AvatarDisplay

@onready var name_label = $VBox/NameLabel
@onready var avatar_image = $VBox/AvatarContainer/AvatarCircle/AvatarImage
@onready var health_arc = $VBox/AvatarContainer/AvatarCircle/HealthArc
@onready var cosmos_arc = $VBox/AvatarContainer/AvatarCircle/CosmosArc
@onready var cosmos_particles = $VBox/AvatarContainer/AvatarCircle/CosmosParticles
@onready var turn_dot = $TurnDot

var max_health: int = 12
var current_health: int = 12
var max_cosmos: int = 12
var current_cosmos: int = 0
var turn_dot_tween: Tween = null
var damage_flash_timer := 0.0

const DAMAGE_FLASH_TIME := 0.25
const SEGMENT_GAP := deg_to_rad(10)   # espacio entre segmentos
const SEGMENT_PADDING := deg_to_rad(0)

const ARC_WIDTH = 14.0
const HEALTH_COLOR = Color(1.0, 0.2, 0.2, 1.0)  # Rojo
const COSMOS_COLOR = Color(0.2, 0.5, 1.0, 1.0)  # Azul
const BG_COLOR = Color(0.2, 0.2, 0.2, 0.3)

const HEALTH_RADIUS_OFFSET = 10.0
const COSMOS_RADIUS_OFFSET = -8.0

func _ready():
	health_arc.draw.connect(_draw_health_arc)
	cosmos_arc.draw.connect(_draw_cosmos_arc)
	setup("Josesito",11,7,null)

func setup(player_name: String, health: int, cosmos: int, avatar_texture: Texture2D = null):
	"""Configurar avatar con datos del jugador"""
	name_label.text = player_name
	current_health = health
	current_cosmos = cosmos
	
	if avatar_texture:
		avatar_image.texture = avatar_texture
	
	# Redibujar arcos
	health_arc.queue_redraw()
	cosmos_arc.queue_redraw()

func get_circle_center() -> Vector2:
	return health_arc.size / 2

func get_base_radius() -> float:
	return min(health_arc.size.x, health_arc.size.y) / 2

func get_health_radius() -> float:
	return get_base_radius() + HEALTH_RADIUS_OFFSET - ARC_WIDTH / 2

func get_cosmos_radius() -> float:
	return get_base_radius() + COSMOS_RADIUS_OFFSET - ARC_WIDTH / 2

func get_gold_radius() -> float:
	return get_base_radius() + HEALTH_RADIUS_OFFSET + ARC_WIDTH

func _process(delta):
	if damage_flash_timer > 0.0:
		damage_flash_timer -= delta
		health_arc.queue_redraw()

func update_health(new_health: int, animate: bool = true):
	if new_health < current_health:
		damage_flash_timer = DAMAGE_FLASH_TIME
	
	current_health = new_health
	health_arc.queue_redraw()

	"""Actualizar vida del jugador"""
	if animate:
		var tween = create_tween()
		var old_health = current_health
		current_health = new_health
		health_arc.queue_redraw()

		tween.tween_method(
			func(value: float):
				current_health = int(value)
				health_arc.queue_redraw()
				, float(old_health), float(new_health), 0.5
		)
	else:
		current_health = new_health
		health_arc.queue_redraw()

func update_cosmos(new_cosmos: int, animate: bool = true):
	"""Actualizar cosmos del jugador"""
	# Emitir partículas y sonido solo si el cosmos aumenta
	if new_cosmos > current_cosmos:
		if cosmos_particles:
			cosmos_particles.emitting = true
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_cosmos_gain()

	if animate:
		var tween = create_tween()
		var old_cosmos = current_cosmos
		tween.tween_method(
			func(value: float):
				current_cosmos = int(value)
				cosmos_arc.queue_redraw()
				, float(old_cosmos), float(new_cosmos), 0.5
		)
	else:
		current_cosmos = new_cosmos
		cosmos_arc.queue_redraw()

func _draw_health_arc():
	var arc_size = health_arc.size
	var center = arc_size / 2
	var base_radius = min(arc_size.x, arc_size.y) / 2
	var radius = base_radius + HEALTH_RADIUS_OFFSET - ARC_WIDTH / 2

	var total_segments := max_health
	var full_angle := TAU
	var segment_angle := full_angle / total_segments

	var start_base := -PI / 2
	
	var flash := damage_flash_timer > 0.0
	var flash_color := Color(1.0, 0.6, 0.6, 1.0)

	for i in range(total_segments):
		var seg_start := start_base + i * segment_angle + SEGMENT_PADDING
		var seg_end := start_base + (i + 1) * segment_angle - SEGMENT_GAP

		var color := BG_COLOR
		if i < current_health:
			color = flash_color if flash else HEALTH_COLOR

		_draw_arc_on(
			health_arc,
			center,
			radius,
			seg_start,
			seg_end,
			color,
			ARC_WIDTH
		)

func _draw_cosmos_arc():
	var arc_size = cosmos_arc.size
	var center = arc_size / 2
	var base_radius = min(arc_size.x, arc_size.y) / 2
	var radius = base_radius + COSMOS_RADIUS_OFFSET - ARC_WIDTH / 2

	var total_segments := max_cosmos
	var full_angle := TAU
	var segment_angle := full_angle / total_segments

	var start_base := -PI / 2

	for i in range(total_segments):
		var seg_start := start_base + i * segment_angle + SEGMENT_PADDING
		var seg_end := start_base + (i + 1) * segment_angle - SEGMENT_GAP

		var color := BG_COLOR
		if i < current_cosmos:
			color = COSMOS_COLOR

		_draw_arc_on(
			cosmos_arc,
			center,
			radius,
			seg_start,
			seg_end,
			color,
			ARC_WIDTH
		)

func _draw_arc_on(
	control: Control,
	center: Vector2,
	radius: float,
	start_angle: float,
	end_angle: float,
	color: Color,
	width: float
):
	var points_count = 32
	var points = PackedVector2Array()

	for i in range(points_count + 1):
		var angle = start_angle + (end_angle - start_angle) * i / points_count
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)

	for i in range(points.size() - 1):
		control.draw_line(points[i], points[i + 1], color, width, false)

func set_turn_active(is_active: bool):
	"""Mostrar el punto azul cuando es turno del jugador"""
	if is_active:
		turn_dot.visible = true
		_start_turn_dot_pulse()
	else:
		_stop_turn_dot_pulse()
		turn_dot.visible = false

func _start_turn_dot_pulse():
	_stop_turn_dot_pulse()
	turn_dot.scale = Vector2.ONE
	var tween = create_tween()
	turn_dot_tween = tween
	tween.set_loops()
	tween.tween_property(turn_dot, "scale", Vector2(1.2, 1.2), 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(turn_dot, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)

func _stop_turn_dot_pulse():
	if turn_dot_tween:
		turn_dot_tween.kill()
		turn_dot_tween = null
	turn_dot.scale = Vector2.ONE
