# DamageNumber.gd
extends Label
class_name DamageNumber

var rise_amount := 40
var duration := 0.6

func _ready():
	modulate.a = 0.0
	pivot_offset = size * 0.5  # Para escalar desde el centro
	_play_animation()

func _play_animation():
	var tween = create_tween()
	tween.set_parallel(true)

	# Aparecer + escalar un poco
	scale = Vector2(0.7, 0.7)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.25)
	tween.tween_property(self, "modulate:a", 1.0, 0.15)

	# Subir
	tween.tween_property(self, "position:y", position.y - rise_amount, duration)

	# Fade out
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_delay(0.3)

	tween.finished.connect(queue_free)
