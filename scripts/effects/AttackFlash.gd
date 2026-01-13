# AttackFlash.gd
# Efecto visual de flash blanco cuando una carta recibe daño
extends ColorRect
class_name AttackFlash

var flash_duration := 0.3

func _ready():
	# Cubrir toda la carta
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Color blanco semi-transparente
	color = Color(1.0, 1.0, 1.0, 0.7)
	modulate.a = 0.0
	
	_play_flash()


func _play_flash():
	var tween = create_tween()
	
	# Flash rápido
	tween.tween_property(self, "modulate:a", 1.0, 0.05)
	tween.tween_property(self, "modulate:a", 0.0, flash_duration)
	
	tween.finished.connect(queue_free)
