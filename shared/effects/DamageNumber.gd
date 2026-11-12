# DamageNumber.gd
# Número flotante de daño o curación: aparece grande de golpe, sube y se desvanece.
extends Label
class_name DamageNumber

var rise_amount := 80.0
var duration := 0.9

var _value := 0
var _is_heal := false


func set_damage(amount: int) -> void:
	"""Daño: «-N» en rojo. Una cantidad negativa se muestra como curación."""
	_value = absi(amount)
	_is_heal = amount < 0
	_apply_text()


func set_heal(amount: int) -> void:
	_value = absi(amount)
	_is_heal = true
	_apply_text()


func _ready() -> void:
	theme_type_variation = &"StatValue"
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 200
	_apply_text()
	modulate.a = 0.0
	# Centrado sobre el punto de impacto, con una pequeña variación para que no se tapen
	await get_tree().process_frame
	if not is_inside_tree():
		return
	reset_size()
	position -= size / 2.0
	position.x += randf_range(-14.0, 14.0)
	pivot_offset = size * 0.5
	rotation = deg_to_rad(randf_range(-8.0, 8.0))
	_play_animation()


func _apply_text() -> void:
	text = ("+%d" if _is_heal else "-%d") % _value
	var big := _value >= 5
	add_theme_font_size_override("font_size", 84 if big else 64)
	add_theme_constant_override("outline_size", 14)
	add_theme_color_override("font_color", UIPalette.HEAL if _is_heal else Color("#FF6B5E"))
	add_theme_color_override("font_outline_color", Color("#1A0410") if not _is_heal else Color("#03200F"))


func _play_animation() -> void:
	var tween := create_tween()
	tween.set_parallel(true)

	# Entra enorme y se asienta (efecto golpe)
	scale = Vector2(1.9, 1.9)
	tween.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.08)

	# Sube y se desvanece
	tween.tween_property(self, "position:y", position.y - rise_amount, duration).set_delay(0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.35).set_delay(duration - 0.2)

	tween.finished.connect(queue_free)
