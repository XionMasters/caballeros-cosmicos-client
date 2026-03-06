# MatchEffectsManager.gd
extends CanvasLayer
class_name MatchEffectsManager
# CanvasLayer garantiza que los efectos SIEMPRE estén sobre la UI y las cartas

# ---------------------------------------------------------
#  PRELOADS
# ---------------------------------------------------------
const COSMOS_PARTICLE := preload("res://shared/effects/CosmosParticle.tscn")
const ATTACK_FLASH := preload("res://shared/effects/AttackFlash.tscn")
const DAMAGE_NUMBER := preload("res://shared/effects/DamageNumber.tscn")

# Para líneas y flashes UI
var effects_root : Control = null

func _ready():
	# Capa superior dentro del CanvasLayer
	effects_root = Control.new()
	effects_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# CRÍTICO: ignorar input para no bloquear clics en las cartas y botones
	effects_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(effects_root)

# ---------------------------------------------------------
#  CONVERSIÓN DE POSICIONES
# ---------------------------------------------------------
func _to_canvas_position(global_pos: Vector2) -> Vector2:
	"""
	Asegura que cualquier posición (Control o Node2D) se convierta a coordenadas UI.
	Muy importante para daño, ataques, partículas encima de cartas.
	"""
	return effects_root.get_viewport().get_canvas_transform().affine_inverse() * global_pos


# ---------------------------------------------------------
#  CARD PLAY EFFECT
# ---------------------------------------------------------
func play_card_effect(global_pos: Vector2, card_type: String):
	var pos = _to_canvas_position(global_pos)

	match card_type:
		"knight":
			spawn_cosmos_burst(pos, Color.GOLD)
		"tecnica":
			spawn_cosmos_burst(pos, Color.SKY_BLUE)
		"objeto":
			spawn_cosmos_burst(pos, Color.SILVER)
		"escenario":
			spawn_global_flash(Color(1, 1, 1, 0.35))
		"ayudante":
			spawn_cosmos_burst(pos, Color.GREEN)
		"ocasion":
			spawn_cosmos_burst(pos, Color.PURPLE)


# ---------------------------------------------------------
#  PARTICLE BURST
# ---------------------------------------------------------
func spawn_cosmos_burst(pos: Vector2, color: Color):
	if not COSMOS_PARTICLE:
		return
	
	var p = COSMOS_PARTICLE.instantiate()
	effects_root.add_child(p)
	p.global_position = pos
	p.modulate = color
	p.emitting = true

	await get_tree().create_timer(1.5).timeout
	p.queue_free()


# ---------------------------------------------------------
#  GLOBAL FLASH
# ---------------------------------------------------------
func spawn_global_flash(color: Color):
	var flash = ColorRect.new()
	flash.color = color
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	effects_root.add_child(flash)

	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.45)

	await tween.finished
	flash.queue_free()


# ---------------------------------------------------------
#  ATTACK EFFECT
# ---------------------------------------------------------
func play_attack_effect(from_global: Vector2, to_global: Vector2, damage: int):
	var a = _to_canvas_position(from_global)
	var b = _to_canvas_position(to_global)

	spawn_attack_line(a, b)
	spawn_damage_number(b, damage)
	shake_camera(0.25, 12)


func spawn_attack_line(a: Vector2, b: Vector2):
	var line = Line2D.new()
	effects_root.add_child(line)

	line.add_point(a)
	line.add_point(b)
	line.width = 5
	line.default_color = Color.YELLOW

	var tween = create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.25)

	await tween.finished
	line.queue_free()


# ---------------------------------------------------------
#  DAMAGE NUMBER
# ---------------------------------------------------------
func spawn_damage_number(pos: Vector2, damage: int):
	if DAMAGE_NUMBER:
		var d = DAMAGE_NUMBER.instantiate()
		effects_root.add_child(d)
		d.global_position = pos

		if d.has_method("set_damage"):
			d.set_damage(damage)
		return

	# Fallback sin escena
	var lbl = Label.new()
	lbl.text = "-" + str(damage)
	lbl.add_theme_font_size_override("font_size", 48)
	lbl.add_theme_color_override("font_color", Color.RED)
	lbl.global_position = pos
	effects_root.add_child(lbl)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", pos.y - 90, 0.9)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.9)

	await tween.finished
	lbl.queue_free()


# ---------------------------------------------------------
#  CAMERA SHAKE (UI-safe)
# ---------------------------------------------------------
func shake_camera(duration: float, intensity: float):
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return

	var original := cam.offset
	var time := 0.0

	while time < duration:
		cam.offset = original + Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		time += get_process_delta_time()
		await get_tree().process_frame

	cam.offset = original


# ---------------------------------------------------------
#  TECHNIQUE ACTIVATION
# ---------------------------------------------------------
func play_technique_activation(technique_name: String, global_pos: Vector2):
	var pos = _to_canvas_position(global_pos)

	var lbl = Label.new()
	lbl.text = technique_name
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color.GOLD)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.global_position = pos
	effects_root.add_child(lbl)

	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(lbl, "scale", Vector2(1.4, 1.4), 0.5).set_trans(Tween.TRANS_BACK)
	t.tween_property(lbl, "modulate:a", 0.0, 1.0).set_delay(0.45)

	await t.finished
	lbl.queue_free()

	spawn_cosmos_burst(pos, Color.CYAN)


func play_cosmos_charge_effect(global_pos: Vector2):
	var pos = _to_canvas_position(global_pos)
	spawn_cosmos_burst(pos, Color(0.5, 0.5, 1.0))
