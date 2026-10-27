# ZodiacRing.gd
# Anillo zodiacal dorado dibujado por código: 12 casas que giran lentamente
# y un anillo interior en sentido contrario.
extends Control

const GOLD := Color(1.0, 0.8, 0.36)
const HOUSES := 12

@export var rotation_speed: float = 0.05  # radianes por segundo

var _angle: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_angle = fmod(_angle + delta * rotation_speed, TAU)
	queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - 4.0
	if radius <= 0.0:
		return

	# Anillos exteriores
	draw_arc(center, radius, 0.0, TAU, 128, Color(GOLD, 0.55), 2.0, true)
	draw_arc(center, radius * 0.93, 0.0, TAU, 128, Color(GOLD, 0.35), 1.0, true)
	draw_arc(center, radius * 0.62, 0.0, TAU, 96, Color(GOLD, 0.30), 1.5, true)

	# Las 12 casas: estrella de cuatro puntas + radio hacia el centro
	for i in HOUSES:
		var a := _angle + TAU * i / HOUSES
		var dir := Vector2.from_angle(a)
		var marker := center + dir * radius * 0.965
		_draw_star(marker, radius * 0.045, a, Color(GOLD, 0.9))
		draw_line(center + dir * radius * 0.66, center + dir * radius * 0.9, Color(GOLD, 0.25), 1.0, true)
		# Separadores entre casas
		var sep := Vector2.from_angle(a + PI / HOUSES)
		draw_line(center + sep * radius * 0.93, center + sep * radius, Color(GOLD, 0.45), 1.5, true)

	# Anillo interior con 24 marcas, girando en sentido contrario
	for i in 24:
		var a := -_angle * 1.6 + TAU * i / 24.0
		var dir := Vector2.from_angle(a)
		var inner := radius * (0.55 if i % 2 == 0 else 0.58)
		draw_line(center + dir * inner, center + dir * radius * 0.62, Color(GOLD, 0.4), 1.0, true)


func _draw_star(pos: Vector2, r: float, a: float, color: Color) -> void:
	var points := PackedVector2Array()
	for k in 8:
		var radius := r if k % 2 == 0 else r * 0.35
		points.append(pos + Vector2.from_angle(a + PI / 4.0 * k) * radius)
	draw_colored_polygon(points, color)
