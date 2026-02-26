# DeckDisplay.gd
extends CardCollection
class_name DeckDisplay

# Usar configuración centralizada de tamaños (inicialización en _ready)
var deck_card_size: Vector2 = Vector2.ZERO

@export var max_visible_cards: int = 3      # Cartas que se muestran superpuestas
@export var card_back_scene: PackedScene    # Escena de CardBack
@export var stack_offset: float = 6.0       # Offset vertical por carta
@export var show_counter: bool = true

var _card_count: int = 0
var _player_id: String = ""
var _back_texture: Texture2D
var _counter_label: Label

func _ready() -> void:
	##super._ready()
	# Inicializar tamaño de cartas desde CardSizeConfig (autoload)
	deck_card_size = CardSizeConfig.get_deck_card_size()
	
	# Establecer tamaño mínimo del contenedor para que los hijos sean visibles
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# print("[DeckDisplay] 📏 Tamaño mínimo establecido: %s" % custom_minimum_size)
	
	_ensure_counter()
	
	# NO llamar a arrange_cards aquí porque aún no hay cartas
	# Se llamará después de que se agreguen las cartas en _rebuild_visual()


func _ensure_counter() -> void:
	if show_counter:
		if not has_node("Counter"):
			_counter_label = Label.new()
			_counter_label.name = "Counter"
			_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_counter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_counter_label.label_settings = LabelSettings.new()
			_counter_label.label_settings.font_size = 24
			add_child(_counter_label)
		else:
			_counter_label = $Counter
	else:
		if has_node("Counter"):
			$Counter.queue_free()
		_counter_label = null


# ============================================================
#   API PRINCIPAL
# ============================================================

func setup(card_count: int, player_id: String) -> void:
	_card_count = max(card_count, 0)
	_player_id = player_id
	
	# Render inicial inmediato
	_rebuild_visual()
	
	# Luego intentamos cargar textura personalizada (async)
	_load_card_back_texture()


func set_count(n: int) -> void:
	_card_count = max(n, 0)
	_rebuild_visual()
	arrange_cards()


func reset_deck(n: int) -> void:
	_card_count = max(n, 0)
	_rebuild_visual()
	arrange_cards()


func push_card_back() -> void:
	_card_count += 1
	_rebuild_visual()
	arrange_cards()


func pop_card_back() -> void:
	if _card_count > 0:
		_card_count -= 1
		_rebuild_visual()
		arrange_cards()

func _load_card_back_texture() -> void:
	if _player_id.is_empty():
		# print("[DeckDisplay] ℹ️ player_id vacío, usando dorso por defecto")
		_back_texture = CardsManager.get_default_card_back()
		# print("[DeckDisplay] 📍 Dorso por defecto = %s" % ("Válido" if _back_texture else "NULL"))
		_rebuild_visual()
		return

	# Primero intentar cargar desde el perfil público del usuario
	var callback = func(success: bool, data: Variant, error: String) -> void:
		if success and data is Dictionary:
			# print("[DeckDisplay] 📋 Datos recibidos: %s" % data)
			var deck_back = data.get("deck_back")
			
			# print("[DeckDisplay] 📍 Respuesta del perfil: deck_back = %s" % ("Exists" if deck_back else "Null"))
			
			# Verificar si hay un dorso actual
			if deck_back and deck_back is Dictionary:
				var image_url = deck_back.get("image_url", "")
				# print("[DeckDisplay] 📍 URL encontrada: %s" % image_url)
				
				if not image_url.is_empty():
					# print("[DeckDisplay] ✅ Cargando dorso: %s" % deck_back.get("name", ""))
					_load_card_back_image(image_url)
					return
			
			# Si no hay dorso en perfil, usar el predeterminado
			# print("[DeckDisplay] ℹ️ Sin dorso personalizado, intentando default")
			_back_texture = CardsManager.get_default_card_back()
			# print("[DeckDisplay] 📍 Dorso por defecto = %s" % ("Válido" if _back_texture else "NULL"))
			_rebuild_visual()
			return

		# print("[DeckDisplay] ⚠️ Error cargando perfil: %s" % error)
		_back_texture = CardsManager.get_default_card_back()
		# print("[DeckDisplay] 📍 Dorso por defecto (error) = %s" % ("Válido" if _back_texture else "NULL"))
		_rebuild_visual()

	# print("[DeckDisplay] 🔄 Cargando perfil de usuario: %s" % _player_id)
	
	# Llamar al endpoint público que devuelve avatar y deck_back
	ApiClient.get_request_with_callback(
		"/profile/user/" + _player_id,
		"load_deckback_%s" % _player_id,
		callback,
		false  # Sin autenticación para perfil público
	)

func _load_card_back_image(image_url: String) -> void:
	# print("[DeckDisplay] 🖼️ Cargando imagen: %s" % image_url)
	
	var callback = func(image: Image, _tag = null) -> void:
		if image:
			_back_texture = ImageTexture.create_from_image(image)
			# print("[DeckDisplay] ✅ Imagen de dorso cargada correctamente")
		else:
			# print("[DeckDisplay] ❌ Error cargando imagen de dorso, usando default")
			_back_texture = CardsManager.get_default_card_back()
		
		# Reconstruir visual DESPUÉS de cargar la textura
		_rebuild_visual()

	ApiClient.get_image_with_callback(
		image_url,
		callback,
		"deckback_image_%s" % _player_id
	)

# ============================================================
#   RECONSTRUCCIÓN VISUAL
# ============================================================
func _rebuild_visual() -> void:
	if not card_back_scene:
		push_error("[DeckDisplay] card_back_scene no asignado")
		return
	
	# print("[DeckDisplay] 🎨 Reconstruyendo visual con %d cartas (mostrar max %d)" % [_card_count, max_visible_cards])
	
	# Borra todos los nodos hijos visibles (no el Counter)
	for child in get_children():
		if child != _counter_label:
			child.queue_free()

	# Crear las cartas visibles
	var cards_visible: int = min(_card_count, max_visible_cards)

	for i in range(cards_visible):
		var back = card_back_scene.instantiate() as CardBack
		
		# Asignar textura si existe, sino CardBack maneja el fallback
		if _back_texture:
			back.set_back_texture(_back_texture)
			# print("[DeckDisplay] ✅ Textura asignada a carta %d" % i)
		else:
			# Si no hay textura, CardBack mostrará su fallback visual
			print("[DeckDisplay] ⚠️ Sin textura de dorso, usando fallback de CardBack")
		
		# back.position = Vector2(0, -i * stack_offset)
		back.z_index = i
		add_child(back)
		# print("[DeckDisplay] ✅ Carta %d agregada al árbol de nodos" % i)

	# Contador visual
	if _counter_label:
		_counter_label.text = str(_card_count)
		_counter_label.position = Vector2(0, 30)
		# print("[DeckDisplay] 📊 Contador actualizado: %d" % _card_count)
	
	# print("[DeckDisplay] ✅ Visual reconstruida completamente: %d cartas visibles" % cards_visible)
	arrange_cards()


# ============================================================
#   CARDCOLLECTION OVERRIDES
# ============================================================

func _update_layout() -> void:
	"""Override del método template de CardCollection"""
	arrange_cards()
	super._update_layout()  # Emitir señal

func arrange_cards() -> void:
	# Apila las cartas con offset vertical
	# print("[DeckDisplay] 📐 arrange_cards() - size: %s, custom_minimum_size: %s" % [size, custom_minimum_size])
	
	var visible_count = 0
	for child in get_children():
		if child == _counter_label:
			continue
		if child is Control:
			# Centrar horizontalmente
			var center_x = (size.x - child.size.x) * 0.5 if size.x > 0 else 0
			
			# Apilar verticalmente con offset
			var offset_y = visible_count * stack_offset
			
			child.position = Vector2(center_x, offset_y)
			# print("[DeckDisplay] 📍 Carta %d posicionada en (x=%f, y=%f) (size: %s)" % [visible_count, center_x, offset_y, child.size])
			
			visible_count += 1
# ============================================================
#   GETTERS
# ============================================================

func get_back_texture() -> Texture2D:
	return _back_texture


# No queremos permitir añadir nodos arbitrarios desde fuera.
func add_card(_card: Node) -> void:
	push_warning("DeckLayout no usa add_card(). Usa set_count(), push_card_back(), etc.")


func remove_card(_card: Node) -> void:
	push_warning("DeckLayout no usa remove_card(). Usa pop_card_back().")
