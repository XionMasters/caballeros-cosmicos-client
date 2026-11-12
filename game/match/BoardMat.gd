# BoardMat.gd
# Tapete del tablero, dibujado detrás de las cartas:
#   - un panel translúcido por cada mitad del campo (rival arriba, propio abajo),
#   - la línea central entre ambas mitades,
#   - el rótulo de turno sobre esa línea ("Tu turno" / "Turno del rival" · ronda).
# Se coloca a partir de las filas reales del tablero, así que se adapta al layout.
extends Control

const PADDING := 16.0
const RADIUS := 18

var _opponent_rows: Array = []
var _player_rows: Array = []
var _last_rects := []

var _banner: PanelContainer
var _banner_title: Label
var _banner_sub: Label
var _banner_tween: Tween

# Rótulo gigante que cruza la pantalla al cambiar de turno (en su propia capa, encima de todo)
var _swoosh_layer: CanvasLayer
var _swoosh_band: Panel
var _swoosh_label: Label
var _swoosh_tween: Tween
var _last_turn_key := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_banner()
	_build_swoosh()


func setup(opponent_rows: Array, player_rows: Array) -> void:
	_opponent_rows = opponent_rows
	_player_rows = player_rows
	queue_redraw()


func set_turn(title: String, subtitle: String, is_mine: bool) -> void:
	# Solo al cambiar de turno (no en cada actualización del estado)
	var key := "%s|%s" % [title, subtitle]
	if key != _last_turn_key:
		var first := _last_turn_key == ""
		_last_turn_key = key
		if not first or is_mine:
			_play_swoosh(title, is_mine)

	_banner.theme_type_variation = &"CurrencyPill" if is_mine else &"Chip"
	_banner_title.text = title.to_upper()
	_banner_sub.text = subtitle.to_upper()
	_banner_title.add_theme_color_override("font_color", UIPalette.GOLD_LIGHT if is_mine else UIPalette.TEXT_MUTED)
	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner.modulate = Color.WHITE
	if is_mine:
		# Pulso suave cuando te toca
		_banner_tween = create_tween().set_loops()
		_banner_tween.tween_property(_banner, "modulate", Color(1.15, 1.1, 0.95), 1.1).set_trans(Tween.TRANS_SINE)
		_banner_tween.tween_property(_banner, "modulate", Color.WHITE, 1.1).set_trans(Tween.TRANS_SINE)
	_place_banner()


func _process(_delta: float) -> void:
	# Redibujar solo si las filas se movieron o cambiaron de tamaño
	var rects := [_union(_opponent_rows), _union(_player_rows)]
	if rects != _last_rects:
		_last_rects = rects
		queue_redraw()
		_place_banner()


func _draw() -> void:
	var opponent := _union(_opponent_rows)
	var player := _union(_player_rows)
	if opponent.size == Vector2.ZERO or player.size == Vector2.ZERO:
		return

	_draw_half(opponent.grow(PADDING), UIPalette.alpha(UIPalette.GOLD, 0.16))
	_draw_half(player.grow(PADDING), UIPalette.alpha(UIPalette.GOLD, 0.3))

	# Línea central entre las dos mitades, que se desvanece hacia los lados
	var y := (opponent.end.y + player.position.y) * 0.5
	var left := minf(opponent.position.x, player.position.x) - PADDING
	var right := maxf(opponent.end.x, player.end.x) + PADDING
	var segments := 24
	for i in segments:
		var t0 := float(i) / segments
		var t1 := float(i + 1) / segments
		var fade := 1.0 - absf((t0 + t1) - 1.0)  # 0 en los extremos, 1 en el centro
		draw_line(Vector2(lerpf(left, right, t0), y), Vector2(lerpf(left, right, t1), y),
			UIPalette.alpha(UIPalette.GOLD, 0.45 * fade), 2.0)


func _draw_half(rect: Rect2, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = UIPalette.alpha(UIPalette.ABYSS, 0.42)
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 12
	draw_style_box(style, rect)


func _union(rows: Array) -> Rect2:
	"""Rectángulo (en coordenadas locales) que cubre las posiciones de esas filas."""
	var result := Rect2()
	var first := true
	for row in rows:
		if not (row is Control) or not is_instance_valid(row) or not row.is_visible_in_tree():
			continue
		# Solo las posiciones (CardSlot), no todo el ancho del contenedor
		for slot in row.find_children("*", "", true, false):
			if not (slot is CardSlot):
				continue
			var r := Rect2(slot.global_position - global_position, slot.size)
			result = r if first else result.merge(r)
			first = false
	return result


func _place_banner() -> void:
	if not _banner:
		return
	var opponent := _union(_opponent_rows)
	var player := _union(_player_rows)
	if opponent.size == Vector2.ZERO or player.size == Vector2.ZERO:
		_banner.visible = false
		return
	_banner.visible = true
	_banner.reset_size()
	var center_x := (minf(opponent.position.x, player.position.x) + maxf(opponent.end.x, player.end.x)) * 0.5
	var y := (opponent.end.y + player.position.y) * 0.5
	_banner.position = Vector2(center_x, y) - _banner.size * 0.5


func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.theme_type_variation = &"Chip"
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_banner.add_child(box)
	_banner_title = Label.new()
	_banner_title.theme_type_variation = &"SectionTitle"
	box.add_child(_banner_title)
	_banner_sub = Label.new()
	_banner_sub.theme_type_variation = &"Eyebrow"
	_banner_sub.add_theme_font_size_override("font_size", 16)
	_banner_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(_banner_sub)
	_banner.visible = false


func _build_swoosh() -> void:
	_swoosh_layer = CanvasLayer.new()
	_swoosh_layer.layer = 20
	add_child(_swoosh_layer)

	_swoosh_band = Panel.new()
	_swoosh_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_swoosh_band.visible = false
	_swoosh_layer.add_child(_swoosh_band)

	_swoosh_label = Label.new()
	_swoosh_label.theme = load("res://ui/theme/cosmic_theme.tres")
	_swoosh_label.theme_type_variation = &"HeroTitle"
	_swoosh_label.add_theme_font_size_override("font_size", 110)
	_swoosh_label.add_theme_constant_override("outline_size", 16)
	_swoosh_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_swoosh_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_swoosh_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_swoosh_band.add_child(_swoosh_label)
	_swoosh_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _play_swoosh(title: String, is_mine: bool) -> void:
	"""Una franja inclinada cruza la pantalla con «¡TU TURNO!» o el turno del rival"""
	if not _swoosh_band:
		return
	var view := get_viewport_rect().size
	var accent := UIPalette.GOLD if is_mine else UIPalette.LIFE

	var style := StyleBoxFlat.new()
	style.bg_color = UIPalette.alpha(UIPalette.ABYSS, 0.88)
	style.border_color = accent
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.skew = Vector2(0.25, 0)
	style.shadow_color = UIPalette.alpha(accent, 0.45)
	style.shadow_size = 30
	_swoosh_band.add_theme_stylebox_override("panel", style)

	_swoosh_label.text = ("¡%s!" % title.to_upper()) if is_mine else title.to_upper()
	_swoosh_label.add_theme_color_override("font_color", UIPalette.GOLD_LIGHT if is_mine else Color.WHITE)
	_swoosh_label.add_theme_color_override("font_shadow_color", UIPalette.alpha(accent, 0.6))

	var band_size := Vector2(view.x * 1.3, 170)
	var center := Vector2((view.x - band_size.x) / 2.0, (view.y - band_size.y) / 2.0)
	_swoosh_band.size = band_size
	_swoosh_band.position = center + Vector2(-view.x, 0)
	_swoosh_band.modulate.a = 1.0
	_swoosh_band.visible = true

	if _swoosh_tween and _swoosh_tween.is_valid():
		_swoosh_tween.kill()
	_swoosh_tween = create_tween()
	_swoosh_tween.tween_property(_swoosh_band, "position", center, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_swoosh_tween.tween_interval(0.75)
	_swoosh_tween.tween_property(_swoosh_band, "position", center + Vector2(view.x, 0), 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_swoosh_tween.tween_callback(func(): _swoosh_band.visible = false)
