# CardBack.gd
# Componente visual para el dorso de la carta
# NO decide qué textura usar, solo la muestra
extends Control
class_name CardBack

@onready var back_image: TextureRect = $BackImage

# Estilo compartido (una sola instancia)
static var shared_style: StyleBoxFlat = null


func _ready() -> void:
	custom_minimum_size = Vector2(80, 120)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_style()

	# Fallback solo para editor o tests
	if Engine.is_editor_hint():
		set_back_texture(_get_fallback_texture())


# ============================================================================
# API PÚBLICA
# ============================================================================
func set_back_texture(texture: Texture2D) -> void:
	"""Asigna la textura del dorso"""
	if not back_image:
		call_deferred("set_back_texture", texture)
		return

	back_image.texture = texture


# ============================================================================
# ESTILO
# ============================================================================

func _setup_style() -> void:
	if shared_style == null:
		shared_style = StyleBoxFlat.new()
		shared_style.bg_color = Color(0.1, 0.1, 0.15, 1)
		shared_style.border_width_left = 2
		shared_style.border_width_top = 2
		shared_style.border_width_right = 2
		shared_style.border_width_bottom = 2
		shared_style.border_color = Color(0.4, 0.4, 0.6, 1)
		shared_style.corner_radius_top_left = 8
		shared_style.corner_radius_top_right = 8
		shared_style.corner_radius_bottom_left = 8
		shared_style.corner_radius_bottom_right = 8

	add_theme_stylebox_override("panel", shared_style)


# ============================================================================
# FALLBACK
# ============================================================================

func _get_fallback_texture() -> Texture2D:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.15, 0.15, 0.2, 1))
	return ImageTexture.create_from_image(img)
