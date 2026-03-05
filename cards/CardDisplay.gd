# CardDisplay.gd
# Visual + Interactive component for cards with professional drag-and-drop
# Integrates DraggableObject state machine logic directly
extends Control
class_name CardDisplay

# ===== STATE MACHINE (From DraggableObject) =====
enum DraggableState {
	IDLE,
	HOVERING,
	HOLDING
}

var current_state: DraggableState = DraggableState.IDLE
var allowed_transitions = {
	DraggableState.IDLE: [DraggableState.HOVERING, DraggableState.HOLDING],
	DraggableState.HOVERING: [DraggableState.IDLE, DraggableState.HOLDING],
	DraggableState.HOLDING: [DraggableState.IDLE]
}

# ===== SIGNALS =====
signal card_clicked(card: CardData)
signal card_double_clicked(card: CardData)
signal drag_started(card: CardData)
signal drag_ended(card: CardData)

# ===== CARD DATA =====
var card_data: CardData
var card_instance: CardInstance = null
var instance_id: String = ""

# ===== UI COMPONENTS =====
var card_image: TextureRect = null
var highlight_overlay: ColorRect = null
var click_timer: Timer = null
var cost_badge: Label = null  # Badge que muestra el costo

# ===== STATS OVERLAY (Mini HUD - visible solo en field_knight) =====
var stats_overlay: Control = null
var hp_label: Label = null
var cp_label: Label = null

# ===== STATS TOOLTIP (hover sobre field_knight) =====
var stats_tooltip: PanelContainer = null
var tooltip_ce_label: Label = null
var tooltip_ar_label: Label = null
var tooltip_mode_label: Label = null
var tooltip_status_container: HBoxContainer = null

# ===== STATE MACHINE PROPERTIES (From DraggableObject) =====
var can_be_interacted_with: bool = true
var is_mouse_inside: bool = false
var current_holding_mouse_position: Vector2
var held_position_base: Vector2  # Position before drag (set when entering HOLDING)
var original_scale: Vector2
var original_rotation: float
var original_z: int

# ===== HOVER ANIMATION PROPERTIES =====
@export var hover_distance: int = 30
@export var hover_scale: float = 1.1
@export var hover_rotation: float = 0.0
@export var hover_duration: float = 0.2

# ===== TWEEN REFERENCES =====
var hover_tween: Tween = null
var move_tween: Tween = null
var highlight_tween: Tween = null

# ===== CARD STATES (Game logic) =====
var interaction_enabled: bool = true
var dragging_enabled: bool = true   # false cuando la carta está en un slot del campo
var is_disabled: bool = false
var is_exhausted: bool = false
var is_highlighted: bool = false
var disable_hover_animation: bool = false

# ===== STYLES =====
var normal_style: StyleBoxFlat = null
var disabled_style: StyleBoxFlat = null

# ===== CLICK DETECTION =====
var click_count: int = 0


func _ready() -> void:
	_ensure_ui_structure()
	_create_styles()
	_cleanup_tweens()  # Limpiar tweens previos
	_setup_state_machine()

	print("[CardDisplay] Ready - card_data=", card_data.name if card_data else "none")
	print("[CardDisplay] %s - mouse_filter=%s, can_be_dragged=%s" % [
		card_data.name if card_data else "?",
		mouse_filter,
		can_be_dragged()
	])


func _cleanup_tweens() -> void:
	"""Limpiar todos los tweens activos para evitar conflictos"""
	if hover_tween and hover_tween.is_valid():
		hover_tween.kill()
		hover_tween = null
	
	if move_tween and move_tween.is_valid():
		move_tween.kill()
		move_tween = null
	
	if highlight_tween and highlight_tween.is_valid():
		highlight_tween.kill()
		highlight_tween = null


func _setup_state_machine() -> void:
	"""Initialize state machine signals and properties"""
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Store original state (NOT position - that's managed by container)
	original_scale = scale
	original_rotation = rotation
	original_z = z_index
	
	# Connect signals for state machine
	mouse_entered.connect(_on_mouse_enter)
	mouse_exited.connect(_on_mouse_exit)
	gui_input.connect(_on_gui_input)
	
	# Setup click detection
	click_timer = Timer.new()
	click_timer.wait_time = 0.3
	click_timer.one_shot = true
	add_child(click_timer)
	click_timer.timeout.connect(_on_click_timeout)
	
	# Make children ignore mouse events
	_set_children_mouse_filter_ignore()


func _ensure_ui_structure() -> void:
	"""Create UI structure with image only"""
	# Usar CardSizeConfig como autoload (validar que exista)
	if CardSizeConfig:
		custom_minimum_size = CardSizeConfig.get_hand_card_size()
	else:
		custom_minimum_size = Vector2(120, 168)  # Fallback si CardSizeConfig no está listo
	
	if has_node("MarginContainer/VBoxContainer/CardImage"):
		card_image = $MarginContainer/VBoxContainer/CardImage
		highlight_overlay = $HighlightOverlay if has_node("HighlightOverlay") else null
		return
	
	var margin = MarginContainer.new()
	margin.name = "MarginContainer"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)
	
	card_image = TextureRect.new()
	card_image.name = "CardImage"
	card_image.custom_minimum_size = CardSizeConfig.get_hand_card_size()
	card_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	card_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(card_image)
	
	highlight_overlay = ColorRect.new()
	highlight_overlay.name = "HighlightOverlay"
	highlight_overlay.color = Color(1, 1, 0, 0.3)
	highlight_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight_overlay.visible = false
	highlight_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(highlight_overlay)
	highlight_overlay.z_index = 1


func _set_children_mouse_filter_ignore() -> void:
	"""Recursively set IGNORE mouse filter on all children"""
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for grandchild in child.get_children():
				if grandchild is Control:
					grandchild.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _create_styles() -> void:
	"""Create predefined styles"""
	normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	normal_style.set_corner_radius_all(4)
	
	disabled_style = StyleBoxFlat.new()
	disabled_style.bg_color = Color(0.4, 0.4, 0.4, 0.5)
	disabled_style.set_corner_radius_all(4)


func _create_cost_badge() -> void:
	"""Crear badge visual que muestra el costo de energía"""
	cost_badge = Label.new()
	cost_badge.name = "CostBadge"
	cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Posicionar en esquina superior derecha
	cost_badge.anchor_left = 0.85
	cost_badge.anchor_top = 0.05
	cost_badge.anchor_right = 0.98
	cost_badge.anchor_bottom = 0.2
	
	# Estilo
	cost_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_badge.add_theme_font_size_override("font_size", 20)
	cost_badge.add_theme_color_override("font_color", Color.YELLOW)
	cost_badge.text = "0"  # Default
	
	# Fondo redondo
	var badge_bg = StyleBoxFlat.new()
	badge_bg.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	badge_bg.border_color = Color(1, 1, 0, 0.8)
	badge_bg.border_width_left = 2
	badge_bg.border_width_right = 2
	badge_bg.border_width_top = 2
	badge_bg.border_width_bottom = 2
	badge_bg.set_corner_radius_all(8)
	cost_badge.add_theme_stylebox_override("normal", badge_bg)
	
	add_child(cost_badge)
	cost_badge.z_index = 100


# ===== STATS OVERLAY METHODS =====

func _create_stats_overlay() -> void:
	"""Crear el Mini HUD de stats en la parte inferior de la carta"""
	if stats_overlay and is_instance_valid(stats_overlay):
		return

	stats_overlay = Control.new()
	stats_overlay.name = "StatsOverlay"
	stats_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_overlay.visible = false

	# Anclado al fondo de la carta (20% inferior)
	stats_overlay.anchor_left = 0.0
	stats_overlay.anchor_top = 0.8
	stats_overlay.anchor_right = 1.0
	stats_overlay.anchor_bottom = 1.0
	stats_overlay.offset_left = 0
	stats_overlay.offset_top = 0
	stats_overlay.offset_right = 0
	stats_overlay.offset_bottom = 0

	add_child(stats_overlay)
	stats_overlay.z_index = 50

	# Panel de fondo semitransparente
	var panel = PanelContainer.new()
	panel.name = "StatsBg"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.04, 0.04, 0.10, 0.90)
	bg_style.border_color = Color(0.55, 0.45, 0.18, 0.85)
	bg_style.border_width_top = 1
	bg_style.corner_radius_top_left = 3
	bg_style.corner_radius_top_right = 3
	panel.add_theme_stylebox_override("panel", bg_style)
	stats_overlay.add_child(panel)

	# HBox centrado con los dos stats
	var hbox = HBoxContainer.new()
	hbox.name = "StatsHBox"
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(hbox)

	# Label HP
	hp_label = Label.new()
	hp_label.name = "HPLabel"
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 11)
	hp_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 1.0))
	hp_label.text = "\u2665 -/-"
	hbox.add_child(hp_label)

	# Separador
	var sep = Label.new()
	sep.name = "Separator"
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep.text = "|"
	sep.add_theme_color_override("font_color", Color(0.5, 0.45, 0.25, 0.7))
	sep.add_theme_font_size_override("font_size", 11)
	hbox.add_child(sep)

	# Label CP (Cosmos Points del caballero)
	cp_label = Label.new()
	cp_label.name = "CPLabel"
	cp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cp_label.add_theme_font_size_override("font_size", 11)
	cp_label.add_theme_color_override("font_color", Color(0.80, 0.55, 1.0, 1.0))
	cp_label.text = "\u25C6 -/-"
	hbox.add_child(cp_label)


func update_stats_display() -> void:
	"""Actualizar los labels del Mini HUD desde card_instance"""
	if not stats_overlay or not is_instance_valid(stats_overlay):
		return

	# Mostrar solo si el caballero está en el campo
	if not card_instance or card_instance.zone != "field_knight" or card_instance.base_data.type != "knight":
		stats_overlay.visible = false
		return

	stats_overlay.visible = true

	# --- HP label con color dinámico ---
	if hp_label and is_instance_valid(hp_label):
		hp_label.text = "\u2665 %d/%d" % [card_instance.current_health, card_instance.max_health]
		var ratio: float = 1.0
		if card_instance.max_health > 0:
			ratio = float(card_instance.current_health) / float(card_instance.max_health)
		if ratio <= 0.33:
			hp_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15, 1.0))  # Rojo critico
		elif ratio <= 0.66:
			hp_label.add_theme_color_override("font_color", Color(1.0, 0.60, 0.15, 1.0))  # Naranja
		else:
			hp_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35, 1.0))  # Verde lleno

	# --- CP label (Cosmos Points) ---
	if cp_label and is_instance_valid(cp_label):
		cp_label.text = "\u25C6 %d/%d" % [card_instance.current_cosmos, card_instance.max_cosmos]
		var cp_ratio: float = 1.0
		if card_instance.max_cosmos > 0:
			cp_ratio = float(card_instance.current_cosmos) / float(card_instance.max_cosmos)
		if cp_ratio <= 0.33:
			cp_label.add_theme_color_override("font_color", Color(0.50, 0.20, 0.75, 1.0))
		elif cp_ratio <= 0.66:
			cp_label.add_theme_color_override("font_color", Color(0.75, 0.45, 1.0, 1.0))
		else:
			cp_label.add_theme_color_override("font_color", Color(0.88, 0.65, 1.0, 1.0))


# ===== STATS TOOLTIP METHODS =====

func _create_stats_tooltip() -> void:
	"""Crear el tooltip de hover: CE, AR y estados del caballero"""
	if stats_tooltip and is_instance_valid(stats_tooltip):
		return

	stats_tooltip = PanelContainer.new()
	stats_tooltip.name = "StatsTooltip"
	stats_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_tooltip.visible = false
	stats_tooltip.position = Vector2(-4, -96)
	stats_tooltip.custom_minimum_size = Vector2(128, 0)
	add_child(stats_tooltip)
	stats_tooltip.z_index = 200

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.04, 0.04, 0.12, 0.96)
	bg_style.border_color = Color(0.65, 0.55, 0.18, 1.0)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(5)
	bg_style.content_margin_left = 7
	bg_style.content_margin_right = 7
	bg_style.content_margin_top = 5
	bg_style.content_margin_bottom = 5
	stats_tooltip.add_theme_stylebox_override("panel", bg_style)

	var vbox = VBoxContainer.new()
	vbox.name = "TooltipVBox"
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 3)
	stats_tooltip.add_child(vbox)

	# Fila 1: CE y AR
	var row1 = HBoxContainer.new()
	row1.name = "Row1"
	row1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.add_theme_constant_override("separation", 6)
	vbox.add_child(row1)

	tooltip_ce_label = Label.new()
	tooltip_ce_label.name = "CELabel"
	tooltip_ce_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_ce_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tooltip_ce_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tooltip_ce_label.add_theme_font_size_override("font_size", 11)
	tooltip_ce_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2, 1.0))
	tooltip_ce_label.text = "\u26A1 CE: -"
	row1.add_child(tooltip_ce_label)

	var row1_sep = Label.new()
	row1_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row1_sep.text = "|"
	row1_sep.add_theme_color_override("font_color", Color(0.45, 0.40, 0.20, 0.6))
	row1_sep.add_theme_font_size_override("font_size", 11)
	row1.add_child(row1_sep)

	tooltip_ar_label = Label.new()
	tooltip_ar_label.name = "ARLabel"
	tooltip_ar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_ar_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tooltip_ar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tooltip_ar_label.add_theme_font_size_override("font_size", 11)
	tooltip_ar_label.add_theme_color_override("font_color", Color(0.45, 0.78, 1.0, 1.0))
	tooltip_ar_label.text = "\u25C9 AR: -"
	row1.add_child(tooltip_ar_label)

	# Fila 2: Modo (oculto si es "normal")
	tooltip_mode_label = Label.new()
	tooltip_mode_label.name = "ModeLabel"
	tooltip_mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tooltip_mode_label.add_theme_font_size_override("font_size", 10)
	tooltip_mode_label.visible = false
	vbox.add_child(tooltip_mode_label)

	# Fila 3: Status effects
	tooltip_status_container = HBoxContainer.new()
	tooltip_status_container.name = "StatusRow"
	tooltip_status_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_status_container.alignment = BoxContainer.ALIGNMENT_CENTER
	tooltip_status_container.add_theme_constant_override("separation", 3)
	vbox.add_child(tooltip_status_container)


func _update_stats_tooltip() -> void:
	"""Rellenar el tooltip con valores actuales del card_instance"""
	if not stats_tooltip or not is_instance_valid(stats_tooltip):
		return
	if not card_instance:
		return

	# CE (Combat Energy = ataque actual)
	if tooltip_ce_label and is_instance_valid(tooltip_ce_label):
		tooltip_ce_label.text = "\u26A1 CE: %d" % card_instance.current_attack

	# AR (Armor Rating = defensa actual)
	if tooltip_ar_label and is_instance_valid(tooltip_ar_label):
		tooltip_ar_label.text = "\u25C9 AR: %d" % card_instance.current_defense

	# Modo (invisible si es "normal")
	if tooltip_mode_label and is_instance_valid(tooltip_mode_label):
		var mode_val = card_instance.mode
		if mode_val != "normal":
			tooltip_mode_label.visible = true
			match mode_val:
				"defense":
					tooltip_mode_label.text = "\u26CA DEFENSA"
					tooltip_mode_label.add_theme_color_override("font_color", Color(0.40, 0.75, 1.00))
				"evade":
					tooltip_mode_label.text = "\u21A9 EVASION"
					tooltip_mode_label.add_theme_color_override("font_color", Color(0.40, 1.00, 0.65))
				"prayer":
					tooltip_mode_label.text = "\u2736 ORACION"
					tooltip_mode_label.add_theme_color_override("font_color", Color(1.00, 0.90, 0.35))
				_:
					tooltip_mode_label.text = "[ %s ]" % mode_val.to_upper()
					tooltip_mode_label.add_theme_color_override("font_color", Color.WHITE)
		else:
			tooltip_mode_label.visible = false

	# Status effects
	if tooltip_status_container and is_instance_valid(tooltip_status_container):
		for child in tooltip_status_container.get_children():
			child.queue_free()
		for status in card_instance.status_effects:
			var pill = _create_status_pill(status)
			tooltip_status_container.add_child(pill)


func _create_status_pill(status: Dictionary) -> Label:
	"""Crear etiqueta-pastilla para un status effect"""
	var pill = Label.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_font_size_override("font_size", 9)

	var effect_type = str(status.get("type", "?"))
	var duration = int(status.get("duration", 0))

	var pill_bg = StyleBoxFlat.new()
	pill_bg.set_corner_radius_all(4)
	pill_bg.content_margin_left = 4
	pill_bg.content_margin_right = 4
	pill_bg.content_margin_top = 2
	pill_bg.content_margin_bottom = 2

	match effect_type.to_lower():
		"poison", "veneno":
			pill.text = "\u2620 %dt" % duration
			pill_bg.bg_color = Color(0.22, 0.60, 0.12, 0.92)
			pill.add_theme_color_override("font_color", Color(0.90, 1.00, 0.85))
		"paralysis", "paralisis":
			pill.text = "\u26A1 %dt" % duration
			pill_bg.bg_color = Color(0.78, 0.70, 0.04, 0.92)
			pill.add_theme_color_override("font_color", Color(0.08, 0.06, 0.00))
		"frozen", "congelado":
			pill.text = "\u2744 %dt" % duration
			pill_bg.bg_color = Color(0.22, 0.52, 1.00, 0.92)
			pill.add_theme_color_override("font_color", Color(1.00, 1.00, 1.00))
		"burn", "quemado":
			pill.text = "\u2605 %dt" % duration
			pill_bg.bg_color = Color(0.90, 0.26, 0.04, 0.92)
			pill.add_theme_color_override("font_color", Color(1.00, 1.00, 1.00))
		"silenced", "silenciado":
			pill.text = "\u2298 %dt" % duration
			pill_bg.bg_color = Color(0.45, 0.24, 0.55, 0.92)
			pill.add_theme_color_override("font_color", Color(1.00, 1.00, 1.00))
		_:
			pill.text = "%s %dt" % [effect_type.substr(0, 3).to_upper(), duration]
			pill_bg.bg_color = Color(0.32, 0.32, 0.32, 0.92)
			pill.add_theme_color_override("font_color", Color(1.00, 1.00, 1.00))

	pill.add_theme_stylebox_override("normal", pill_bg)
	return pill


# ===== STATE MACHINE METHODS =====

func change_state(new_state: DraggableState) -> bool:
	"""Safely transition between states with validation"""
	if new_state == current_state:
		return true
	
	var current_name = DraggableState.keys()[current_state]
	var new_name = DraggableState.keys()[new_state]
	var card_name = card_data.name if card_data else "unknown"
	
	if not new_state in allowed_transitions[current_state]:
		print("[CardDisplay] 🚫 Transición inválida para '%s': %s → %s" % [card_name, current_name, new_name])
		return false
	
	_exit_state(current_state)
	var old_state = current_state
	current_state = new_state
	current_name = DraggableState.keys()[current_state]
	print("[CardDisplay] ✅ Estado: %s (para '%s')" % [current_name, card_name])
	_enter_state(new_state, old_state)
	
	return true


func _enter_state(state: DraggableState, _from_state: DraggableState) -> void:
	"""Handle state entry logic"""
	match state:
		DraggableState.IDLE:
			z_index = original_z
			mouse_filter = Control.MOUSE_FILTER_STOP
			
		DraggableState.HOVERING:
			z_index = original_z + 10
			_start_hover_animation()
			
		DraggableState.HOLDING:
			# Preserve current position before dragging
			held_position_base = position
			
			current_holding_mouse_position = get_local_mouse_position()
			z_index = original_z + 10
			rotation = 0


func _exit_state(state: DraggableState) -> void:
	"""Handle state exit logic"""
	match state:
		DraggableState.HOVERING:
			z_index = original_z
			_stop_hover_animation()
			
		DraggableState.HOLDING:
			z_index = original_z
			scale = original_scale
			rotation = original_rotation
			position = held_position_base  # Return to position before drag


func _process(_delta: float) -> void:
	"""Process frame - handle HOLDING state mouse tracking"""
	if current_state == DraggableState.HOLDING:
		global_position = get_global_mouse_position() - current_holding_mouse_position


# ===== INPUT HANDLING =====

func _on_gui_input(event: InputEvent) -> void:
	"""Handle mouse input events"""
	if not interaction_enabled:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_handle_mouse_pressed()
		else:
			_handle_mouse_released()


func _handle_mouse_pressed() -> void:
	"""Handle mouse press and click detection"""
	if not can_be_dragged():
		return
	
	# Cambiar a HOLDING inmediatamente para permitir drag
	if current_state == DraggableState.HOVERING or current_state == DraggableState.IDLE:
		change_state(DraggableState.HOLDING)
		start_dragging()
	
	# Contar clics para doble-clic
	click_count += 1
	if click_count == 1:
		click_timer.start()
	elif click_count == 2:
		click_timer.stop()
		click_count = 0
		card_double_clicked.emit(card_data)


func _handle_mouse_released() -> void:
	"""Handle mouse release"""
	if current_state == DraggableState.HOLDING:
		stop_dragging()
		change_state(DraggableState.IDLE)


func _on_mouse_enter() -> void:
	"""Handle mouse enter"""
	is_mouse_inside = true

	if current_state == DraggableState.IDLE and _can_start_hovering():
		change_state(DraggableState.HOVERING)

	# Mostrar tooltip de stats solo en campo
	if card_instance and card_instance.zone == "field_knight":
		_create_stats_tooltip()
		_update_stats_tooltip()
		if stats_tooltip and is_instance_valid(stats_tooltip):
			stats_tooltip.visible = true


func _on_mouse_exit() -> void:
	"""Handle mouse exit"""
	is_mouse_inside = false

	if current_state == DraggableState.HOVERING:
		change_state(DraggableState.IDLE)

	# Ocultar tooltip
	if stats_tooltip and is_instance_valid(stats_tooltip):
		stats_tooltip.visible = false


func _can_start_hovering() -> bool:
	"""CardDisplay doesn't handle hover - delegated to container (HandLayout, etc.)"""
	return false


# ===== HOVER ANIMATION =====

func _start_hover_animation() -> void:
	"""Start hover animation"""
	if disable_hover_animation or (hover_tween and hover_tween.is_valid()):
		return
	
	# DON'T reset position - animate from current position
	# This preserves the card's location in HandLayout or zones
	hover_tween = create_tween()
	hover_tween.set_parallel(true)
	
	var target_position = Vector2(position.x, position.y - hover_distance)
	hover_tween.tween_property(self, "position", target_position, hover_duration)
	hover_tween.tween_property(self, "scale", original_scale * hover_scale, hover_duration)
	
	if hover_rotation != 0:
		hover_tween.tween_property(self, "rotation", deg_to_rad(hover_rotation), hover_duration)


func _stop_hover_animation() -> void:
	"""Stop hover animation - [DEPRECATED] no longer called since _can_start_hovering() = false"""
	if hover_tween and hover_tween.is_valid():
		hover_tween.kill()
		hover_tween = null


func _preserve_hover_position() -> void:
	"""[DEPRECATED] No longer needed - position preserved in HOLDING state entry"""
	pass


# ===== DRAG & DROP LOGIC =====

func can_be_dragged() -> bool:
	"""Check if card can be dragged"""
	return card_data != null and interaction_enabled and dragging_enabled and not is_disabled and not is_exhausted


func get_drag_data(_at_position: Vector2) -> Variant:
	"""Godot drag-drop system: preparar data para soltar en drop zones
	
	Llamado automáticamente por Godot cuando el usuario comienza drag.
	Retorna null = no se puede arrastrar
	Retorna Dictionary = data para pasar a _can_drop_data() en targets
	"""
	if not can_be_dragged():
		return null
	
	var drag_data = {
		"card_type": card_data.type,           # "knight", "technique", "item", etc.
		"card_display": self,                  # Nodo visual
		"card_instance": card_instance,        # Datos del juego
		"source_zone": "hand"                  # De dónde salió
	}
	
	print("[CardDisplay] 🎴 get_drag_data(): preparado %s con type=%s" % [card_data.name, card_data.type])
	return drag_data


func start_dragging() -> void:
	"""Start dragging - notificar a todos los CardSlots"""
	drag_started.emit(card_data)
	print("[CardDisplay] Drag started: ", card_data.name if card_data else "unknown")
	
	# Notificar a todos los CardSlots que un drag comenzó
	_notify_all_slots_drag_started()


func _notify_all_slots_drag_started() -> void:
	"""Notificar a todos los CardSlots en el árbol que un drag comenzó"""
	var root = get_tree().root
	var card_data_dict = get_data()  # Convertir a Dictionary para CardSlot
	_notify_slots_recursive(root, self, card_data_dict)


func _notify_slots_recursive(node: Node, card_display: Control, card_data_dict: Dictionary) -> void:
	"""Recursivamente notificar a todos los CardSlots"""
	if node is CardSlot:
		(node as CardSlot).notify_card_drag_started(card_display, card_data_dict)
	
	for child in node.get_children():
		_notify_slots_recursive(child, card_display, card_data_dict)


func stop_dragging() -> void:
	"""Stop dragging - notificar a todos los CardSlots"""
	drag_ended.emit(card_data)
	print("[CardDisplay] Drag ended: ", card_data.name if card_data else "unknown")
	
	# Notificar a todos los CardSlots que el drag terminó
	_notify_all_slots_drag_ended()


func _notify_all_slots_drag_ended() -> void:
	"""Notificar a todos los CardSlots que el drag terminó"""
	var root = get_tree().root
	_notify_slots_ended_recursive(root)


func _notify_slots_ended_recursive(node: Node) -> void:
	"""Recursivamente notificar a todos los CardSlots"""
	if node is CardSlot:
		(node as CardSlot).notify_card_drag_ended()
	
	for child in node.get_children():
		_notify_slots_ended_recursive(child)


func show_card_details() -> void:
	"""Show card details (on click without drag)"""
	card_clicked.emit(card_data)
	print("[CardDisplay] Card clicked: ", card_data.name if card_data else "unknown")


# ===== CARD SETUP =====

func setup(data: CardData) -> void:
	"""Setup card with data"""
	if not data:
		push_error("[CardDisplay] ❌ setup: data es null")
		return
	
	# 🔥 CRÍTICO: Asegurarse que la UI existe antes de usarla
	if not is_instance_valid(card_image):
		_ensure_ui_structure()
	
	card_data = data
	instance_id = data.id

	if not is_instance_valid(CardsManager):
		push_error("[CardDisplay] ❌ setup: CardManager no disponible")
		return

	# Debug: check si imagen está en caché
	var in_cache = CardsManager._image_cache.has(card_data.id)
	print("[CardDisplay] setup(%s) - en cache: %s, image_url: %s" % [card_data.name, in_cache, card_data.image_url])

	CardsManager.get_cached_image(card_data.id, card_data.image_url, func(texture):
		if texture == null:
			print("[CardDisplay] ⚠️ Texture es null para: %s (image_url: %s)" % [card_data.id, card_data.image_url])
			push_error("[CardDisplay] ❌ Error cargando imagen para: %s" % card_data.id)
			# Mostrar placeholder si la imagen no se pudo cargar
			if is_instance_valid(card_image):
				_show_placeholder()
			return
		if is_instance_valid(card_image):
			card_image.texture = texture
			print("[CardDisplay] ✅ Imagen asignada a %s (size: %.0fx%.0f)" % [card_data.name, texture.get_size().x, texture.get_size().y])
		else:
			print("[CardDisplay] ⚠️ card_image no es válido para: %s (node queue freed?)" % card_data.name)
	)

func setup_from_instance(instance: CardInstance) -> void:
	"""Setup from CardInstance and refresh visuals"""
	if not instance or not instance.base_data:
		push_error("[CardDisplay] ❌ setup_from_instance: instance o base_data missing")
		return
	
	_ensure_ui_structure()
	if not normal_style or not disabled_style:
		_create_styles()
	
	card_instance = instance
	card_data = instance.base_data
	instance_id = instance.instance_id
	
	if not is_instance_valid(CardsManager):
		push_error("[CardDisplay] ❌ setup_from_instance: CardManager no disponible")
		return
	
	setup(card_data)
	update_visual_state()

	# Crear overlay de stats si es knight
	if card_data.type == "knight":
		_create_stats_overlay()
		if not instance.stats_changed.is_connected(_on_instance_stats_changed):
			instance.stats_changed.connect(_on_instance_stats_changed)
		update_stats_display()


func _on_instance_stats_changed(_inst: CardInstance) -> void:
	"""Llamado cuando CardInstance emite stats_changed"""
	update_stats_display()
	# Refrescar tooltip si está visible (evitar reconstruirlo)
	if stats_tooltip and is_instance_valid(stats_tooltip) and stats_tooltip.visible:
		_update_stats_tooltip()

func play_spawn_animation() -> void:
	"""Simple spawn animation for when the card appears"""
	modulate.a = 0.0
	scale = Vector2(0.3, 0.3)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ===== CARD STATE METHODS =====

func set_disabled(disabled: bool) -> void:
	"""Set disabled state"""
	is_disabled = disabled
	update_visual_state()


func set_exhausted(exhausted: bool) -> void:
	"""Set exhausted state"""
	is_exhausted = exhausted
	update_visual_state()


func set_highlighted(highlighted: bool) -> void:
	"""Set highlighted state"""
	is_highlighted = highlighted
	update_visual_state()


func update_visual_state() -> void:
	"""Update visual state based on flags"""
	if is_disabled:
		add_theme_stylebox_override("panel", disabled_style)
		modulate = Color(0.6, 0.6, 0.6, 1.0)
	else:
		add_theme_stylebox_override("panel", normal_style)
		modulate = Color(1, 1, 1, 1)
	
	if is_exhausted:
		modulate = Color(0.7, 0.7, 0.7, 0.8)
		if card_image:
			card_image.rotation_degrees = 15
	else:
		if card_image:
			card_image.rotation_degrees = 0
	
	if highlight_overlay:
		highlight_overlay.visible = is_highlighted


func bind_instance(instance: CardInstance) -> void:
	"""Bind CardInstance to this display"""
	card_instance = instance
	if instance:
		instance_id = instance.instance_id
		# Conectar señal y actualizar stats
		if instance.base_data and instance.base_data.type == "knight":
			_create_stats_overlay()
			if not instance.stats_changed.is_connected(_on_instance_stats_changed):
				instance.stats_changed.connect(_on_instance_stats_changed)
			update_stats_display()


func _on_click_timeout() -> void:
	"""Handle click timeout - emit card clicked signal"""
	if click_count == 1:
		var card_name = card_data.name if card_data else "unknown"
		print("[CardDisplay] Click emitted: ", card_name)
		card_clicked.emit(card_data)
	click_count = 0


func unbind_instance() -> void:
	"""Unbind CardInstance"""
	if card_instance and card_instance.stats_changed.is_connected(_on_instance_stats_changed):
		card_instance.stats_changed.disconnect(_on_instance_stats_changed)
	card_instance = null
	instance_id = ""
	if stats_overlay and is_instance_valid(stats_overlay):
		stats_overlay.visible = false
	if stats_tooltip and is_instance_valid(stats_tooltip):
		stats_tooltip.visible = false


func get_instance() -> CardInstance:
	"""Get bound CardInstance"""
	return card_instance


func get_data() -> Dictionary:
	"""Get card data as a dictionary"""
	if card_data == null:
		return {}
	
	return {
		"id": card_data.id,
		"name": card_data.name,
		"type": card_data.type,
		"rarity": card_data.rarity,
		"faction": card_data.faction,
		"element": card_data.element,
		"cost": card_data.cost
	}


# ===== ZONE TRANSITION ANIMATIONS =====

func animate_from_position(start_global_pos: Vector2, duration: float = 0.4) -> void:
	"""Animate card movement from a source position to current position.
	Used for deck→hand, field→discard, etc.
	
	Args:
		start_global_pos: Global position where animation starts (e.g., deck pile)
		duration: Animation duration in seconds
	"""
	var final_position = global_position
	
	global_position = start_global_pos
	modulate.a = 0.3
	rotation = randf_range(-0.3, 0.3)
	scale = Vector2(0.85, 0.85)
	
	if move_tween and move_tween.is_valid():
		move_tween.kill()
	
	move_tween = create_tween()
	move_tween.set_parallel(true)
	move_tween.set_trans(Tween.TRANS_QUAD)
	move_tween.set_ease(Tween.EASE_OUT)
	
	move_tween.tween_property(self, "global_position", final_position, duration)
	move_tween.tween_property(self, "modulate:a", 1.0, duration)
	move_tween.tween_property(self, "rotation", 0.0, duration)
	move_tween.tween_property(self, "scale", Vector2(1.0, 1.0), duration)
	
	print("[CardDisplay] Animation started: %s from %s to %s" % [card_data.name, start_global_pos, final_position])


func animate_flip_from_deck(deck_pos: Vector2, duration: float = 0.5) -> void:
	"""Animate card flip from deck (dorso/CardBack) to hand with smooth transition.
	Card starts with CardBack visible on top, moves to hand, and flips to show card face.
	
	Args:
		deck_pos: Global position where card back is
		duration: Total animation duration in seconds
	"""
	var final_position = global_position
	
	# Get CardBack reference
	var card_back = get_meta("card_back") if has_meta("card_back") else null
	
	# Ensure CardBack is visible at start
	if card_back:
		card_back.visible = true
		card_back.z_index = 10  # Keep on top
	
	# Start at deck position
	global_position = deck_pos
	modulate.a = 1.0
	rotation = 0.0
	scale = Vector2(1.0, 1.0)
	
	if move_tween and move_tween.is_valid():
		move_tween.kill()
	
	move_tween = create_tween()
	move_tween.set_trans(Tween.TRANS_QUAD)
	move_tween.set_ease(Tween.EASE_OUT)
	
	# Move from deck to hand (70% of time)
	move_tween.tween_property(self, "global_position", final_position, duration * 0.7)
	
	# At 70%, perform flip: hide CardBack, animate card image
	move_tween.tween_callback(func():
		# Hide CardBack
		if card_back:
			card_back.visible = false
		
		# Flip card image with rotation
		if card_image:
			var flip_tween = create_tween()
			flip_tween.set_trans(Tween.TRANS_QUAD)
			flip_tween.set_ease(Tween.EASE_IN_OUT)
			flip_tween.tween_property(card_image, "rotation_degrees", 180.0, duration * 0.15)
			flip_tween.tween_property(card_image, "rotation_degrees", 0.0, duration * 0.15)
	)
	
	print("[CardDisplay] Flip animation: %s from deck to hand" % card_data.name)


func _perform_flip() -> void:
	"""[DEPRECATED] - Logic moved to animate_flip_from_deck callback"""
	pass


func animate_to_position(target_global_pos: Vector2, duration: float = 0.4) -> void:
	"""Animate card movement to a target position.
	Used for hand→field, card→discard pile, etc.
	
	Args:
		target_global_pos: Global position where animation ends
		duration: Animation duration in seconds
	"""
	if move_tween and move_tween.is_valid():
		move_tween.kill()
	
	move_tween = create_tween()
	move_tween.set_parallel(true)
	move_tween.set_trans(Tween.TRANS_QUAD)
	move_tween.set_ease(Tween.EASE_IN)
	
	move_tween.tween_property(self, "global_position", target_global_pos, duration)
	move_tween.tween_property(self, "modulate:a", 0.7, duration)
	move_tween.tween_property(self, "rotation", randf_range(-0.2, 0.2), duration)
	
	print("[CardDisplay] Animation to: %s towards %s" % [card_data.name, target_global_pos])


func animate_spawn(duration: float = 0.3) -> void:
	"""Play spawn animation for newly created cards.
	Used when cards appear from nowhere (draw, generate, etc.)
	"""
	modulate.a = 0.0
	scale = Vector2(0.5, 0.5)
	
	if move_tween and move_tween.is_valid():
		move_tween.kill()
	
	move_tween = create_tween()
	move_tween.set_parallel(true)
	move_tween.set_trans(Tween.TRANS_BACK)
	move_tween.set_ease(Tween.EASE_OUT)
	
	move_tween.tween_property(self, "modulate:a", 1.0, duration)
	move_tween.tween_property(self, "scale", Vector2(1.0, 1.0), duration)

func _show_placeholder() -> void:
	"""Mostrar imagen de placeholder cuando hay error al cargar la imagen"""
	if not is_instance_valid(card_image):
		return
	
	# Crear una imagen placeholder de color gris
	var placeholder = Image.create(120, 168, false, Image.FORMAT_RGB8)
	placeholder.fill(Color(0.3, 0.3, 0.35, 1.0))  # Gris oscuro
	
	# Si no hay fuente disponible, solo mostrar el rectángulo gris
	var placeholder_texture = ImageTexture.create_from_image(placeholder)
	card_image.texture = placeholder_texture
	print("[CardDisplay] 📦 Placeholder mostrado para: %s" % (card_data.name if card_data else "unknown"))

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if hover_tween and hover_tween.is_valid():
			hover_tween.kill()
		if move_tween and move_tween.is_valid():
			move_tween.kill()
		if highlight_tween and highlight_tween.is_valid():
			highlight_tween.kill()
