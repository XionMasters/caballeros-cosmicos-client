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

# Target highlight (selección de objetivo — reutilizable para ataque, buff, etc.)
var _highlight_color: Color = Color.TRANSPARENT
var _highlight_tween: Tween = null

# Drag tracking (sistema manual sin get_drag_data)
var _current_dragging_card: Control = null       # CardDisplay que está siendo arrastrada
var _is_mouse_over: bool = false                 # Detectar si el cursor está sobre este slot
var _drag_valid: bool = false                    # ¿Es válido droppear aquí?
var _equip_mode: bool = false                    # Se arrastra un objeto: se equipa soltándolo sobre un caballero
var _drop_overlay: Panel = null                  # Resaltado encima de la carta (posiciones ocupadas)

# Watermark (tipo de slot): icono + rótulo, visible solo con la posición vacía
var watermark_label: Control = null

# Shared styles (evitar instanciar repetido)
static var _hover_style: StyleBoxFlat = null
static var _glow_style_cache := {}  # color_str / "default_<tipo>" -> StyleBoxFlat
static var _valid_drag_style: StyleBoxFlat = null     # Cian: el cursor está sobre un destino válido
static var _invalid_drag_style: StyleBoxFlat = null   # Naranja: destino no válido
static var _available_drag_style: StyleBoxFlat = null # Cian tenue: destino válido mientras se arrastra

## Icono de cada tipo de posición vacía
const SLOT_ICONS := {
	SlotType.KNIGHT: "res://assets/ui-icons/lobby/battle.svg",
	SlotType.TECH_OBJECT: "res://assets/ui-icons/lobby/flame.svg",
	SlotType.HELPER: "res://assets/ui-icons/lobby/users.svg",
	SlotType.SCENARIO: "res://assets/ui-icons/lobby/sanctuary.svg",
	SlotType.OCCASION: "res://assets/ui-icons/lobby/news.svg",
}

# ====================================================
# READY
# ====================================================
func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Tamaño fijo desde CardSizeConfig (no se estira en el HBoxContainer)
	var card_size := get_card_size()
	custom_minimum_size = card_size
	size = card_size
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # No expandir; centrado en columnas
	size_flags_vertical = 0

	_create_watermark()
	_init_shared_styles()
	if highlight_on_hover:
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)


## Tamaño de la carta en esta posición: las de caballero son las grandes
func get_card_size() -> Vector2:
	if slot_type == SlotType.KNIGHT:
		return CardSizeConfig.get_card_size()
	return CardSizeConfig.get_support_slot_size()


func _slot_color() -> Color:
	match slot_type:
		SlotType.KNIGHT: return UIPalette.GOLD
		SlotType.TECH_OBJECT: return UIPalette.COSMOS
		SlotType.HELPER: return UIPalette.HEAL
		SlotType.SCENARIO: return UIPalette.ABILITY
		SlotType.OCCASION: return UIPalette.POWER
	return UIPalette.GOLD


## Estilo en reposo: cristal oscuro con el borde del color de su tipo
func _default_style() -> StyleBoxFlat:
	var key := "default_%d_%s" % [slot_type, is_opponent]
	if not _glow_style_cache.has(key):
		var s := StyleBoxFlat.new()
		s.bg_color = UIPalette.alpha(UIPalette.ABYSS, 0.55)
		s.border_color = UIPalette.alpha(_slot_color(), 0.22 if is_opponent else 0.38)
		s.set_border_width_all(2)
		s.set_corner_radius_all(12)
		s.anti_aliasing = true
		_glow_style_cache[key] = s
	return _glow_style_cache[key]


## Estilo cuando no pasa nada encima: tenue si es destino válido de un arrastre, si no el de reposo
func _rest_style() -> StyleBoxFlat:
	if _current_dragging_card != null and _drag_valid:
		return _available_drag_style
	return _default_style()


func _set_style(style: StyleBox) -> void:
	add_theme_stylebox_override("panel", style)
	queue_redraw()
	_update_drop_overlay(style)


## Con una carta en la posición, el borde del slot queda tapado: el resaltado de
## arrastre (equipar un objeto, reemplazar el escenario) se dibuja encima de la carta.
func _update_drop_overlay(style: StyleBox) -> void:
	var highlight := is_occupied and style in [_available_drag_style, _valid_drag_style, _invalid_drag_style]
	if not highlight:
		if _drop_overlay and is_instance_valid(_drop_overlay):
			_drop_overlay.visible = false
		return
	if _drop_overlay == null or not is_instance_valid(_drop_overlay):
		_drop_overlay = Panel.new()
		_drop_overlay.name = "DropOverlay"
		_drop_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_drop_overlay.z_index = 60
		add_child(_drop_overlay)
		_drop_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(_drop_overlay, -1)
	_drop_overlay.add_theme_stylebox_override("panel", style)
	_drop_overlay.visible = true


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
				_set_style(_rest_style())

# ====================================================
# SHARED STYLES
# ====================================================
func _make_state_style(bg: Color, border: Color, width: int, shadow: Color, shadow_size: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(12)
	s.shadow_color = shadow
	s.shadow_size = shadow_size
	s.anti_aliasing = true
	return s


func _init_shared_styles():
	# Borde por defecto (siempre visible)
	_set_style(_default_style())

	if _hover_style == null:
		_hover_style = _make_state_style(UIPalette.alpha(UIPalette.HIGHLIGHT, 0.4),
			UIPalette.alpha(UIPalette.GOLD_LIGHT, 0.8), 2, Color.TRANSPARENT, 0)

	# Cian tenue: posición válida mientras se arrastra una carta (todas a la vez)
	if _available_drag_style == null:
		_available_drag_style = _make_state_style(UIPalette.alpha(UIPalette.TARGET, 0.1),
			UIPalette.alpha(UIPalette.TARGET, 0.65), 2, UIPalette.alpha(UIPalette.TARGET, 0.25), 8)

	# ✅ Cian intenso: el cursor está sobre una posición válida
	if _valid_drag_style == null:
		_valid_drag_style = _make_state_style(UIPalette.alpha(UIPalette.TARGET, 0.26),
			UIPalette.TARGET, 3, UIPalette.alpha(UIPalette.TARGET, 0.6), 14)

	# ❌ Naranja para drop inválido (se distingue del cian también por luminosidad)
	if _invalid_drag_style == null:
		_invalid_drag_style = _make_state_style(UIPalette.alpha(UIPalette.INVALID, 0.15),
			UIPalette.INVALID, 3, UIPalette.alpha(UIPalette.INVALID, 0.4), 6)

func _draw() -> void:
	"""Control no dibuja panel stylebox automáticamente, hay que hacerlo manual"""
	var style := get_theme_stylebox("panel")
	if style:
		draw_style_box(style, Rect2(Vector2.ZERO, size))
	# Overlay parpadeante de selección de objetivo
	if _highlight_color.a > 0.01:
		draw_rect(Rect2(Vector2.ZERO, size), _highlight_color, true)
		var border_c := Color(_highlight_color.r, _highlight_color.g, _highlight_color.b,
				minf(_highlight_color.a * 1.6, 1.0))
		draw_rect(Rect2(Vector2.ZERO, size), border_c, false, 3.0)

func _make_glow_style(color: Color) -> StyleBoxFlat:	
	var key := "%f-%f-%f-%f" % [color.r, color.g, color.b, color.a]
	if _glow_style_cache.has(key):
		return _glow_style_cache[key]
	var s := _make_state_style(Color(color.r, color.g, color.b, 0.28), color, 3, color, 10)
	_glow_style_cache[key] = s
	return s

# ====================================================
# TARGET HIGHLIGHT  (selección de objetivo)
# ====================================================
func set_target_highlight(active: bool, color: Color = UIPalette.LIFE) -> void:
	"""Activa/desactiva el overlay parpadeante para indicar objetivo válido.
	Reutilizable para cualquier acción: ataque (rojo), buff (verde), mover (azul), etc."""
	if _highlight_tween:
		_highlight_tween.kill()
		_highlight_tween = null

	if not active:
		_highlight_color = Color.TRANSPARENT
		queue_redraw()
		return

	# Pulso suave: 0.75 → 0.08 → 0.75, en bucle
	_highlight_tween = create_tween().set_loops()
	_highlight_tween.tween_method(
		func(a: float) -> void:
			_highlight_color = Color(color.r, color.g, color.b, a)
			queue_redraw(),
		0.75, 0.08, 0.42
	)
	_highlight_tween.tween_method(
		func(a: float) -> void:
			_highlight_color = Color(color.r, color.g, color.b, a)
			queue_redraw(),
		0.08, 0.75, 0.42
	)

# ====================================================
# WATERMARK
# ====================================================
func _create_watermark():
	"""Icono y rótulo de la posición vacía (qué tipo de carta va ahí). Se oculta al colocar una carta."""
	var text := ""
	match slot_type:
		SlotType.KNIGHT: text = "CABALLERO"
		SlotType.TECH_OBJECT: text = "TÉCNICA / OBJETO"
		SlotType.HELPER: text = "AYUDANTE"
		SlotType.SCENARIO: text = "ESCENARIO"
		SlotType.OCCASION: text = "OCASIÓN"
	# Discreto: orienta sin competir con las cartas; más tenue en el lado del rival
	var color := UIPalette.alpha(_slot_color(), 0.3 if is_opponent else 0.5)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	watermark_label = box

	var icon := TextureRect.new()
	icon.texture = load(SLOT_ICONS.get(slot_type, SLOT_ICONS[SlotType.KNIGHT]))
	var icon_size := 44.0 if slot_type == SlotType.KNIGHT else 32.0
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.modulate = color
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"Eyebrow"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 14)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)

	watermark_label.visible = not is_occupied

# ====================================================
# INPUT (clics)
# ====================================================
func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_RIGHT:
		# Clic derecho: detalle de la carta (propia o rival)
		if is_occupied and card_instance:
			CardDetailManager.show_instance(card_instance)
			accept_event()
		if slot_type == SlotType.KNIGHT and is_occupied and not is_opponent:
			emit_signal("knight_right_clicked", self)
		return

	if event.button_index == MOUSE_BUTTON_LEFT:
		# Doble clic: detalle de la carta (el primer clic ya hizo su acción normal)
		if event.double_click and is_occupied and card_instance:
			CardDetailManager.show_instance(card_instance)
			accept_event()
			return
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

	var incoming_inst: CardInstance = data.get("card_instance", null)
	if incoming_inst == null and data.has("card_display"):
		var cd: Node = data["card_display"]
		if cd and cd.has_method("get_instance"):
			incoming_inst = cd.get_instance()

	# Lo que dice el servidor manda: valid_actions de la carta de la mano
	# ({ can_play, play_zone, play_slots }). El cliente no calcula reglas.
	if incoming_inst != null and incoming_inst.valid_actions.has("can_play"):
		return _server_allows_drop(incoming_inst.valid_actions)

	# If there is a validator node (MatchController/GameRules), prefer it
	var validator := _get_validator_node()
	if validator != null and incoming_inst != null and validator.has_method("can_play_card"):
		return validator.can_play_card(incoming_inst, self)

	# Fallback: simple type-based validation (fast, local)
	if not data.has("card_type"):
		print("[CardSlot:%s] ❌ sin card_type" % self.name)
		return false

	# Tipos normalizados (knight/technique/item/helper/stage/event): ver _validate_card_type.
	# El escenario y la ocasión se pueden reemplazar aunque la posición esté ocupada.
	var card_type: String = _normalize_card_type(str(data["card_type"]))
	var replaceable := slot_type == SlotType.SCENARIO or slot_type == SlotType.OCCASION
	var result := _validate_card_type(card_type) and (replaceable or not is_occupied)
	print("[CardSlot:%s] card_type=%s, slot_type=%s → %s" % [self.name, card_type, slot_type, result])
	return result

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
	# La carta toma el tamaño de la posición (las de apoyo son más pequeñas que las de mano)
	if card_display.has_method("set_display_size"):
		card_display.set_display_size(get_card_size())
	card_display.scale = Vector2.ONE
	card_display.rotation = 0.0
	card_display.reset_size()
	# position deferred so the slot has its final size from the container layout
	call_deferred("_reposition_card")
	if not resized.is_connected(_reposition_card):
		resized.connect(_reposition_card)

	# Deshabilitar drag para cartas en campo (ninguna carta en slot es arrastrable)
	card_display.dragging_enabled = false
	card_display.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
		_set_style(_hover_style)


func _on_mouse_exited() -> void:
	_is_mouse_over = false
	_set_style(_rest_style())


func _update_drag_glow() -> void:
	"""Actualizar el glow visual según validez del drag"""
	# Cian: drop válido · naranja: drop inválido
	_set_style(_valid_drag_style if _drag_valid else _invalid_drag_style)


# ====================================================
# MANUAL DRAG-DROP (Sin get_drag_data)
# ====================================================
func notify_card_drag_started(card_display: Control, card_data: Dictionary) -> void:
	"""CardDisplay llama esto cuando comienza el drag
	
	Validar tipo de carta y aplicar glow visual (verde=válido, rojo=inválido)
	"""
	_current_dragging_card = card_display
	var card_type: String = card_data.get("type", "")
	card_type = _normalize_card_type(card_type)

	# Validar si este slot acepta esta carta: manda lo que dice el servidor (valid_actions)
	# y, si no lo dice, el tipo de carta
	var instance: CardInstance = card_display.get_instance() if card_display.has_method("get_instance") else null
	var equip_targets = _equip_targets_of(instance)
	_equip_mode = equip_targets != null
	if is_opponent:
		_drag_valid = false
	elif _equip_mode:
		# Objeto: solo valen los caballeros propios a los que el servidor permite equiparlo
		_drag_valid = slot_type == SlotType.KNIGHT and is_occupied and card_instance != null \
			and bool(instance.valid_actions.get("can_play", false)) \
			and equip_targets.has(card_instance.instance_id)
	elif instance != null and instance.valid_actions.has("can_play"):
		_drag_valid = _server_allows_drop(instance.valid_actions)
	else:
		_drag_valid = _validate_card_type(card_type) and (not is_occupied or slot_type == SlotType.SCENARIO)

	# Todas las posiciones válidas se iluminan a la vez; la que está bajo el cursor, más fuerte
	if _is_mouse_over:
		_update_drag_glow()
	else:
		_set_style(_rest_style())


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
	_drag_valid = false
	_equip_mode = false
	_is_mouse_over = false
	_set_style(_default_style())


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
	card_type = _normalize_card_type(card_type)

	# Objeto soltado sobre un caballero propio: se juega en la fila de técnicas/objetos
	# equipado a ese caballero (el servidor elige la posición)
	if _equip_mode:
		if not _drag_valid or card_instance == null:
			print("[CardSlot:%s] ❌ Este objeto no se puede equipar a este caballero" % self.name)
			return
		card_dropped.emit({
			"card_display": card_display,
			"card_instance": card_display.get_instance(),
			"card_type": card_type,
			"target_slot": self,
			"slot_type": SlotType.TECH_OBJECT,
			"slot_index": slot_index,
			"equip_target_id": card_instance.instance_id,
		})
		return

	# Validar tipo de carta
	print("[CardSlot:%s] 🔍 Validando tipo %s para slot %s" % [self.name, card_type, slot_type])

	if not _validate_card_type(card_type):
		print("[CardSlot:%s] ❌ Tipo de carta %s no válido para este slot" % [self.name, card_type])
		return
	
	# El escenario se puede jugar encima del activo: el servidor lo reemplaza
	if is_occupied and slot_type != SlotType.SCENARIO:
		print("[CardSlot:%s] ❌ Slot ocupado" % self.name)
		return

	# Mismo criterio que el resaltado: si la posición no se iluminó, no se juega aquí
	if not _drag_valid:
		print("[CardSlot:%s] ❌ El servidor no permite jugar esta carta aquí" % self.name)
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


## Objetos: ids de los caballeros a los que el servidor permite equiparlo
## (valid_actions.equip_targets). null si la carta no es un objeto equipable.
func _equip_targets_of(instance: CardInstance) -> Variant:
	if instance == null:
		return null
	var targets = instance.valid_actions.get("equip_targets", null)
	return targets if targets is Array else null


## Zona (notación del cliente/servidor) que representa esta posición
func get_play_zone() -> String:
	match slot_type:
		SlotType.KNIGHT:      return "field_knight"
		SlotType.TECH_OBJECT: return "field_technique"
		SlotType.HELPER:      return "field_helper"
		SlotType.SCENARIO:    return "field_scenario"
		SlotType.OCCASION:    return "field_occasion"
	return ""


func _server_allows_drop(va: Dictionary) -> bool:
	if not va.get("can_play", false):
		return false
	var zone := str(va.get("play_zone", ""))
	if zone != "" and zone != get_play_zone():
		return false
	var slots = va.get("play_slots", [])
	if slots is Array and not slots.is_empty():
		var index := get_index()
		for s in slots:
			if int(s) == index:
				return true
		return false
	return true


func _validate_card_type(card_type: String) -> bool:
	"""Validar si el tipo de carta es compatible con este slot"""
	card_type = _normalize_card_type(card_type)
	match slot_type:
		SlotType.KNIGHT:
			return card_type == "knight"
		SlotType.TECH_OBJECT:
			return card_type == "technique" or card_type == "item"
		SlotType.HELPER:
			return card_type == "helper"
		SlotType.SCENARIO:
			return card_type == "stage"
		SlotType.OCCASION:
			return card_type == "event"
	return false


func _normalize_card_type(raw_type: String) -> String:
	var value := raw_type.strip_edges().to_lower()

	match value:
		# Knight
		"caballero":
			return "knight"

		# Technique
		"tecnica", "técnica":
			return "technique"

		# Item (legacy: object/objeto)
		"item", "objeto", "object":
			return "item"

		# Helper
		"helper", "ayudante", "assist", "assistant", "assistente":
			return "helper"

		# Stage (legacy: scenario/escenario)
		"stage", "scenario", "escenario", "cenario":
			return "stage"

		# Event (legacy: occasion/ocasion)
		"event", "occasion", "ocasion", "ocasión":
			return "event"

		_:
			return value

func set_glow(enabled: bool, color: Color = UIPalette.SELECTED):
	_set_style(_make_glow_style(color) if enabled else _default_style())

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
