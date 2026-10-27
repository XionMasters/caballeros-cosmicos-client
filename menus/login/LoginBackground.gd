# LoginBackground.gd
# Fondo animado de la pantalla de login: cosmos (shader), arte del Santuario,
# anillo zodiacal y partículas de cosmos dorado. Se construye por código.
extends Control

const COSMOS_SHADER := preload("res://assets/shaders/cosmos_background.gdshader")
const ZodiacRing := preload("res://menus/login/ZodiacRing.gd")
const HERO_ART_PATH := "res://assets/images/win.png"
const GOLD := Color(1.0, 0.8, 0.36)

var _cosmos: ColorRect
var _hero: TextureRect
var _ring: Control
var _particles: CPUParticles2D
var _cosmos_material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_build_cosmos()
	_build_hero_art()
	_build_ring()
	_build_particles()

	resized.connect(_on_resized)
	_on_resized()
	_start_ambient_animations()


func _build_cosmos() -> void:
	_cosmos = ColorRect.new()
	_cosmos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cosmos_material = ShaderMaterial.new()
	_cosmos_material.shader = COSMOS_SHADER
	_cosmos.material = _cosmos_material
	add_child(_cosmos)
	_cosmos.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_hero_art() -> void:
	var texture: Texture2D = load(HERO_ART_PATH) if ResourceLoader.exists(HERO_ART_PATH) else null
	if texture == null:
		return
	_hero = TextureRect.new()
	_hero.texture = texture
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# Tenue y teñido hacia el cosmos para que no compita con el formulario
	_hero.modulate = Color(0.75, 0.7, 1.0, 0.28)
	add_child(_hero)
	_hero.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_ring() -> void:
	_ring = ZodiacRing.new()
	_ring.modulate = Color(1, 1, 1, 0.45)
	add_child(_ring)


func _build_particles() -> void:
	_particles = CPUParticles2D.new()
	_particles.amount = 90
	_particles.lifetime = 7.0
	_particles.preprocess = 7.0
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.direction = Vector2.UP
	_particles.spread = 18.0
	_particles.gravity = Vector2(0, -8)
	_particles.initial_velocity_min = 25.0
	_particles.initial_velocity_max = 70.0
	_particles.scale_amount_min = 1.5
	_particles.scale_amount_max = 4.0
	_particles.angular_velocity_min = -40.0
	_particles.angular_velocity_max = 40.0

	# Chispas doradas que aparecen y se desvanecen
	var ramp := Gradient.new()
	ramp.set_color(0, Color(GOLD, 0.0))
	ramp.set_color(1, Color(GOLD, 0.0))
	ramp.add_point(0.15, Color(1.0, 0.9, 0.6, 0.9))
	ramp.add_point(0.7, Color(GOLD, 0.5))
	_particles.color_ramp = ramp
	add_child(_particles)


func _on_resized() -> void:
	if _cosmos_material and size.y > 0.0:
		_cosmos_material.set_shader_parameter("aspect", size.x / size.y)

	if _hero:
		_hero.pivot_offset = size / 2.0

	var ring_size := minf(size.x, size.y) * 0.85
	_ring.size = Vector2(ring_size, ring_size)
	_ring.position = (size - _ring.size) / 2.0
	_ring.pivot_offset = _ring.size / 2.0

	_particles.position = Vector2(size.x / 2.0, size.y + 10.0)
	_particles.emission_rect_extents = Vector2(size.x / 2.0, 10.0)


func _start_ambient_animations() -> void:
	# Zoom muy lento sobre el arte (efecto Ken Burns)
	if _hero:
		var zoom := create_tween().set_loops()
		zoom.tween_property(_hero, "scale", Vector2(1.08, 1.08), 18.0).set_trans(Tween.TRANS_SINE)
		zoom.tween_property(_hero, "scale", Vector2.ONE, 18.0).set_trans(Tween.TRANS_SINE)

	# El anillo "respira"
	var pulse := create_tween().set_loops()
	pulse.tween_property(_ring, "modulate:a", 0.6, 3.0).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_ring, "modulate:a", 0.35, 3.0).set_trans(Tween.TRANS_SINE)


func ignite_cosmos() -> void:
	"""Destello de cosmos: aura más intensa y anillo más rápido durante un momento"""
	var tween := create_tween().set_parallel()
	tween.tween_method(_set_aura_boost, 0.0, 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_ring, "scale", Vector2(1.06, 1.06), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_ring, "rotation_speed", 0.6, 0.35)
	tween.chain().set_parallel()
	tween.tween_method(_set_aura_boost, 1.0, 0.0, 1.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_ring, "scale", Vector2.ONE, 1.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_ring, "rotation_speed", 0.05, 1.4)


func _set_aura_boost(value: float) -> void:
	_cosmos_material.set_shader_parameter("aura_boost", value)
