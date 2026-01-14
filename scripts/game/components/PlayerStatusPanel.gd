# PlayerStatusPanel.gd
# Avatar del jugador con vida, mana/cosmos y nombre
extends Control
class_name PlayerStatusPanel

# ============================================================================
# REFERENCIAS A NODOS
# ============================================================================
@onready var avatar_texture = $VBoxContainer/AvatarTexture
@onready var player_name_label = $VBoxContainer/PlayerNameLabel
@onready var life_label = $VBoxContainer/StatsContainer/LifeLabel
@onready var cosmos_label = $VBoxContainer/StatsContainer/CosmosLabel

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
var player_name: String = "Jugador"

# ============================================================================
# CICLO DE VIDA
# ============================================================================
func _ready() -> void:
	print("[PlayerStatusPanel] Inicializando panel de status")
	
	# Ajustar tamaño mínimo
	custom_minimum_size = Vector2(200, 250)


# ============================================================================
# MÉTODOS PÚBLICOS
# ============================================================================
func setup(name: String, life: int, cosmos: int, avatar_url: String = "") -> void:
	"""Configurar el panel inicial"""
	player_name = name
	current_life = life
	current_cosmos = cosmos
	
	_update_display()
	
	if not avatar_url.is_empty():
		_load_avatar(avatar_url)


func update_life(new_life: int) -> void:
	"""Actualizar vida"""
	current_life = new_life
	if life_label:
		life_label.text = "❤️ %d" % current_life


func update_cosmos(new_cosmos: int) -> void:
	"""Actualizar cosmos/mana"""
	current_cosmos = new_cosmos
	if cosmos_label:
		cosmos_label.text = "✨ %d" % current_cosmos


func update_both(new_life: int, new_cosmos: int) -> void:
	"""Actualizar ambas métricas"""
	update_life(new_life)
	update_cosmos(new_cosmos)


# ============================================================================
# MÉTODOS PRIVADOS
# ============================================================================
func _update_display() -> void:
	"""Actualizar todos los labels"""
	if player_name_label:
		player_name_label.text = player_name
	
	update_life(current_life)
	update_cosmos(current_cosmos)


func _load_avatar(url: String) -> void:
	"""Cargar avatar desde URL (async)"""
	if not avatar_texture:
		return
	
	print("[PlayerStatusPanel] Cargando avatar: %s" % url)
	
	# Usar CardsManager si está disponible para reutilizar caché
	if CardsManager:
		CardsManager.fetch_image(url, _on_avatar_loaded)
	else:
		# Fallback a carga directa
		var http_request = HTTPRequest.new()
		add_child(http_request)
		http_request.request_completed.connect(_on_http_request_completed.bind(avatar_texture))
		http_request.request(url)


func _on_avatar_loaded(texture: Texture2D) -> void:
	"""Callback cuando el avatar se carga"""
	if avatar_texture:
		avatar_texture.texture = texture
		print("[PlayerStatusPanel] ✅ Avatar cargado")


func _on_http_request_completed(result, response_code, headers, body, texture_rect):
	"""Callback de HTTP request directo"""
	if response_code == 200:
		var image = Image.new()
		image.load_png_from_buffer(body)
		var texture = ImageTexture.create_from_image(image)
		texture_rect.texture = texture
