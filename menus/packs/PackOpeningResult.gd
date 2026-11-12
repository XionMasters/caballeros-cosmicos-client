# PackOpeningResult.gd
# Apertura de sobres: el sobre tiembla y estalla en un destello, las cartas caen boca abajo
# (con un halo del color de su rareza como pista) y se revelan al pulsarlas, de la más
# común a la mejor. «Revelar todo» las voltea seguidas; al terminar, resumen y «Continuar».
#
# API usada por la tienda: show_cards(pack_name, cards) y la señal `closed`.
extends Control

signal closed

const CARD_RATIO := 1.5
const MAX_CARD_W := 232.0
const GAP := 26.0
const SIDE_MARGIN := 70.0

var _session := 0
var _pack_name := ""
# Datos del sobre abierto (code, nombre…) para elegir su arte
var _pack_data: Dictionary = {}
var _reveal_cards: Array = []
var _revealing_all := false
var _finished := false

var _dim: ColorRect
var _rays: Rays
var _title: Label
var _subtitle: Label
var _pack: TextureRect
var _flash: ColorRect
var _cards_layer: Control
var _hint: Label
var _summary: Label
var _button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") and _finished:
		get_viewport().set_input_as_handled()
		_close()


# ============================================================================
# CONSTRUCCIÓN
# ============================================================================

func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.color = UIPalette.alpha(UIPalette.ABYSS, 0.94)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_rays = Rays.new()
	_rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rays)

	var header := VBoxContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	header.offset_top = 28
	header.grow_horizontal = Control.GROW_DIRECTION_BOTH
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", -4)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)

	_subtitle = Label.new()
	_subtitle.theme_type_variation = &"PlayHint"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_color_override("font_color", UIPalette.ACCENT)
	header.add_child(_subtitle)

	_title = Label.new()
	_title.theme_type_variation = &"HeroTitle"
	_title.add_theme_font_size_override("font_size", 46)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_title)

	_pack = TextureRect.new()
	_pack.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pack.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pack)

	_cards_layer = Control.new()
	_cards_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cards_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cards_layer)

	var footer := VBoxContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	footer.offset_bottom = -30
	footer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 12)
	add_child(footer)

	_hint = Label.new()
	_hint.theme_type_variation = &"Caption"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.text = "Toca una carta para revelarla"
	footer.add_child(_hint)

	_summary = Label.new()
	_summary.theme_type_variation = &"Subtitle"
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(_summary)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_child(button_row)

	_button = Button.new()
	_button.custom_minimum_size = Vector2(300, 64)
	_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_button.add_theme_font_size_override("font_size", 24)
	_button.pressed.connect(_on_button_pressed)
	button_row.add_child(_button)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)


# ============================================================================
# FLUJO
# ============================================================================

func show_cards(pack_name: String, cards: Array, pack_data: Dictionary = {}) -> void:
	_session += 1
	var session := _session
	_pack_name = pack_name
	_pack_data = pack_data
	_finished = false
	_revealing_all = false
	_clear_cards()

	# De la más común a la mejor: la última carta es la sorpresa
	var sorted := cards.duplicate()
	sorted.sort_custom(func(a, b): return _rank(a) < _rank(b))

	var best: Dictionary = sorted.back() if not sorted.is_empty() else {}
	var best_color := PackArt.rarity_color(str(best.get("rarity", "common")))
	_rays.color = UIPalette.alpha(best_color.lerp(UIPalette.GOLD, 0.4), 0.065)
	_rays.modulate.a = 0.0

	_subtitle.text = pack_name.to_upper()
	_title.text = "ABRIENDO SOBRE…"
	_title.modulate.a = 0.0
	_subtitle.modulate.a = 0.0
	_hint.visible = false
	_summary.visible = false
	_button.visible = false
	modulate.a = 1.0
	scale = Vector2.ONE
	show()

	await _play_pack_intro(session)
	if session != _session:
		return
	await _deal_cards(sorted, session)
	if session != _session:
		return

	_title.text = "¡SOBRE ABIERTO!"
	_hint.visible = true
	_set_button("REVELAR TODO", &"GhostButton")
	_button.visible = true


func _play_pack_intro(session: int) -> void:
	var view := size
	var pack_size := Vector2(240, 330)
	_pack.texture = PackArt.texture_for(_pack_data if not _pack_data.is_empty() else {"name": _pack_name})
	_pack.size = pack_size
	_pack.pivot_offset = pack_size / 2.0
	_pack.position = view / 2.0 - pack_size / 2.0
	_pack.scale = Vector2(0.55, 0.55)
	_pack.modulate = Color(1, 1, 1, 0)
	_pack.rotation = 0.0
	_pack.visible = true

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_dim, "modulate:a", 1.0, 0.2).from(0.0)
	tween.tween_property(_pack, "modulate:a", 1.0, 0.25)
	tween.tween_property(_pack, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_rays, "modulate:a", 1.0, 0.6)
	tween.tween_property(_subtitle, "modulate:a", 1.0, 0.4)
	tween.tween_property(_title, "modulate:a", 1.0, 0.4)
	await tween.finished
	if session != _session:
		return

	# Tiembla cada vez más fuerte mientras se carga de luz
	var base := _pack.position
	var shake := create_tween()
	for i in 12:
		var strength := 2.0 + i * 1.1
		shake.tween_property(_pack, "position", base + Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), 0.05)
		shake.parallel().tween_property(_pack, "rotation", randf_range(-0.05, 0.05) * (1.0 + i * 0.15), 0.05)
	shake.parallel().tween_property(_pack, "modulate", Color(1.6, 1.5, 1.3, 1), 0.6)
	await shake.finished
	if session != _session:
		return

	# Estallido
	var burst := create_tween().set_parallel(true)
	burst.tween_property(_flash, "color:a", 0.95, 0.1)
	burst.tween_property(_pack, "scale", Vector2(1.5, 1.5), 0.12)
	await burst.finished
	_pack.visible = false
	var fade := create_tween()
	fade.tween_property(_flash, "color:a", 0.0, 0.45).set_ease(Tween.EASE_OUT)


func _deal_cards(cards: Array, session: int) -> void:
	var layout := _layout(cards.size())
	var card_size: Vector2 = layout["size"]
	var positions: Array = layout["positions"]
	var center := size / 2.0

	for i in cards.size():
		var reveal := RevealCard.new()
		reveal.setup(cards[i], card_size)
		reveal.position = center - card_size / 2.0
		reveal.scale = Vector2(0.25, 0.25)
		reveal.rotation = randf_range(-0.6, 0.6)
		reveal.modulate.a = 0.0
		reveal.revealed.connect(_on_card_revealed)
		reveal.inspect_requested.connect(_on_inspect)
		_cards_layer.add_child(reveal)
		_reveal_cards.append(reveal)

		var tween := create_tween().set_parallel(true)
		tween.tween_property(reveal, "position", positions[i], 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(reveal, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(reveal, "rotation", 0.0, 0.42)
		tween.tween_property(reveal, "modulate:a", 1.0, 0.2)
		await get_tree().create_timer(0.09).timeout
		if session != _session:
			return
	await get_tree().create_timer(0.35).timeout


func _layout(count: int) -> Dictionary:
	var view := size
	var rows := 1 if count <= 6 else 2
	var per_row := int(ceil(float(count) / rows))
	var available_w := view.x - SIDE_MARGIN * 2.0
	var w := minf(MAX_CARD_W, (available_w - GAP * (per_row - 1)) / per_row)
	var max_h := (view.y - 290.0 - GAP * (rows - 1)) / rows
	w = minf(w, max_h / CARD_RATIO)
	var card_size := Vector2(w, w * CARD_RATIO)

	var total_h := rows * card_size.y + (rows - 1) * (GAP + 22.0)
	var top := view.y / 2.0 - total_h / 2.0 + 4.0
	var positions := []
	for i in count:
		var row := i / per_row
		var in_row := mini(per_row, count - row * per_row)
		var col := i - row * per_row
		var row_w := in_row * card_size.x + (in_row - 1) * GAP
		var x := view.x / 2.0 - row_w / 2.0 + col * (card_size.x + GAP)
		var y := top + row * (card_size.y + GAP + 22.0)
		positions.append(Vector2(x, y))
	return {"size": card_size, "positions": positions}


func _on_button_pressed() -> void:
	if _finished:
		_close()
	else:
		_reveal_all()


func _reveal_all() -> void:
	if _revealing_all:
		return
	_revealing_all = true
	_button.disabled = true
	var session := _session
	for reveal in _reveal_cards:
		if session != _session:
			return
		if is_instance_valid(reveal) and not reveal.is_revealed:
			reveal.reveal()
			await get_tree().create_timer(0.22).timeout


func _on_card_revealed(reveal: RevealCard) -> void:
	# Las legendarias y divinas sacuden la pantalla
	if reveal.rank >= UIPalette.rarity_rank("legendary"):
		_shake_screen()
	for r in _reveal_cards:
		if is_instance_valid(r) and not r.is_revealed:
			return
	_on_all_revealed()


func _on_all_revealed() -> void:
	_finished = true
	_hint.text = "Toca una carta para ver su detalle"
	_summary.text = _summary_text()
	_summary.visible = true
	_summary.modulate.a = 0.0
	create_tween().tween_property(_summary, "modulate:a", 1.0, 0.3)
	_button.disabled = false
	_set_button("CONTINUAR", &"PlayButton")


func _summary_text() -> String:
	var counts := {}
	var news := 0
	var foils := 0
	for reveal in _reveal_cards:
		var key := PackArt.normalize_rarity(str(reveal.card_json.get("rarity", "common")))
		counts[key] = int(counts.get(key, 0)) + 1
		if reveal.card_json.get("is_new", false):
			news += 1
		if reveal.card_json.get("is_foil", false):
			foils += 1
	var parts := []
	var order := UIPalette.RARITY_ORDER.duplicate()
	order.reverse()
	for key in order:
		if counts.has(key):
			parts.append("%d %s" % [counts[key], _rarity_plural(key, counts[key])])
	if news > 0:
		parts.append("%d %s" % [news, "nueva" if news == 1 else "nuevas"])
	if foils > 0:
		parts.append("%d foil" % foils)
	# Garantía: la épica que trae el sobre tras 10 seguidos sin épica o superior
	for reveal in _reveal_cards:
		if reveal.card_json.get("from_guarantee", false):
			parts.append("épica asegurada")
			break
	return "  ·  ".join(parts)


func _rarity_plural(key: String, count: int) -> String:
	var label := PackArt.rarity_label(key).to_lower()
	if count == 1:
		return label
	return label + ("es" if label.ends_with("n") else "s")


func _on_inspect(reveal: RevealCard) -> void:
	var card := CardData.from_json(reveal.card_json)
	var texture = CardsManager._image_cache.get(card.id, null)
	CardDetailManager.show_card(card, texture)


func _set_button(text: String, variation: StringName) -> void:
	_button.text = text
	_button.theme_type_variation = variation


func _shake_screen() -> void:
	var tween := create_tween()
	for i in 6:
		var s := 9.0 - i * 1.4
		tween.tween_property(_cards_layer, "position", Vector2(randf_range(-s, s), randf_range(-s, s)), 0.04)
	tween.tween_property(_cards_layer, "position", Vector2.ZERO, 0.05)


func _close() -> void:
	_session += 1
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.22)
	await tween.finished
	hide()
	_clear_cards()
	closed.emit()


func _clear_cards() -> void:
	for reveal in _reveal_cards:
		if is_instance_valid(reveal):
			reveal.queue_free()
	_reveal_cards.clear()
	_cards_layer.position = Vector2.ZERO
	_button.disabled = false


static func _rank(card_json: Dictionary) -> int:
	return UIPalette.rarity_rank(PackArt.normalize_rarity(str(card_json.get("rarity", "common"))))


# ============================================================================
# CARTA BOCA ABAJO QUE SE REVELA
# ============================================================================

class RevealCard extends Control:
	signal revealed(card: RevealCard)
	signal inspect_requested(card: RevealCard)

	const CARD_DISPLAY = preload("res://cards/CardDisplay.tscn")

	var card_json: Dictionary = {}
	var rank := 0
	var is_revealed := false

	var _color := Color.WHITE
	var _glow: Panel
	var _back: TextureRect
	var _front: Control
	var _rarity_label: Label
	var _new_badge: Label
	var _pulse: Tween

	func setup(json: Dictionary, card_size: Vector2) -> void:
		card_json = json
		rank = maxi(0, UIPalette.rarity_rank(PackArt.normalize_rarity(str(json.get("rarity", "common")))))
		_color = PackArt.rarity_color(str(json.get("rarity", "common")))
		size = card_size
		custom_minimum_size = card_size
		pivot_offset = card_size / 2.0
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		# Halo: pista de rareza boca abajo (raras en adelante), más intenso al revelar
		_glow = Panel.new()
		_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_glow.position = Vector2(4, 4)
		_glow.size = card_size - Vector2(8, 8)
		var glow_style := StyleBoxFlat.new()
		glow_style.bg_color = Color(0, 0, 0, 0)
		glow_style.set_corner_radius_all(12)
		glow_style.shadow_color = UIPalette.alpha(_color, 0.75)
		glow_style.shadow_size = 10 + maxi(0, rank - UIPalette.rarity_rank("uncommon")) * 8
		_glow.add_theme_stylebox_override("panel", glow_style)
		_glow.modulate.a = 0.0 if rank < UIPalette.rarity_rank("rare") else 0.55
		add_child(_glow)

		_back = TextureRect.new()
		_back.texture = CardsManager.get_default_card_back()
		_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_back.stretch_mode = TextureRect.STRETCH_SCALE
		_back.size = card_size
		_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_back)

		var front = CARD_DISPLAY.instantiate()
		front.mouse_filter = Control.MOUSE_FILTER_IGNORE
		front.visible = false
		add_child(front)
		if front.has_method("set_display_size"):
			front.set_display_size(card_size)
		front.setup(CardData.from_json(json))
		front.position = Vector2.ZERO
		_front = front

		_rarity_label = Label.new()
		_rarity_label.text = PackArt.rarity_label(str(json.get("rarity", "common"))).to_upper() \
			+ ("  ·  FOIL" if json.get("is_foil", false) else "") \
			+ ("  ·  ASEGURADA" if json.get("from_guarantee", false) else "")
		_rarity_label.theme_type_variation = &"PlayHint"
		_rarity_label.add_theme_color_override("font_color", _color)
		_rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_rarity_label.position = Vector2(-20, card_size.y + 6)
		_rarity_label.size = Vector2(card_size.x + 40, 22)
		_rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rarity_label.modulate.a = 0.0
		add_child(_rarity_label)

		_new_badge = Label.new()
		_new_badge.text = "NUEVA"  # la fuente de las insignias no tiene «¡»
		_new_badge.theme_type_variation = &"BadgeLabel"
		_new_badge.add_theme_font_size_override("font_size", 15)
		_new_badge.add_theme_color_override("font_color", UIPalette.ON_GOLD)
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = UIPalette.ACCENT
		badge_style.set_corner_radius_all(8)
		badge_style.content_margin_left = 10
		badge_style.content_margin_right = 10
		badge_style.content_margin_top = 2
		badge_style.content_margin_bottom = 2
		_new_badge.add_theme_stylebox_override("normal", badge_style)
		_new_badge.position = Vector2(card_size.x / 2.0 - 34, -14)
		_new_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_new_badge.visible = false
		add_child(_new_badge)

		gui_input.connect(_on_gui_input)
		mouse_entered.connect(func(): _hover(true))
		mouse_exited.connect(func(): _hover(false))

		if rank >= UIPalette.rarity_rank("rare"):
			_pulse = create_tween().set_loops()
			_pulse.tween_property(_glow, "modulate:a", 0.95, 0.7).set_trans(Tween.TRANS_SINE)
			_pulse.tween_property(_glow, "modulate:a", 0.4, 0.7).set_trans(Tween.TRANS_SINE)

	func _on_gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			if is_revealed:
				inspect_requested.emit(self)
			else:
				reveal()

	func _hover(entered: bool) -> void:
		var target := Vector2(1.06, 1.06) if entered else Vector2.ONE
		create_tween().tween_property(self, "scale", target, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func reveal() -> void:
		if is_revealed:
			return
		is_revealed = true
		if _pulse:
			_pulse.kill()

		var flip := create_tween()
		flip.tween_property(self, "scale:x", 0.0, 0.12).set_ease(Tween.EASE_IN)
		flip.tween_callback(func():
			_back.visible = false
			_front.visible = true
			if card_json.get("is_new", false):
				_new_badge.visible = true
		)
		flip.tween_property(self, "scale:x", 1.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		flip.parallel().tween_property(_rarity_label, "modulate:a", 1.0, 0.25)
		var rare_rank := UIPalette.rarity_rank("rare")
		flip.parallel().tween_property(_glow, "modulate:a", 1.0 if rank > rare_rank else (0.6 if rank == rare_rank else 0.0), 0.25)
		flip.tween_callback(func():
			_burst()
			revealed.emit(self)
		)
		if card_json.get("is_foil", false):
			var shimmer := create_tween().set_loops()
			shimmer.tween_property(_glow, "self_modulate", UIPalette.MAGENTA, 0.6)
			shimmer.tween_property(_glow, "self_modulate", UIPalette.ACCENT, 0.6)

	func _burst() -> void:
		# Anillo de luz que se expande desde la carta
		var ring := Panel.new()
		var ring_style := StyleBoxFlat.new()
		ring_style.bg_color = Color(0, 0, 0, 0)
		ring_style.border_color = _color
		ring_style.set_border_width_all(4 if rank < UIPalette.rarity_rank("legendary") else 6)
		ring_style.set_corner_radius_all(int(size.x))
		ring.add_theme_stylebox_override("panel", ring_style)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var d := size.x * 0.9
		ring.size = Vector2(d, d)
		ring.position = size / 2.0 - ring.size / 2.0
		ring.pivot_offset = ring.size / 2.0
		ring.scale = Vector2(0.5, 0.5)
		add_child(ring)
		var tween := ring.create_tween().set_parallel(true)
		tween.tween_property(ring, "scale", Vector2(1.6 + rank * 0.25, 1.6 + rank * 0.25), 0.45).set_ease(Tween.EASE_OUT)
		tween.tween_property(ring, "modulate:a", 0.0, 0.45)
		tween.chain().tween_callback(ring.queue_free)


# ============================================================================
# RAYOS DE FONDO
# ============================================================================

class Rays extends Control:
	var color := Color(1, 0.8, 0.3, 0.1)
	var _spin := 0.0

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_spin += delta * 0.12
		queue_redraw()

	func _draw() -> void:
		var center := size / 2.0
		var radius := size.length()
		for i in 18:
			var angle := _spin + TAU * i / 18.0
			var points := PackedVector2Array([
				center,
				center + Vector2.from_angle(angle - 0.06) * radius,
				center + Vector2.from_angle(angle + 0.06) * radius,
			])
			draw_colored_polygon(points, color)
		for k in 5:
			draw_circle(center, 300.0 - k * 55.0, Color(color.r, color.g, color.b, color.a * 0.6))
