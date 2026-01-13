#HandLayout.gd
extends CardCollection
class_name HandLayout

# Use centralized card size config
@export var card_width: float = 120.0
@export var card_height: float = 168.0
@export var max_total_width: float = 1200.0
@export var card_spacing: float = -40.0  # Solapamiento negativo para efecto profesional
@export var card_scale: float = 1.0
@export var hover_scale: float = 1.1
@export var hover_offset_y: float = -30.0

var hovered_card: Control = null
var dragging_card: Control = null
var _pending_dealt_cards: int = 0  # Cards being animated (not yet in _cards)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Sincronizar con CardSizeConfig si está disponible
	if CardSizeConfig:
		card_width = CardSizeConfig.card_width
		card_height = CardSizeConfig.card_height
		card_scale = CardSizeConfig.hand_card_scale
		hover_scale = CardSizeConfig.hand_card_hover_scale
	
	# Establecer estilo visual de fondo
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.18, 0.6)
	panel_style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", panel_style)
	
	resized.connect(arrange_cards)


# ====================================================================
# LAYOUT
# ====================================================================
func arrange_cards() -> void:
	if dragging_card:
		return

	# Use _cards (CardCollection's source of truth), not get_children()
	var cards: Array = _cards
	if cards.is_empty():
		return

	var count: int = cards.size()
	
	# Debug: verify single source of truth
	if get_children().size() != _cards.size():
		print("[HandLayout] ⚠️ Mismatch - children: %d, _cards: %d" % [get_children().size(), _cards.size()])

	# Calcular el ancho efectivo de una carta (con scale)
	var effective_card_width = card_width * card_scale
	
	# Calcular el espacio ocupado por todas las cartas con spacing
	var total_width = effective_card_width
	if count > 1:
		total_width += (count - 1) * (effective_card_width + card_spacing)

	# Calcular posición inicial para centrar
	var available_width = min(size.x - 20, max_total_width)  # 20px margen
	var start_x = max(10.0, (available_width - total_width) / 2.0 + 10.0)
	
	var base_y = 0.0

	for i in range(count):
		var card = cards[i] as Control
		if card == hovered_card:
			continue

		# Posición base sin hover
		var px = start_x + i * (effective_card_width + card_spacing)
		var py = base_y

		card.set_meta("base_pos", Vector2(px, py))
		card.set_meta("base_index", i)
		card.custom_minimum_size = Vector2(card_width, card_height)

		_apply_layout_to_card(card)


func _apply_layout_to_card(card: Control) -> void:
	if dragging_card == card:
		return

	var base_pos: Vector2 = card.get_meta("base_pos", card.position)
	var base_index: int = card.get_meta("base_index", 0)

	card.scale = Vector2.ONE * card_scale
	card.position = base_pos
	card.rotation = 0.0
	card.z_index = base_index


# ====================================================================
# HOVER
# ====================================================================
func hover_card(card: Control) -> void:
	if dragging_card or hovered_card == card:
		return

	print("HandLayout: Hover activado en carta")
	hovered_card = card

	# Kill previous tween if it exists
	if card.has_meta("hover_tween"):
		var old_tween = card.get_meta("hover_tween") as Tween
		if old_tween and old_tween.is_valid():
			old_tween.kill()

	var base_pos: Vector2 = card.get_meta("base_pos", card.position)
	var final_pos: Vector2 = base_pos + Vector2(0, hover_offset_y)

	card.z_index = 1000

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "scale", Vector2.ONE * hover_scale, 0.15)
	tween.tween_property(card, "position", final_pos, 0.15)
	
	# Store tween reference for cleanup
	card.set_meta("hover_tween", tween)


func unhover_card(card: Control) -> void:
	if dragging_card or hovered_card != card:
		return

	hovered_card = null

	# Kill previous tween if it exists
	if card.has_meta("hover_tween"):
		var old_tween = card.get_meta("hover_tween") as Tween
		if old_tween and old_tween.is_valid():
			old_tween.kill()

	var base_pos: Vector2 = card.get_meta("base_pos", card.position)
	var base_index: int = card.get_meta("base_index", 0)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "scale", Vector2.ONE * card_scale, 0.12)
	tween.tween_property(card, "position", base_pos, 0.12)
	tween.tween_callback(func(): card.z_index = base_index)
	
	# Store tween reference for cleanup
	card.set_meta("hover_tween", tween)


# ====================================================================
# DRAG
# ====================================================================
func notify_drag_start(_card_data: CardData) -> void:
	"""Notificación de inicio de drag desde CardDisplay"""
	# Buscar la carta en los hijos que está siendo arrastrada
	for card in get_children():
		if card is CardDisplay and card.card_data == _card_data:
			dragging_card = card
			card.z_index = 2000
			return


func notify_drag_end(_card_data: CardData) -> void:
	"""Notificación de fin de drag desde CardDisplay"""
	if dragging_card:
		dragging_card = null
		call_deferred("arrange_cards")


# ====================================================================
# API (usa base de CardCollection)
# ====================================================================
func add_card(card: Node) -> void:
	var ctrl := card as Control
	if not ctrl:
		push_error("HandLayout: add_card solo acepta Control.")
		return

	# If card already has a different parent, reparent it
	if ctrl.get_parent() != self and ctrl.get_parent() != null:
		ctrl.reparent(self)
	
	_connect_card_signals(ctrl)
	super.add_card(card)  # Llama al padre que hace add_child y emite señal


func add_dealt_card(card: Node) -> void:
	"""Add a card that was animated from the deck (delegates to add_card)"""
	var ctrl := card as Control
	if not ctrl:
		push_error("HandLayout: add_dealt_card solo acepta Control.")
		return
	
	# 🔥 ÚNICA entrada: add_card maneja TODA la incorporación
	# (signals, _cards, add_child, layout)
	# NO hacemos reparent aquí - add_card lo maneja
	add_card(ctrl)


func get_next_dealt_card_position() -> Vector2:
	"""Calculate global position where the next dealt card will land
	Used by CardDealAnimator to animate directly to final slot without jumps
	Accounts for cards still being animated (not yet in _cards)"""
	var next_index = _cards.size() + _pending_dealt_cards
	
	# Calculate effective width with scale
	var effective_card_width = card_width * card_scale
	
	# Calculate total width of all cards (including the incoming one)
	var total_cards = next_index + 1
	var total_width = effective_card_width
	if total_cards > 1:
		total_width += (total_cards - 1) * (effective_card_width + card_spacing)
	
	# Calculate starting position (centered)
	var available_width = min(size.x - 20, max_total_width)
	var start_x = max(10.0, (available_width - total_width) / 2.0 + 10.0)
	
	# Calculate position for this card
	var local_x = start_x + next_index * (effective_card_width + card_spacing)
	var local_y = 0.0
	
	# Convert to global position
	return global_position + Vector2(local_x, local_y)


func remove_card(card: Node) -> void:
	super.remove_card(card)  # Llama al padre


func _increment_pending_dealt() -> void:
	"""Called when CardDealAnimator starts animating a card"""
	_pending_dealt_cards += 1
	print("[HandLayout] 📥 +1 pending dealt, total: %d" % _pending_dealt_cards)


func _decrement_pending_dealt() -> void:
	"""Called when CardDealAnimator finishes and adds card to hand"""
	_pending_dealt_cards = max(0, _pending_dealt_cards - 1)
	print("[HandLayout] 📤 -1 pending dealt, total: %d" % _pending_dealt_cards)


# ====================================================================
# SEÑALES
# ====================================================================
func _connect_card_signals(card: Control) -> void:
	if card.has_signal("mouse_entered") and not card.mouse_entered.is_connected(_on_enter.bind(card)):
		card.mouse_entered.connect(_on_enter.bind(card))
		print("HandLayout: Conectada señal mouse_entered para carta")

	if card.has_signal("mouse_exited") and not card.mouse_exited.is_connected(_on_exit.bind(card)):
		card.mouse_exited.connect(_on_exit.bind(card))
		print("HandLayout: Conectada señal mouse_exited para carta")

	if card.has_signal("drag_started") and not card.drag_started.is_connected(notify_drag_start):
		card.drag_started.connect(notify_drag_start)

	if card.has_signal("drag_ended") and not card.drag_ended.is_connected(notify_drag_end):
		card.drag_ended.connect(notify_drag_end)


func _on_enter(card): hover_card(card)
func _on_exit(card): unhover_card(card)

# ====================================================================
# CARDCOLLECTION OVERRIDE
# ====================================================================
func _update_layout() -> void:
	"""Override del método template de CardCollection"""
	# Debug: Verify single source of truth
	for card in _cards:
		assert(card.get_parent() == self, "[HandLayout] Card parent mismatch! Card: %s, parent: %s" % [card, card.get_parent()])
	
	arrange_cards()
	super._update_layout()  # Emitir señal
