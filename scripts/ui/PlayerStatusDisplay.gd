# PlayerStatusDisplay.gd
# Muestra avatar, vida y cosmos con indicadores visuales (ruedas)
extends Control
class_name PlayerStatusDisplay

@export var player_name: String = "Player"
@export var is_player: bool = true  # true = jugador, false = oponente
@export var avatar_size: Vector2 = Vector2(120, 120)

# Referencias
var avatar_rect: TextureRect = null
var life_wheel: Control = null      # Rueda de vida
var cosmos_wheel: Control = null    # Rueda de cosmos
var life_label: Label = null
var cosmos_label: Label = null
var name_label: Label = null

# Estado actual
var current_life: int = 12
var current_cosmos: int = 0
var max_life: int = 12

func _ready():
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	_create_ui()
	_update_display()

func _create_ui() -> void:
	"""Crear estructura visual: Avatar + Ruedas indicadoras"""
	
	# HBox para organizar horizontalmente
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 40)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(hbox)
	
	# Rueda de cosmos (izquierda)
	cosmos_wheel = _create_indicator_wheel("COSMOS", Color(0, 0.8, 1, 0.9))  # Azul
	hbox.add_child(cosmos_wheel)
	
	# Avatar (centro) - Container vertical
	var avatar_container = VBoxContainer.new()
	avatar_container.alignment = BoxContainer.ALIGNMENT_CENTER
	avatar_container.add_theme_constant_override("separation", 10)
	hbox.add_child(avatar_container)
	
	# Avatar image
	avatar_rect = TextureRect.new()
	avatar_rect.custom_minimum_size = avatar_size
	avatar_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	avatar_container.add_child(avatar_rect)
	
	# Nombre debajo del avatar
	name_label = Label.new()
	name_label.text = player_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar_container.add_child(name_label)
	
	# Rueda de vida (derecha)
	life_wheel = _create_indicator_wheel("LIFE", Color(1, 0.2, 0.2, 0.9))  # Rojo
	hbox.add_child(life_wheel)

func _create_indicator_wheel(label_text: String, color: Color) -> Control:
	"""Crear una rueda indicadora (círculo con valor y label)"""
	var wheel = Control.new()
	wheel.custom_minimum_size = Vector2(120, 120)
	
	# Panel con estilo circular
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_bottom_left = 60
	style.corner_radius_bottom_right = 60
	style.corner_radius_top_left = 60
	style.corner_radius_top_right = 60
	style.border_color = Color.WHITE
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(120, 120)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wheel.add_child(panel)
	
	# VBox para organizar valor y label
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(vbox)
	
	# Label con valor grande (número)
	var value_label = Label.new()
	value_label.text = "0"
	value_label.add_theme_font_size_override("font_size", 40)
	value_label.add_theme_color_override("font_color", Color.WHITE)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.custom_minimum_size = Vector2(100, 50)
	vbox.add_child(value_label)
	
	# Label con tipo (LIFE/COSMOS) pequeño
	var type_label = Label.new()
	type_label.text = label_text
	type_label.add_theme_font_size_override("font_size", 12)
	type_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.custom_minimum_size = Vector2(100, 30)
	vbox.add_child(type_label)
	
	# Guardar referencia al label de valor
	if label_text == "LIFE":
		life_label = value_label
	else:
		cosmos_label = value_label
	
	return wheel

func update_stats(life: int, cosmos: int) -> void:
	"""Actualizar vida y cosmos"""
	current_life = life
	current_cosmos = cosmos
	_update_display()

func _update_display() -> void:
	"""Actualizar los valores mostrados"""
	if life_label:
		life_label.text = str(current_life)
	if cosmos_label:
		cosmos_label.text = str(current_cosmos)

func set_avatar(texture: Texture2D) -> void:
	"""Establecer la imagen del avatar"""
	if avatar_rect:
		avatar_rect.texture = texture
