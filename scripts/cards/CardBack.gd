# CardBack.gd
# Componente visual para el dorso de la carta (oponente, deck, etc.)
# Usa la textura pre-cargada por CardsManager
extends PanelContainer
class_name CardBack

@onready var back_image: TextureRect = $BackImage

# Estilo compartido (se crea una sola vez)
static var shared_style: StyleBoxFlat = null


func _ready():
	custom_minimum_size = Vector2(80, 120)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_setup_style()
	_load_or_assign_texture()


func _setup_style():
	"""Crear o reutilizar el estilo compartido"""
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


func _load_or_assign_texture():
	"""Asignar textura desde CardsManager (ya pre-cargada)"""
	# Verificar que back_image esté listo
	if not back_image:
		print("[CardBack] ⚠️ back_image no está listo, diferiendo...")
		call_deferred("_load_or_assign_texture")
		return
	
	# Obtener dorso del CardsManager
	var texture = CardsManager.get_card_back_texture()
	
	if texture:
		print("[CardBack] ✅ Textura del dorso asignada desde cache")
		back_image.texture = texture
		return
	
	# Si no está cargado aún, usar fallback y esperar
	print("[CardBack] ⏳ Esperando dorso del CardsManager...")
	back_image.texture = _get_fallback_texture()
	
	# Conectar para cuando se cargue (si no estaba ya conectado)
	if not CardsManager.card_back_loaded.is_connected(_on_card_back_ready):
		CardsManager.card_back_loaded.connect(_on_card_back_ready)


func _on_card_back_ready(texture: ImageTexture):
	"""Callback cuando CardsManager termina de cargar el dorso"""
	print("[CardBack] 📥 Signal card_back_loaded recibida, actualizando textura")
	if back_image and texture:
		print("[CardBack] ✅ Textura del dorso cargada exitosamente")
		back_image.texture = texture
	else:
		print("[CardBack] ❌ Error: back_image=%s, texture=%s" % [back_image != null, texture != null])


func _get_fallback_texture() -> Texture2D:
	"""Textura de respaldo si falla la descarga"""
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.15, 0.15, 0.2, 1))
	return ImageTexture.create_from_image(img)
