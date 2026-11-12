# PlayerStatusPanel.gd
# Retrato del jugador en el tablero: avatar con su nombre, insignia grande con la vida
# y una fila de gemas de cosmo (una por punto, hasta el máximo de la partida).
# Se construye por código; la API (setup/update_*/set_active_turn) es la que usan
# StatusPanelController y TurnController.
extends Control
class_name PlayerStatusPanel

const MAX_COSMOS := 12  ## BASE_MATCH_RULES.max_cosmos del servidor
const AVATAR_SIZE := 78.0
const GEM_SIZE := 15.0
const DEFAULT_AVATAR := "res://assets/ui-icons/lobby/profile.svg"
const CIRCLE_MASK := preload("res://assets/shaders/circle_mask.gdshader")

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

var _frame: PanelContainer
var _frame_style: StyleBoxFlat
var _avatar: TextureRect
var _name_label: Label
var _turn_label: Label
var _life_badge: Label
var _cosmos_label: Label
var _gems: Array[Panel] = []
var _gem_on: StyleBoxFlat
var _gem_off: StyleBoxFlat

# Tween para indicador de turno activo
var _turn_tween: Tween = null


# ============================================================================
# CICLO DE VIDA
# ============================================================================
func _ready() -> void:
	custom_minimum_size = Vector2(260, 150)
	_build()
	_refresh_life(false)
	_refresh_cosmos(false)


func _build() -> void:
	_frame = PanelContainer.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame_style = StyleBoxFlat.new()
	_frame_style.bg_color = UIPalette.alpha(UIPalette.ABYSS, 0.82)
	_frame_style.border_color = UIPalette.alpha(UIPalette.EDGE, 0.45)
	_frame_style.set_border_width_all(2)
	_frame_style.set_corner_radius_all(18)
	_frame_style.content_margin_left = 12
	_frame_style.content_margin_right = 12
	_frame_style.content_margin_top = 10
	_frame_style.content_margin_bottom = 10
	_frame_style.shadow_color = Color(0, 0, 0, 0.45)
	_frame_style.shadow_size = 12
	_frame_style.anti_aliasing = true
	_frame.add_theme_stylebox_override("panel", _frame_style)
	add_child(_frame)
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)

	# Avatar redondo con aro y la vida encima, abajo a la derecha
	var avatar_holder := Control.new()
	avatar_holder.custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	avatar_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(avatar_holder)

	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = UIPalette.PANEL
	ring_style.border_color = UIPalette.GOLD if not is_opponent else UIPalette.alpha(UIPalette.LIFE, 0.9)
	ring_style.set_border_width_all(3)
	ring_style.set_corner_radius_all(int(AVATAR_SIZE))
	ring_style.anti_aliasing = true
	ring.add_theme_stylebox_override("panel", ring_style)
	avatar_holder.add_child(ring)
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_avatar = TextureRect.new()
	_avatar.texture = load(DEFAULT_AVATAR)
	_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask := ShaderMaterial.new()
	mask.shader = CIRCLE_MASK
	mask.set_shader_parameter("smoothness", 0.04)
	_avatar.material = mask
	avatar_holder.add_child(_avatar)
	_avatar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_avatar.offset_left = 4
	_avatar.offset_top = 4
	_avatar.offset_right = -4
	_avatar.offset_bottom = -4

	_life_badge = Label.new()
	_life_badge.theme_type_variation = &"StatValue"
	_life_badge.add_theme_font_size_override("font_size", 30)
	_life_badge.add_theme_color_override("font_color", Color.WHITE)
	_life_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_life_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_life_badge.tooltip_text = "Vida"
	var life_style := StyleBoxFlat.new()
	life_style.bg_color = UIPalette.LIFE.darkened(0.1)
	life_style.border_color = Color.WHITE
	life_style.set_border_width_all(3)
	life_style.set_corner_radius_all(30)
	life_style.shadow_color = Color(0, 0, 0, 0.5)
	life_style.shadow_size = 6
	life_style.anti_aliasing = true
	_life_badge.add_theme_stylebox_override("normal", life_style)
	avatar_holder.add_child(_life_badge)
	_life_badge.position = Vector2(AVATAR_SIZE - 34, AVATAR_SIZE - 34)
	_life_badge.size = Vector2(50, 50)

	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", -4)
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(names)

	_turn_label = Label.new()
	_turn_label.theme_type_variation = &"Eyebrow"
	_turn_label.add_theme_font_size_override("font_size", 15)
	_turn_label.text = "RIVAL" if is_opponent else "TÚ"
	names.add_child(_turn_label)

	_name_label = Label.new()
	_name_label.theme_type_variation = &"TitleLabel"
	_name_label.add_theme_font_size_override("font_size", 28)
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.clip_text = true
	names.add_child(_name_label)

	# Cosmo: una gema por punto (2 filas de 6) y el número al lado
	var cosmos_row := HBoxContainer.new()
	cosmos_row.add_theme_constant_override("separation", 10)
	cosmos_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cosmos_row.tooltip_text = "Cosmo"
	column.add_child(cosmos_row)

	var grid := GridContainer.new()
	grid.columns = MAX_COSMOS / 2
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cosmos_row.add_child(grid)

	_gem_on = StyleBoxFlat.new()
	_gem_on.bg_color = UIPalette.COSMOS
	_gem_on.border_color = Color(0.85, 0.92, 1.0)
	_gem_on.set_border_width_all(2)
	_gem_on.set_corner_radius_all(4)
	_gem_on.skew = Vector2(0.25, 0)
	_gem_on.shadow_color = UIPalette.alpha(UIPalette.COSMOS, 0.7)
	_gem_on.shadow_size = 5
	_gem_off = _gem_on.duplicate()
	_gem_off.bg_color = UIPalette.alpha(UIPalette.COSMOS, 0.12)
	_gem_off.border_color = UIPalette.alpha(UIPalette.COSMOS, 0.35)
	_gem_off.shadow_size = 0
	for i in MAX_COSMOS:
		var gem := Panel.new()
		gem.custom_minimum_size = Vector2(GEM_SIZE, GEM_SIZE)
		gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gem.add_theme_stylebox_override("panel", _gem_off)
		grid.add_child(gem)
		_gems.append(gem)

	_cosmos_label = Label.new()
	_cosmos_label.theme_type_variation = &"StatValue"
	_cosmos_label.add_theme_font_size_override("font_size", 30)
	_cosmos_label.add_theme_color_override("font_color", UIPalette.COSMOS.lightened(0.35))
	_cosmos_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cosmos_row.add_child(_cosmos_label)


# ============================================================================
# MÉTODOS PÚBLICOS
# ============================================================================
func setup(new_player_name: String, life: int, cosmos: int, user_id: String = "") -> void:
	"""Configurar panel con datos del jugador y cargar avatar desde servidor"""
	player_name = new_player_name
	if _name_label:
		_name_label.text = new_player_name

	# Si ya está inicializado con el mismo usuario, solo actualizar vida y cosmos
	if not player_id.is_empty() and player_id == user_id:
		update_both(life, cosmos)
		return

	current_life = life
	current_cosmos = cosmos
	player_id = user_id
	_refresh_life(false)
	_refresh_cosmos(false)

	# Si hay user_id, cargar avatar del servidor (solo la primera vez)
	if not user_id.is_empty():
		_load_avatar_from_server(user_id)


func update_life(new_life: int) -> void:
	var animate := new_life != current_life
	var lost := new_life < current_life
	current_life = new_life
	_refresh_life(animate, lost)


func update_cosmos(new_cosmos: int) -> void:
	var animate := new_cosmos != current_cosmos
	current_cosmos = new_cosmos
	_refresh_cosmos(animate)


func update_both(new_life: int, new_cosmos: int) -> void:
	update_life(new_life)
	update_cosmos(new_cosmos)


func set_active_turn(active: bool) -> void:
	"""Resalta el retrato del jugador al que le toca y apaga el otro"""
	if _turn_tween and is_instance_valid(_turn_tween):
		_turn_tween.kill()
		_turn_tween = null
	if not _frame_style:
		return

	if active:
		_frame_style.border_color = UIPalette.GOLD
		_frame_style.shadow_color = UIPalette.alpha(UIPalette.GOLD, 0.45)
		_frame_style.shadow_size = 18
		_turn_label.text = "TU TURNO" if not is_opponent else "TURNO DEL RIVAL"
		_turn_label.add_theme_color_override("font_color", UIPalette.GOLD_LIGHT)
		modulate = Color.WHITE
		# Halo que respira mientras dura el turno
		_turn_tween = create_tween().set_loops()
		_turn_tween.tween_property(_frame_style, "shadow_size", 26, 0.9).set_trans(Tween.TRANS_SINE)
		_turn_tween.tween_property(_frame_style, "shadow_size", 14, 0.9).set_trans(Tween.TRANS_SINE)
	else:
		_frame_style.border_color = UIPalette.alpha(UIPalette.EDGE, 0.45)
		_frame_style.shadow_color = Color(0, 0, 0, 0.45)
		_frame_style.shadow_size = 12
		_turn_label.text = "RIVAL" if is_opponent else "TÚ"
		_turn_label.remove_theme_color_override("font_color")
		modulate = Color(0.82, 0.8, 0.9)
	_frame.queue_redraw()


# ============================================================================
# PINTADO
# ============================================================================
func _refresh_life(animate: bool, lost := false) -> void:
	if not _life_badge:
		return
	_life_badge.text = str(current_life)
	if not animate:
		return
	# Golpe: la insignia salta y el retrato tiembla; curación: salto verde
	_life_badge.pivot_offset = _life_badge.size / 2.0
	var flash := UIPalette.LIFE.lightened(0.4) if lost else UIPalette.HEAL
	var pop := create_tween()
	pop.tween_property(_life_badge, "scale", Vector2(1.6, 1.6), 0.1).set_trans(Tween.TRANS_QUAD)
	pop.parallel().tween_property(_life_badge, "modulate", flash, 0.1)
	pop.tween_property(_life_badge, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.parallel().tween_property(_life_badge, "modulate", Color.WHITE, 0.3)
	if lost:
		var origin := _frame.position
		var shake := create_tween()
		for offset in [Vector2(9, 0), Vector2(-7, 0), Vector2(4, 0), Vector2.ZERO]:
			shake.tween_property(_frame, "position", origin + offset, 0.04)


func _refresh_cosmos(animate: bool) -> void:
	if _gems.is_empty():
		return
	var lit := clampi(current_cosmos, 0, MAX_COSMOS)
	for i in _gems.size():
		var on := i < lit
		var gem := _gems[i]
		var was_on := gem.get_theme_stylebox("panel") == _gem_on
		gem.add_theme_stylebox_override("panel", _gem_on if on else _gem_off)
		if animate and on and not was_on:
			# Las gemas nuevas se encienden con un pequeño salto, una tras otra
			gem.pivot_offset = gem.size / 2.0
			gem.scale = Vector2(0.3, 0.3)
			create_tween().tween_property(gem, "scale", Vector2.ONE, 0.25) \
				.set_delay(0.04 * (i % 6)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_cosmos_label.text = str(current_cosmos)


# ============================================================================
# AVATAR
# ============================================================================
func _load_avatar_from_server(user_id: String) -> void:
	"""Cargar avatar del servidor para un usuario específico"""
	var callback = func(success: bool, data: Variant, error: String) -> void:
		if success and data is Dictionary:
			var avatar = data.get("avatar", {})
			var image_url = avatar.get("image_url", "") if avatar is Dictionary else ""
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
	var target: WeakRef = weakref(self)
	var callback = func(image: Image, _tag = null) -> void:
		if image and target.get_ref() and _avatar:
			_avatar.texture = ImageTexture.create_from_image(image)

	ApiClient.get_image_with_callback(
		image_url,
		callback,
		"avatar_image_%s" % player_name
	)
