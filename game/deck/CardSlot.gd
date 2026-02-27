# CardSlot.gd (PRO - Segun chat)
# Espacio donde se puede colocar una carta. Validación externa (GameRules/MatchController)
extends Control
class_name CardSlot

# Signals
signal card_dropped(payload: Dictionary)
signal card_clicked(card_data: Dictionary)
signal card_placed(slot: CardSlot, card_display: Control)
signal card_double_clicked(card_data)
signal knight_right_clicked(slot: CardSlot)
signal slot_clicked(slot: CardSlot)

enum SlotType { KNIGHT, TECH_OBJECT, HELPER, SCENARIO, OCCASION }

@export var slot_type: SlotType = SlotType.KNIGHT
@export var slot_index: int = 0
@export var is_opponent: bool = false
@export var highlight_on_hover: bool = true

# Optional path to an external validator node (MatchController, GameRules, etc.)
# Si está configurado, llamaremos a node.can_play_card(card_instance, target_slot)
@export var validator_node_path: NodePath = NodePath("")

# Estado
var card_instance: CardInstance = null           # CardInstance real (si aplica)
var card_display_node: Control = null            # UI node (CardDisplay)
var is_occupied: bool = false

# Drag tracking (sistema manual sin get_drag_data)
var _current_dragging_card: Control = null       # CardDisplay que está siendo arrastrada
var _is_mouse_over: bool = false                 # Detectar si el cursor está sobre este slot
var _drag_valid: bool = false                    # ¿Es válido droppear aquí?

# Watermark (tipo de slot)
var watermark_label: Label = null

# Shared styles (evitar instanciar repetido)
static var _hover_style: StyleBoxFlat = null
static var _glow_style_cache := {}  # color_str -> StyleBoxFlat
static var _valid_drag_style: StyleBoxFlat = null   # Verde para drop válido
static var _invalid_drag_style: StyleBoxFlat = null # Rojo para drop inválido

# ====================================================
# READY
# ====================================================
func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Tamaño fijo desde CardSizeConfig (no se estira en el HBoxContainer)
	var card_size := Vector2(CardSizeConfig.card_width, CardSizeConfig.card_height)
	custom_minimum_size = card_size
	size = card_size
	size_flags_horizontal = 0  # No expandir
	size_flags_vertical = 0
	
	_create_watermark()
	_init_shared_styles()
	if highlight_on_hover:
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)


func _process(_delta: float) -> void:
	"""Detectar si hay un drag en progreso sobre este slot"""
	if _current_dragging_card == null:
		return
	
	# Si el drag está activo, verificar si el cursor está dentro del rect de este slot
	# No confiar en mouse_entered/exited porque la carta está encima del cursor
	if _current_dragging_card.current_state == _current_dragging_card.DraggableState.HOLDING:
		var mouse_pos = get_local_mouse_position()
		var slot_rect = Rect2(Vector2.ZERO, size)
		
		# Chequear si el mouse está dentro de los bounds del slot
		var is_mouse_inside = slot_rect.has_point(mouse_pos)
		
		# Actualizar estado visual si cambió
		if is_mouse_inside != _is_mouse_over:
			_is_mouse_over = is_mouse_inside
			if _is_mouse_over:
				_update_drag_glow()
			else:
				remove_theme_stylebox_override("panel")

# ====================================================
# SHARED STYLES
# ====================================================
func _init_shared_styles():
	# Borde por defecto (siempre visible)
	if not _glow_style_cache.has("default"):
		var default_style := StyleBoxFlat.new()
		default_style.bg_color = Color(0, 0, 0, 0.25)
		default_style.border_color = Color(0.4, 0.4, 0.5, 0.7)
		default_style.border_width_left = 2
		default_style.border_width_right = 2
		default_style.border_width_top = 2
		default_style.border_width_bottom = 2
		default_style.corner_radius_top_left = 4
		default_style.corner_radius_top_right = 4
		default_style.corner_radius_bottom_left = 4
		default_style.corner_radius_bottom_right = 4
		_glow_style_cache["default"] = default_style
	add_theme_stylebox_override("panel", _glow_style_cache["default"])
	queue_redraw()

	if _hover_style == null:
		_hover_style = StyleBoxFlat.new()
		_hover_style.bg_color = Color(1, 1, 1, 0.12)
		_hover_style.border_color = Color(0, 1, 0, 0.55)
		_hover_style.border_width_left = 2
		_hover_style.border_width_right = 2
		_hover_style.border_width_top = 2
		_hover_style.border_width_bottom = 2
	
	# ✅ Verde para drop válido
	if _valid_drag_style == null:
		_valid_drag_style = StyleBoxFlat.new()
		_valid_drag_style.bg_color = Color(0, 1, 0, 0.25)      # Verde translúcido
		_valid_drag_style.border_color = Color(0, 1, 0, 1.0)   # Verde brillante
		_valid_drag_style.border_width_left = 3
		_valid_drag_style.border_width_right = 3
		_valid_drag_style.border_width_top = 3
		_valid_drag_style.border_width_bottom = 3
		_valid_drag_style.shadow_color = Color(0, 1, 0, 0.6)
		_valid_drag_style.shadow_size = 4
	
	# ❌ Rojo para drop inválido
	if _invalid_drag_style == null:
		_invalid_drag_style = StyleBoxFlat.new()
		_invalid_drag_style.bg_color = Color(1, 0, 0, 0.15)      # Rojo translúcido
		_invalid_drag_style.border_color = Color(1, 0, 0, 1.0)   # Rojo brillante
		_invalid_drag_style.border_width_left = 3
		_invalid_drag_style.border_width_right = 3
		_invalid_drag_style.border_width_top = 3
		_invalid_drag_style.border_width_bottom = 3
		_invalid_drag_style.shadow_color = Color(1, 0, 0, 0.4)
		_invalid_drag_style.shadow_size = 4

func _draw() -> void:
	"""Control no dibuja panel stylebox automáticamente, hay que hacerlo manual"""
	var style := get_theme_stylebox("panel")
	if style:
		draw_style_box(style, Rect2(Vector2.ZERO, size))

func _make_glow_style(color: Color) -> StyleBoxFlat:	
	var key := "%f-%f-%f-%f" % [color.r, color.g, color.b, color.a]
	if _glow_style_cache.has(key):
		return _glow_style_cache[key]
	var s := StyleBoxFlat.new()
	s.bg_color = Color(color.r, color.g, color.b, 0.28)
	s.border_color = color
	s.border_width_left = 3
	s.border_width_right = 3
	s.border_width_top = 3
	s.border_width_bottom = 3
	s.shadow_color = color
	s.shadow_size = 6
	_glow_style_cache[key] = s
	return s

# ====================================================
# WATERMARK
# ====================================================
func _create_watermark():
	watermark_label = Label.new()
	add_child(watermark_label)
	watermark_label.anchor_left = 0.5
	watermark_label.anchor_top = 0.5
	watermark_label.anchor_right = 0.5
	watermark_label.anchor_bottom = 0.5
	watermark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	watermark_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	watermark_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var text := ""
	var color := Color(1, 1, 1, 0.9)
	match slot_type:
		SlotType.KNIGHT:
			text = "K"
			color = Color(1.0, 0.8, 0.0, 0.95)
		SlotType.TECH_OBJECT:
			text = "T/O"
			color = Color(0.3, 0.5, 1, 0.95)
		SlotType.HELPER:
			text = "H"
			color = Color(0.2, 1, 0.4, 0.95)
		SlotType.SCENARIO:
			text = "S"
			color = Color(1, 0.3, 1, 0.95)
		SlotType.OCCASION:
			text = "O"
			color = Color(1, 0.5, 0, 0.95)

	watermark_label.text = text
	watermark_label.add_theme_color_override("font_color", color)
	watermark_label.add_theme_font_size_override("font_size", 110)
	watermark_label.add_theme_constant_override("outline_size", 6)
	watermark_label.z_index = -1
	watermark_label.visible = true

# ====================================================
# INPUT (clics)
# ====================================================
func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_RIGHT:
		if slot_type == SlotType.KNIGHT and is_occupied and not is_opponent:
			emit_signal("knight_right_clicked", self)
		return

	if event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("slot_clicked", self)
		if is_occupied:
			# Emitir info útil: card data y CardInstance si está
			var payload := {}
			if card_display_node and card_display_node.has_method("get_card_data"):
				payload["card_data"] = card_display_node.get_card_data()
			else:
				payload["card_data"] = {}
			payload["card_instance"] = card_instance
			emit_signal("card_clicked", payload)

# ====================================================
# DROP API (drag & drop)
# ====================================================
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# Data defensiva
	if not data is Dictionary:
		print("[CardSlot:%s] ❌ _can_drop_data: data no es Dictionary" % self.name)
		return false

	print("[CardSlot:%s] 🔍 _can_drop_data: LLAMADO - evaluando..." % self.name)

	# no drops to opponent slots
	if is_opponent:
		print("[CardSlot:%s] ❌ es slot de oponente" % self.name)
		return false

	# If there is a validator node (MatchController/GameRules), prefer it
	var validator := _get_validator_node()
	if validator != null:
		# incoming_inst: CardInstance?
		var incoming_inst: CardInstance = data.get("card_instance", null)

		# Fallback: resolve from CardDisplay
		if incoming_inst == null and data.has("card_display"):
			var cd: Node = data["card_display"]
			if cd and cd.has_method("get_instance"):
				incoming_inst = cd.get_instance()

		# If validator provides can_play_card(instance, slot) call it
		if incoming_inst != null and validator.has_method("can_play_card"):
			return validator.can_play_card(incoming_inst, self)

	# Fallback: simple type-based validation (fast, local)
	if not data.has("card_type"):
		print("[CardSlot:%s] ❌ sin card_type" % self.name)
		return false

	var card_type: String = str(data["card_type"])
	print("[CardSlot:%s] card_type=%s, slot_type=%s" % [self.name, card_type, slot_type])

	match slot_type:
		SlotType.KNIGHT:
			var result = card_type == "knight" and not is_occupied
			print("[CardSlot:%s] KNIGHT: result=%s (type_ok=%s, not_occupied=%s)" % [self.name, result, card_type == "knight", not is_occupied])
			return result
		SlotType.TECH_OBJECT:
			var result = (card_type == "technique" or card_type == "object") and not is_occupied
			print("[CardSlot:%s] TECH: result=%s" % [self.name, result])
			return result
		SlotType.HELPER:
			var result = card_type == "helper" and not is_occupied
			return result
		SlotType.SCENARIO:
			var result = card_type == "scenario" and not is_occupied
			return result
		SlotType.OCCASION:
			return true

	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	print("[CardSlot:%s] 🎯 _drop_data: LLAMADO" % self.name)
	if not (data is Dictionary and data.has("card_display")):
		print("[CardSlot:%s] ❌ _drop_data: data inválida" % self.name)
		return

	# prepare payload
	var payload := {}
	payload["card_display"] = data["card_display"]
	payload["card_instance"] = data.get("card_instance", null)
	payload["card_type"] = data.get("card_type", "")
	payload["source_slot"] = data.get("source_slot", null)
	payload["target_slot"] = self
	payload["slot_type"] = slot_type
	payload["slot_index"] = slot_index

	print("[CardSlot:%s] ✅ Emitiendo card_dropped" % self.name)
	# place card visually (UI) and update internal state
	place_card(payload["card_display"])
	emit_signal("card_dropped", payload)

# ====================================================
# PLACEMENT / CLEAR
# ====================================================
func place_card(card_display: Control, animate: bool = true) -> void:
	"""Coloca visualmente la carta y actualiza card_instance"""
	# if occupied, clear first (animation included)
	if is_occupied:
		clear()

	# extract instance and data defensively
	var incoming_instance: CardInstance = null
	if card_display and card_display.has_method("get_instance"):
		incoming_instance = card_display.get_instance()

	# If card_display exposes get_card_data, store a lightweight copy for UI signals
	var _card_data := {}
	if card_display and card_display.has_method("get_card_data"):
		_card_data = card_display.get_card_data()

	# assign internal state
	card_instance = incoming_instance
	card_display_node = card_display
	is_occupied = true

	# reparent & center at natural card size (120x168)
	if card_display.get_parent():
		card_display.get_parent().remove_child(card_display)
	add_child(card_display)
	card_display.set_anchors_preset(Control.PRESET_TOP_LEFT)
	card_display.reset_size()
	# position deferred so the slot has its final size from the container layout
	call_deferred("_reposition_card")
	if not resized.is_connected(_reposition_card):
		resized.connect(_reposition_card)

	# Deshabilitar drag para cartas en campo (ninguna carta en slot es arrastrable)
	card_display.dragging_enabled = false

	# connect double-click forwarding
	if card_display.has_signal("card_double_clicked"):
		if not card_display.card_double_clicked.is_connected(_on_card_double_clicked):
			card_display.card_double_clicked.connect(_on_card_double_clicked)

	# hide watermark
	if watermark_label:
		watermark_label.visible = false

	# feedback
	if animate and has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_card_place()

	# animate and emit
	if animate:
		animate_card_entrance()
	emit_signal("card_placed", self, card_display)

func _reposition_card() -> void:
	"""Centrar card_display_node en el slot según el tamaño actual del slot"""
	if card_display_node and is_instance_valid(card_display_node):
		card_display_node.position = ((size - card_display_node.size) / 2).round()

func clear() -> void:
	"""Quita la carta del slot con animación. No asume ownership extra."""
	if card_display_node and is_instance_valid(card_display_node):
		animate_card_exit()
		# esperar un poco para que la animación termine antes de free
		await get_tree().create_timer(0.18).timeout
		if card_display_node and is_instance_valid(card_display_node):
			card_display_node.queue_free()

	card_display_node = null
	card_instance = null
	is_occupied = false

	if resized.is_connected(_reposition_card):
		resized.disconnect(_reposition_card)

	if watermark_label:
		watermark_label.visible = true

# ====================================================
# ANIMACIONES
# ====================================================
func animate_card_entrance() -> void:
	if not (card_display_node and is_instance_valid(card_display_node)):
		return
	card_display_node.modulate.a = 0.0
	card_display_node.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(card_display_node, "modulate:a", 1.0, 0.32).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(card_display_node, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func animate_card_exit() -> void:
	if not (card_display_node and is_instance_valid(card_display_node)):
		return
	var tw := create_tween()
	tw.tween_property(card_display_node, "modulate:a", 0.0, 0.18)
	tw.tween_property(card_display_node, "scale", Vector2(0.5, 0.5), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished

# ====================================================
# HOVER / GLOW / DRAG VISUAL FEEDBACK
# ====================================================
func _on_mouse_entered() -> void:
	_is_mouse_over = true
	
	# Si hay un drag en progreso, aplicar glow de validez
	if _current_dragging_card != null:
		_update_drag_glow()
	elif not is_occupied and not is_opponent:
		# Hover normal (sin drag)
		add_theme_stylebox_override("panel", _hover_style)
		queue_redraw()


func _on_mouse_exited() -> void:
	_is_mouse_over = false
	# Remover cualquier estilo de drag
	remove_theme_stylebox_override("panel")
	add_theme_stylebox_override("panel", _glow_style_cache["default"])
	queue_redraw()


func _update_drag_glow() -> void:
	"""Actualizar el glow visual según validez del drag"""
	if _drag_valid:
		# ✅ Verde: drop válido
		add_theme_stylebox_override("panel", _valid_drag_style)
		print("[CardSlot:%s] 🟢 Glow VÁLIDO (drop permitido)" % self.name)
	else:
		# ❌ Rojo: drop inválido
		add_theme_stylebox_override("panel", _invalid_drag_style)
		print("[CardSlot:%s] 🔴 Glow INVÁLIDO (drop bloqueado)" % self.name)
	queue_redraw()


# ====================================================
# MANUAL DRAG-DROP (Sin get_drag_data)
# ====================================================
func notify_card_drag_started(card_display: Control, card_data: Dictionary) -> void:
	"""CardDisplay llama esto cuando comienza el drag
	
	Validar tipo de carta y aplicar glow visual (verde=válido, rojo=inválido)
	"""
	_current_dragging_card = card_display
	var card_type: String = card_data.get("type", "")
	
	# Validar si este slot acepta este tipo de carta
	_drag_valid = _validate_card_type(card_type) and not is_occupied
	
	print("[CardSlot:%s] 📍 Drag iniciado: %s (válido=%s)" % [self.name, card_data.get("name", "?"), _drag_valid])
	
	# Aplicar glow visual solo si el cursor está sobre nosotros
	if _is_mouse_over:
		_update_drag_glow()


func notify_card_drag_ended() -> void:
	"""CardDisplay llama esto cuando termina el drag
	
	Detectar drop usando Rect2 check, no solo mouse_entered/exited
	(mouse_entered/exited no se disparan cuando hay un objeto encima)
	"""
	# Verificar si el cursor está dentro del slot usando rect check
	var mouse_pos = get_local_mouse_position()
	var slot_rect = Rect2(Vector2.ZERO, size)
	var cursor_is_over = slot_rect.has_point(mouse_pos)
	
	# Procesar drop si cursor está sobre el slot y hay una carta siendo arrastrada
	if cursor_is_over and _current_dragging_card != null:
		_process_drop()
	elif not cursor_is_over and _current_dragging_card != null:
		print("[CardSlot:%s] ❌ Drop cancelado - cursor fuera del slot" % self.name)
	
	_current_dragging_card = null
	_is_mouse_over = false
	remove_theme_stylebox_override("panel")
	add_theme_stylebox_override("panel", _glow_style_cache["default"])
	queue_redraw()
	print("[CardSlot:%s] 📍 Drag finalizado" % self.name)


func _process_drop() -> void:
	"""Procesar el drop de una carta"""
	if _current_dragging_card == null:
		print("[CardSlot:%s] ❌ Sin carta para dropear" % self.name)
		return
	
	# Obtener datos de la carta
	var card_display: CardDisplay = _current_dragging_card as CardDisplay
	if card_display == null:
		print("[CardSlot:%s] ❌ Card display no es CardDisplay" % self.name)
		return
	
	var card_data = card_display.get_data()
	if card_data == null:
		print("[CardSlot:%s] ❌ Sin card_data" % self.name)
		return
	
	var card_type: String = card_data.get("type", "")
	
	# Validar tipo de carta
	print("[CardSlot:%s] 🔍 Validando tipo %s para slot %s" % [self.name, card_type, slot_type])
	
	if not _validate_card_type(card_type):
		print("[CardSlot:%s] ❌ Tipo de carta %s no válido para este slot" % [self.name, card_type])
		return
	
	if is_occupied:
		print("[CardSlot:%s] ❌ Slot ocupado" % self.name)
		return
	
	# ✅ Validación pasada - emitir el drop
	print("[CardSlot:%s] ✅ DROP ACEPTADO" % self.name)
	
	var payload = {
		"card_display": card_display,
		"card_instance": card_display.get_instance() if card_display.has_method("get_instance") else null,
		"card_type": card_type,
		"target_slot": self,
		"slot_type": slot_type,
		"slot_index": slot_index
	}
	
	card_dropped.emit(payload)


func _validate_card_type(card_type: String) -> bool:
	"""Validar si el tipo de carta es compatible con este slot"""
	match slot_type:
		SlotType.KNIGHT:
			return card_type == "knight"
		SlotType.TECH_OBJECT:
			return card_type == "technique" or card_type == "object"
		SlotType.HELPER:
			return card_type == "helper"
		SlotType.SCENARIO:
			return card_type == "scenario"
		SlotType.OCCASION:
			return card_type == "occasion"
	return false

func set_glow(enabled: bool, color: Color = Color(1, 0.8, 0.1)):
	if enabled:
		add_theme_stylebox_override("panel", _make_glow_style(color))
	else:
		add_theme_stylebox_override("panel", _glow_style_cache.get("default"))
	queue_redraw()

# ====================================================
# UTIL / SIGNAL FORWARD
# ====================================================
func _on_card_double_clicked(card_data) -> void:
	emit_signal("card_double_clicked", card_data)

# Try to resolve a validator node (explicit path or common autoloads)
func _get_validator_node() -> Node:
	# explicit path
	if validator_node_path != NodePath(""):
		if has_node(validator_node_path):
			return get_node(validator_node_path)
	# common autoloads
	if Engine.has_singleton("MatchController"):
		return Engine.get_singleton("MatchController")
	if has_node("/root/MatchController"):
		return get_node("/root/MatchController")
	if has_node("/root/GameRules"):
		return get_node("/root/GameRules")
	return null
