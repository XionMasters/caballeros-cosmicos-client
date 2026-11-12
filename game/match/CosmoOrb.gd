# CosmoOrb.gd
# Orbe junto a «Terminar turno» con el cosmo del jugador local: el recurso que gasta
# en su turno, a la vista y grande. Lo actualiza StatusPanelController.
class_name CosmoOrb
extends Control

const MAX_COSMOS := 12  ## BASE_MATCH_RULES.max_cosmos del servidor

var _value := 0
var _maximum := MAX_COSMOS
var _label: Label
var _glow := 0.0  ## 0..1, sube un momento al ganar cosmo


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_label = Label.new()
	_label.theme_type_variation = &"StatValue"
	_label.add_theme_font_size_override("font_size", 44)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.text = str(_value)
	resized.connect(queue_redraw)


func set_value(value: int, maximum: int = MAX_COSMOS) -> void:
	var gained := value > _value
	var changed := value != _value
	_value = value
	_maximum = maxi(maximum, 1)
	if _label:
		_label.text = str(value)
	tooltip_text = "Tu cosmo: %d / %d" % [value, _maximum]
	queue_redraw()
	if changed and _label:
		_label.pivot_offset = _label.size / 2.0
		var pop := create_tween()
		pop.tween_property(_label, "scale", Vector2(1.35, 1.35), 0.1)
		pop.tween_property(_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if gained:
		var flash := create_tween()
		flash.tween_method(_set_glow, 1.0, 0.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_glow(value: float) -> void:
	_glow = value
	queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - 4.0
	var base := UIPalette.COSMOS

	# Halo exterior (más fuerte justo después de ganar cosmo)
	for i in 6:
		var t := float(i) / 6.0
		draw_circle(center, radius + 2.0 + 10.0 * t, UIPalette.alpha(base, (0.16 + 0.3 * _glow) * (1.0 - t)))

	# Cuerpo del orbe: oscuro abajo, claro arriba
	draw_circle(center, radius, base.darkened(0.45))
	draw_circle(center + Vector2(0, -radius * 0.12), radius * 0.86, base.darkened(0.1))
	draw_circle(center + Vector2(-radius * 0.28, -radius * 0.38), radius * 0.28, Color(1, 1, 1, 0.22))

	# Arco de progreso: cuánto cosmo hay respecto al máximo
	var fraction := clampf(float(_value) / float(_maximum), 0.0, 1.0)
	draw_arc(center, radius - 1.0, 0.0, TAU, 64, Color(1, 1, 1, 0.18), 4.0, true)
	if fraction > 0.0:
		draw_arc(center, radius - 1.0, -PI / 2.0, -PI / 2.0 + TAU * fraction, 64, Color(0.86, 0.93, 1.0), 4.0, true)
