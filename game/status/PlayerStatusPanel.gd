# PlayerStatusPanel.gd
# Avatar del jugador con vida, mana/cosmos y nombre
extends Control
class_name PlayerStatusPanel

# ============================================================================
# REFERENCIAS A NODOS
# ============================================================================
@onready var avatar_display: AvatarDisplay = $VBoxContainer/AvatarDisplay

# ============================================================================
# PARÁMETROS
# ============================================================================
@export var default_avatar_url: String = ""
@export var is_opponent: bool = false

# ============================================================================
# ESTADO
# ============================================================================
var player_id: String = ""
var current_life: int = 12
var current_cosmos: int = 0
var player_name: String

# Tween para indicador de turno activo
var _turn_tween: Tween = null

# ============================================================================
# CICLO DE VIDA
# ============================================================================
func _ready() -> void:
	# print("[PlayerStatusPanel] Inicializando panel de status")
	
	# Ajustar tamaño mínimo
	custom_minimum_size = Vector2(200, 250)


# ============================================================================
# MÉTODOS PÚBLICOS
# ============================================================================
func setup(player_name: String, life: int, cosmos: int, user_id: String = "") -> void:
	"""Configurar panel con datos del jugador y cargar avatar desde servidor"""
	self.player_name = player_name
	current_life = life
	current_cosmos = cosmos
	player_id = user_id
	
	# Setup inicial del avatar sin textura (se cargará en async)
	avatar_display.setup(player_name, life, cosmos, null)
	# print("[PlayerStatusPanel] Verificamos user_id y luedo pedimos imagen del avatar. ", user_id)
	# Si hay user_id, cargar avatar del servidor
	if not user_id.is_empty():
		# print("[PlayerStatusPanel] Verificamos Aca se debe mandar a pedir, porque user_id no es empty? ah, si lo es. ")
		_load_avatar_from_server(user_id)

func update_life(new_life: int) -> void:
	current_life = new_life
	avatar_display.update_health(new_life)

func update_cosmos(new_cosmos: int) -> void:
	current_cosmos = new_cosmos
	avatar_display.update_cosmos(new_cosmos)

func update_both(new_life: int, new_cosmos: int) -> void:
	current_life = new_life
	current_cosmos = new_cosmos

	avatar_display.update_health(new_life)
	avatar_display.update_cosmos(new_cosmos)

func set_active_turn(active: bool) -> void:
	"""Ilumina o apaga el avatar según si es el turno del jugador"""
	if _turn_tween and is_instance_valid(_turn_tween):
		_turn_tween.kill()
		_turn_tween = null

	if active:
		# Pulso dorado cuando es tu turno
		_turn_tween = create_tween()
		_turn_tween.set_loops()
		_turn_tween.tween_property(avatar_display, "modulate", Color(1.5, 1.3, 0.4, 1.0), 0.7)
		_turn_tween.tween_property(avatar_display, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.7)
	else:
		# Apagado cuando no es tu turno
		avatar_display.modulate = Color(0.5, 0.5, 0.55, 1.0)

# ============================================================================
# MÉTODOS PRIVADOS
# ============================================================================
func _update_display() -> void:
	"""Actualizar todos los labels"""
	update_life(current_life)
	update_cosmos(current_cosmos)

func _load_avatar_from_server(user_id: String) -> void:
	"""Cargar avatar del servidor para un usuario específico"""
	# print("[PlayerStatusPanel] _load_avatar_from_server ---------------------------------------- ")
	var callback = func(success: bool, data: Variant, error: String) -> void:
		if success and data is Dictionary:
			var avatar = data.get("avatar", {})
			var image_url = avatar.get("image_url", "")
			
			if not image_url.is_empty():
				_load_avatar_image(image_url)
		else:
			print("[PlayerStatusPanel] Error cargando avatar: ", error)
	
	ApiClient.get_request_with_callback(
		"/profile/user/" + user_id,
		"load_avatar_%s" % user_id,
		callback,
		false  # No requiere autenticación
	)

func _load_avatar_image(image_url: String) -> void:
	"""Cargar imagen de avatar desde URL"""
	var callback = func(image: Image, _tag = null) -> void:
		# print("[PlayerStatusPanel] _load_avatar_image-----------------------------------------------------------------------")
		if image:
			var texture = ImageTexture.create_from_image(image)
			avatar_display.setup(player_name, current_life, current_cosmos, texture)
		else:
			print("[PlayerStatusPanel] Error cargando imagen de avatar")
	
	ApiClient.get_image_with_callback(
		image_url,
		callback,
		"avatar_image_%s" % player_name
	)
