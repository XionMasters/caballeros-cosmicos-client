# AvatarDisplay.gd
# Muestra el avatar del jugador con barras circulares de vida y cosmos
extends Control

@onready var name_label = $VBox/NameLabel
@onready var avatar_image = $VBox/AvatarContainer/AvatarCircle/AvatarImage
@onready var health_arc = $VBox/AvatarContainer/AvatarCircle/HealthArc
@onready var cosmos_arc = $VBox/AvatarContainer/AvatarCircle/CosmosArc
@onready var health_value = $VBox/StatsRow/HealthStat/Value
@onready var cosmos_value = $VBox/StatsRow/CosmosStat/Value
@onready var cosmos_particles = $VBox/AvatarContainer/AvatarCircle/CosmosParticles
@onready var turn_dot = $TurnDot
# StatsLabel puede no existir, se crea dinámicamente
var stats_label: Label = null

var max_health: int = 12
var current_health: int = 12
var max_cosmos: int = 12
var current_cosmos: int = 0
var turn_dot_tween: Tween = null

const ARC_WIDTH = 6.0
const HEALTH_COLOR = Color(1.0, 0.2, 0.2, 1.0)  # Rojo
const COSMOS_COLOR = Color(0.2, 0.5, 1.0, 1.0)  # Azul
const BG_COLOR = Color(0.2, 0.2, 0.2, 0.3)

func _ready():
	health_arc.draw.connect(_draw_health_arc)
	cosmos_arc.draw.connect(_draw_cosmos_arc)
	_create_stats_label()

func _create_stats_label():
	"""Crear label central con HP/CP si no existe en la escena"""
	# Intentar obtener el nodo si ya existe
	if has_node("VBox/AvatarContainer/AvatarCircle/StatsLabel"):
		stats_label = $VBox/AvatarContainer/AvatarCircle/StatsLabel
	else:
		# Crear dinámicamente si no existe
		stats_label = Label.new()
		stats_label.name = "StatsLabel"
		$VBox/AvatarContainer/AvatarCircle.add_child(stats_label)
		stats_label.anchor_left = 0.5
		stats_label.anchor_top = 0.5
		stats_label.anchor_right = 0.5
		stats_label.anchor_bottom = 0.5
		stats_label.offset_left = -40
		stats_label.offset_top = -20
		stats_label.offset_right = 40
		stats_label.offset_bottom = 20
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stats_label.add_theme_font_size_override("font_size", 16)
		stats_label.add_theme_color_override("font_color", Color.WHITE)
		stats_label.add_theme_color_override("font_outline_color", Color.BLACK)
		stats_label.add_theme_constant_override("outline_size", 4)
		stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_stats_label()

func setup(player_name: String, health: int, cosmos: int, avatar_texture: Texture2D = null):
	"""Configurar avatar con datos del jugador"""
	name_label.text = player_name
	current_health = health
	current_cosmos = cosmos
	
	health_value.text = str(health)
	cosmos_value.text = str(cosmos)
	
	if avatar_texture:
		avatar_image.texture = avatar_texture
	
	# Redibujar arcos
	health_arc.queue_redraw()
	cosmos_arc.queue_redraw()
	_update_stats_label()

func update_health(new_health: int, animate: bool = true):
	"""Actualizar vida del jugador"""
	if animate:
		var tween = create_tween()
		var old_health = current_health
		tween.tween_method(
			func(value: float):
				current_health = int(value)
				health_value.text = str(current_health)
				health_arc.queue_redraw()
				, float(old_health), float(new_health), 0.5
		)
	else:
		current_health = new_health
		health_value.text = str(new_health)
		health_arc.queue_redraw()
	_update_stats_label()

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
				cosmos_value.text = str(current_cosmos)
				cosmos_arc.queue_redraw()
				, float(old_cosmos), float(new_cosmos), 0.5
		)
	else:
		current_cosmos = new_cosmos
		cosmos_value.text = str(new_cosmos)
		cosmos_arc.queue_redraw()
	_update_stats_label()

func _update_stats_label():
	"""Actualizar texto central con HP/CP"""
	if stats_label:
		stats_label.text = str(current_health) + "/" + str(max_health) + "\n" + str(current_cosmos) + "/" + str(max_cosmos)

func _draw_health_arc():
	"""Dibujar arco de vida (parte superior del círculo)"""
	var arc_size = health_arc.size
	var center = arc_size / 2
	var radius = min(arc_size.x, arc_size.y) / 2 - ARC_WIDTH / 2
	
	# Ángulos: -180° a 0° (semicírculo superior)
	var start_angle = -PI
	var end_angle = 0.0
	
	# Dibujar fondo del arco
	_draw_arc_on(health_arc, center, radius, start_angle, end_angle, BG_COLOR, ARC_WIDTH)
	
	# Calcular porcentaje de vida
	var health_percent = float(current_health) / float(max_health)
	var filled_angle = start_angle + (end_angle - start_angle) * health_percent
	
	# Dibujar arco de vida lleno
	if health_percent > 0:
		_draw_arc_on(health_arc, center, radius, start_angle, filled_angle, HEALTH_COLOR, ARC_WIDTH)

func _draw_cosmos_arc():
	"""Dibujar arco de cosmos (parte inferior del círculo)"""
	var arc_size = cosmos_arc.size
	var center = arc_size / 2
	var radius = min(arc_size.x, arc_size.y) / 2 - ARC_WIDTH / 2
	
	# Ángulos: 0° a 180° (semicírculo inferior)
	var start_angle = 0.0
	var end_angle = PI
	
	# Dibujar fondo del arco
	_draw_arc_on(cosmos_arc, center, radius, start_angle, end_angle, BG_COLOR, ARC_WIDTH)
	
	# Calcular porcentaje de cosmos
	var cosmos_percent = float(current_cosmos) / float(max_cosmos)
	var filled_angle = start_angle + (end_angle - start_angle) * cosmos_percent
	
	# Dibujar arco de cosmos lleno
	if cosmos_percent > 0:
		_draw_arc_on(cosmos_arc, center, radius, start_angle, filled_angle, COSMOS_COLOR, ARC_WIDTH)

func _draw_arc_on(control: Control, center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color, width: float):
	"""Dibujar un arco en un control específico"""
	var points_count = 32
	var points = PackedVector2Array()
	
	for i in range(points_count + 1):
		var angle = start_angle + (end_angle - start_angle) * i / points_count
		var point = center + Vector2(cos(angle), sin(angle)) * radius
		points.append(point)
	
	# Dibujar línea gruesa
	for i in range(points.size() - 1):
		control.draw_line(points[i], points[i + 1], color, width, true)
	
	# Dibujar caps redondeados
	if points.size() > 0:
		control.draw_circle(points[0], width / 2, color)
		control.draw_circle(points[points.size() - 1], width / 2, color)

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
