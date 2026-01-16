extends Control

@onready var avatar_display: AvatarDisplay = get_parent().get_parent().get_parent().get_parent() as AvatarDisplay

const GOLD := Color(1.0, 0.85, 0.3, 1.0)
const WIDTH := 3.0
const GOLD_OUTER := Color(1.0, 0.78, 0.25, 0.9)
const GOLD_INNER := Color(1.0, 0.95, 0.6, 0.15)

func _draw() -> void:
	if not avatar_display:
		return

	var center: Vector2 = avatar_display.get_circle_center()
	var radius: float = avatar_display.get_gold_radius()

	# degradé
	draw_radial_gradient_circle(center, radius - WIDTH * 0.5)

	# borde fuerte
	draw_arc(
		center,
		radius,
		0.0,
		TAU,
		64,
		GOLD_OUTER,
		WIDTH
	)


func draw_radial_gradient_circle(
	center: Vector2,
	radius: float,
	steps: int = 12
) -> void:
	for i in range(steps):
		var t := float(i) / float(steps - 1)
		
		var r : float = lerp(radius, radius * 0.6, t)
		var color := GOLD_OUTER.lerp(GOLD_INNER, t)

		draw_circle(center, r, color)
