# MatchSearch.gd
# Superposición de búsqueda de partida (vive en el lobby, encima de todo).
#
#   Buscando   → anillos de cosmos girando, cronómetro, consejos y CANCELAR.
#                A los AI_OFFER_SECONDS ofrece jugar contra la IA mientras tanto.
#   Contra IA  → "Invocando a tu rival" mientras el servidor prepara la partida.
#   Encontrada → "¡RIVAL ENCONTRADO!" y TÚ VS RIVAL hasta que se abre el tablero.
#
# Escucha a MatchmakingService; no busca por su cuenta (el botón JUGAR inicia la búsqueda).
extends Control

const AI_OFFER_SECONDS := 20.0
const TIP_SECONDS := 5.0
const TIPS := [
	"Quien empieza no puede atacar directamente al rival en su primer turno.",
	"Un ataque directo quita 2 vidas al rival; derrotar a uno de sus caballeros, 1.",
	"Cargar Cosmo gasta la acción del caballero, pero te da cosmo para jugar más cartas.",
	"Los objetos se equipan a un caballero propio y van al Yomotsu con él.",
	"La Provocación obliga a los ataques básicos rivales a ir contra su portador.",
	"El Modo Defensa reduce el daño; el Modo Evasión puede esquivar ataques básicos.",
	"Cada habilidad activa se puede usar una vez por turno y caballero.",
	"Las técnicas consumen el cosmo del caballero que las lanza.",
]

enum State { HIDDEN, SEARCHING, AI, FOUND }

var _state := State.HIDDEN
var _elapsed := 0.0
var _tip_elapsed := 0.0
var _tip_index := 0
var _fade_tween: Tween

var _dim: ColorRect
var _rings: CosmosRings
var _title: Label
var _timer_label: Label
var _versus: Label
var _tip: Label
var _cancel_button: Button
var _ai_offer: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	hide()
	set_process(false)

	MatchmakingService.searching_match.connect(_on_searching)
	MatchmakingService.search_cancelled.connect(_on_stopped)
	MatchmakingService.match_error.connect(func(_message): _on_stopped())
	MatchmakingService.match_found.connect(_on_match_found)
	MatchmakingService.ai_match_requested.connect(_on_ai_requested)

	# Si se vuelve al lobby con una búsqueda en curso, mostrarla
	if MatchmakingService.is_searching:
		_on_searching()


func _process(delta: float) -> void:
	_elapsed += delta
	if _state == State.SEARCHING:
		_timer_label.text = "%02d:%02d" % [int(_elapsed) / 60, int(_elapsed) % 60]
		if _elapsed >= AI_OFFER_SECONDS and not _ai_offer.visible:
			_show_ai_offer()
	_tip_elapsed += delta
	if _tip_elapsed >= TIP_SECONDS and _state != State.FOUND:
		_tip_elapsed = 0.0
		_next_tip()


func _unhandled_input(event: InputEvent) -> void:
	if visible and _state == State.SEARCHING and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		MatchmakingService.cancel_search()


# ============================================================================
# CONSTRUCCIÓN
# ============================================================================

func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.color = UIPalette.alpha(UIPalette.ABYSS, 0.975)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	_title = Label.new()
	_title.theme_type_variation = &"HeroTitle"
	_title.add_theme_font_size_override("font_size", 50)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)

	_rings = CosmosRings.new()
	_rings.custom_minimum_size = Vector2(330, 330)
	_rings.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_rings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_rings)

	_timer_label = Label.new()
	_timer_label.theme_type_variation = &"StatValue"
	_timer_label.add_theme_font_size_override("font_size", 40)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_timer_label)

	_versus = Label.new()
	_versus.theme_type_variation = &"SectionTitle"
	_versus.add_theme_font_size_override("font_size", 34)
	_versus.add_theme_color_override("font_color", UIPalette.GOLD_LIGHT)
	_versus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_versus.visible = false
	column.add_child(_versus)

	_tip = Label.new()
	_tip.theme_type_variation = &"Subtitle"
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size = Vector2(640, 52)
	_tip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_tip)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	column.add_child(spacer)

	_ai_offer = VBoxContainer.new()
	_ai_offer.alignment = BoxContainer.ALIGNMENT_CENTER
	_ai_offer.add_theme_constant_override("separation", 6)
	_ai_offer.visible = false
	column.add_child(_ai_offer)

	var offer_text := Label.new()
	offer_text.theme_type_variation = &"Caption"
	offer_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	offer_text.text = "¿Tarda demasiado? Practica mientras tanto"
	_ai_offer.add_child(offer_text)

	var ai_button := Button.new()
	ai_button.text = "JUGAR CONTRA LA IA"
	ai_button.icon = preload("res://assets/ui-icons/lobby/ai.svg")
	ai_button.expand_icon = true
	ai_button.add_theme_constant_override("icon_max_width", 28)
	ai_button.theme_type_variation = &"PlayButton"
	ai_button.add_theme_font_size_override("font_size", 22)
	ai_button.custom_minimum_size = Vector2(340, 58)
	ai_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ai_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ai_button.pressed.connect(func(): MatchmakingService.request_ai_match())
	_ai_offer.add_child(ai_button)

	_cancel_button = Button.new()
	_cancel_button.text = "CANCELAR"
	_cancel_button.theme_type_variation = &"GhostButton"
	_cancel_button.add_theme_font_size_override("font_size", 20)
	_cancel_button.custom_minimum_size = Vector2(240, 54)
	_cancel_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_cancel_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_cancel_button.pressed.connect(func(): MatchmakingService.cancel_search())
	column.add_child(_cancel_button)


# ============================================================================
# ESTADOS
# ============================================================================

func _on_searching() -> void:
	_state = State.SEARCHING
	_elapsed = 0.0
	_title.text = "BUSCANDO RIVAL"
	_title.add_theme_color_override("font_color", UIPalette.TEXT)
	_timer_label.text = "00:00"
	_timer_label.visible = true
	_versus.visible = false
	_cancel_button.visible = true
	_ai_offer.visible = false
	_rings.set_mode(CosmosRings.Mode.SEARCHING)
	_start_tips()
	_appear()


func _on_ai_requested() -> void:
	_state = State.AI
	_title.text = "INVOCANDO A LA IA"
	_title.add_theme_color_override("font_color", UIPalette.ACCENT)
	_timer_label.visible = false
	_versus.visible = false
	_cancel_button.visible = false
	_ai_offer.visible = false
	_rings.set_mode(CosmosRings.Mode.AI)
	if not visible:
		_start_tips()
	_appear()


func _on_match_found(data: Dictionary) -> void:
	_state = State.FOUND
	_title.text = "¡RIVAL ENCONTRADO!"
	_title.add_theme_color_override("font_color", UIPalette.GOLD_LIGHT)
	_timer_label.visible = false
	_cancel_button.visible = false
	_ai_offer.visible = false
	_tip.text = "Preparando el campo de batalla…"
	_versus.text = "TÚ   VS   %s" % _opponent_name(data).to_upper()
	_versus.visible = true
	_versus.pivot_offset = _versus.size / 2.0
	_versus.scale = Vector2(1.6, 1.6)
	_versus.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_versus, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_versus, "modulate:a", 1.0, 0.2)
	_rings.set_mode(CosmosRings.Mode.FOUND)
	_appear()


func _on_stopped() -> void:
	if _state == State.HIDDEN or _state == State.FOUND:
		return
	_state = State.HIDDEN
	set_process(false)
	_fade(0.0)


func _appear() -> void:
	set_process(true)
	if not visible:
		modulate.a = 0.0
		show()
	_fade(1.0)


func _fade(target: float) -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", target, 0.2)
	if target == 0.0:
		# Pudo volver a mostrarse (p. ej. cancelar la búsqueda para jugar contra la IA)
		_fade_tween.tween_callback(func(): if _state == State.HIDDEN: hide())


func _show_ai_offer() -> void:
	_ai_offer.visible = true
	_ai_offer.modulate.a = 0.0
	create_tween().tween_property(_ai_offer, "modulate:a", 1.0, 0.35)


func _start_tips() -> void:
	_tip_index = randi() % TIPS.size()
	_tip_elapsed = 0.0
	_tip.text = TIPS[_tip_index]


func _next_tip() -> void:
	_tip_index = (_tip_index + 1) % TIPS.size()
	var tween := create_tween()
	tween.tween_property(_tip, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func(): _tip.text = TIPS[_tip_index])
	tween.tween_property(_tip, "modulate:a", 1.0, 0.25)


func _opponent_name(data: Dictionary) -> String:
	var gs = data.get("game_state", {})
	if gs is Dictionary:
		var my_id := AuthManager.get_user_id()
		var profile = UserManager.get_profile()
		var my_name: String = profile.username if profile else ""
		var p1_is_me: bool = (my_id != "" and str(gs.get("player1_id", "")) == my_id) \
			or (my_name != "" and str(gs.get("player1_name", "")) == my_name)
		var p2_is_me: bool = (my_id != "" and str(gs.get("player2_id", "")) == my_id) \
			or (my_name != "" and str(gs.get("player2_name", "")) == my_name)
		if p1_is_me:
			return str(gs.get("player2_name", "Rival"))
		if p2_is_me:
			return str(gs.get("player1_name", "Rival"))
	return "IA" if data.get("vs_ai", false) else "Rival"


# ============================================================================
# ANILLOS DE COSMOS
# ============================================================================

class CosmosRings extends Control:
	enum Mode { SEARCHING, AI, FOUND }

	const EMBLEM = preload("res://assets/ui-icons/lobby/emblem.svg")

	var _mode := Mode.SEARCHING
	var _t := 0.0
	var _speed := 1.0
	var _color := UIPalette.GOLD

	func set_mode(mode: Mode) -> void:
		_mode = mode
		match mode:
			Mode.SEARCHING:
				_speed = 1.0
				_color = UIPalette.GOLD
			Mode.AI:
				_speed = 1.6
				_color = UIPalette.ACCENT
			Mode.FOUND:
				_speed = 4.0
				_color = UIPalette.GOLD_LIGHT

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_t += delta * _speed
		queue_redraw()

	func _draw() -> void:
		var center := size / 2.0
		var radius := minf(size.x, size.y) / 2.0 - 6.0
		var pulse := 0.5 + 0.5 * sin(_t * 2.2)

		# Halo y pistas de los anillos
		for k in 4:
			draw_circle(center, radius * (0.55 + k * 0.12), UIPalette.alpha(_color, 0.035 + 0.02 * pulse))
		for r in [radius, radius * 0.78, radius * 0.56]:
			draw_arc(center, r, 0, TAU, 96, UIPalette.alpha(UIPalette.EDGE, 0.25), 2.0, true)

		# Tres arcos que giran a distinto ritmo y sentido
		var arcs := [
			[radius, _t * 0.9, 1.9, 6.0],
			[radius * 0.78, -_t * 1.4, 1.3, 4.5],
			[radius * 0.56, _t * 2.1, 2.4, 3.5],
		]
		for arc in arcs:
			var r: float = arc[0]
			var start: float = arc[1]
			var length: float = arc[2]
			var width: float = arc[3]
			draw_arc(center, r, start, start + length, 48, UIPalette.alpha(_color, 0.95), width, true)
			draw_arc(center, r, start + PI, start + PI + length * 0.35, 24, UIPalette.alpha(_color, 0.5), width * 0.6, true)
			# Estrella en la punta del arco
			var tip := center + Vector2.from_angle(start + length) * r
			draw_circle(tip, width * 1.3, UIPalette.alpha(Color.WHITE, 0.9))
			draw_circle(tip, width * 2.6, UIPalette.alpha(_color, 0.3))

		# Emblema central
		var emblem_size := radius * 0.62 * (1.0 + 0.04 * pulse)
		draw_circle(center, emblem_size * 0.72, UIPalette.alpha(UIPalette.NIGHT, 0.9))
		draw_arc(center, emblem_size * 0.72, 0, TAU, 64, UIPalette.alpha(_color, 0.8), 3.0, true)
		var rect := Rect2(center - Vector2.ONE * emblem_size / 2.0, Vector2.ONE * emblem_size)
		draw_texture_rect(EMBLEM, rect, false, UIPalette.alpha(Color.WHITE, 0.95))
