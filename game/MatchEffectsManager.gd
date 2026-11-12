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
	"""Trazo de energía del atacante al defensor: un halo ancho y un núcleo brillante"""
	var glow := Line2D.new()
	glow.width = 26
	glow.default_color = Color(1.0, 0.78, 0.24, 0.35)
	glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	var core := Line2D.new()
	core.width = 7
	core.default_color = Color(1.0, 0.97, 0.85)
	core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	core.end_cap_mode = Line2D.LINE_CAP_ROUND
	for line in [glow, core]:
		line.add_point(a)
		line.add_point(a)
		effects_root.add_child(line)

	# El trazo "viaja" del atacante al defensor y luego se apaga
	var tween := create_tween()
	tween.tween_method(func(t: float):
		var p := a.lerp(b, t)
		glow.set_point_position(1, p)
		core.set_point_position(1, p)
	, 0.0, 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(spawn_impact_ring.bind(b, UIPalette.GOLD_LIGHT))
	tween.set_parallel(true)
	tween.tween_property(glow, "modulate:a", 0.0, 0.3)
	tween.tween_property(core, "modulate:a", 0.0, 0.3)

	await tween.finished
	glow.queue_free()
	core.queue_free()


func spawn_impact_ring(pos: Vector2, color: Color) -> void:
	"""Onda expansiva corta en el punto de impacto"""
	var ring := _RingFx.new()
	ring.color = color
	ring.position = pos
	effects_root.add_child(ring)


## Anillo que se expande y desvanece (dibujado, sin texturas)
class _RingFx extends Node2D:
	var color := Color.WHITE
	var radius := 10.0
	var width := 10.0
	var alpha := 1.0

	func _ready() -> void:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(self, "radius", 90.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "width", 2.0, 0.35)
		tween.tween_property(self, "alpha", 0.0, 0.35)
		tween.finished.connect(queue_free)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(color, alpha), width, true)


# ---------------------------------------------------------
#  DAMAGE NUMBER
# ---------------------------------------------------------
func spawn_heal_number(pos: Vector2, amount: int):
	spawn_damage_number(pos, -absi(amount))


func spawn_damage_number(pos: Vector2, damage: int):
	if DAMAGE_NUMBER:
		var d = DAMAGE_NUMBER.instantiate()
		if d.has_method("set_damage"):
			d.set_damage(damage)
		effects_root.add_child(d)
		d.global_position = pos
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
var _shaking := false

func shake_camera(duration: float, intensity: float):
	"""Temblor de pantalla. El tablero es UI (sin Camera2D): se mueve el nodo de la partida."""
	var cam := get_viewport().get_camera_2d()
	var target: Control = get_parent() as Control
	if not cam and not target:
		return
	if _shaking:
		return
	_shaking = true

	var original: Vector2 = cam.offset if cam else target.position
	var time := 0.0

	while time < duration and is_inside_tree():
		var falloff := 1.0 - time / duration
		var offset := Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		) * falloff
		if cam:
			cam.offset = original + offset
		else:
			target.position = original + offset
		time += get_process_delta_time()
		await get_tree().process_frame

	if cam:
		cam.offset = original
	elif is_instance_valid(target):
		target.position = original
	_shaking = false


# ---------------------------------------------------------
#  DEATH FLASH
# ---------------------------------------------------------
func spawn_death_flash(global_pos: Vector2):
	"""Caballero caído: destello rojo oscuro, doble onda y temblor"""
	var pos = _to_canvas_position(global_pos)
	spawn_impact_ring(pos, UIPalette.LIFE)
	spawn_cosmos_burst(pos, Color(0.6, 0.05, 0.1, 0.95))
	spawn_global_flash(Color(0.55, 0.0, 0.08, 0.22))
	shake_camera(0.3, 14)
	await get_tree().create_timer(0.12).timeout
	spawn_impact_ring(pos, Color(1, 1, 1, 0.8))


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
