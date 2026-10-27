# ToastNotice.gd
# Aviso flotante breve (éxito o error) abajo y al centro de la pantalla.
# Usa la variación "Toast" del tema del lobby. Ignora repeticiones del mismo
# texto muy seguidas (un mismo error puede llegar por dos servicios a la vez).
class_name ToastNotice
extends PanelContainer

const VISIBLE_SECONDS := 2.8
const DUPLICATE_WINDOW_MS := 1500

var _label: Label
var _tween: Tween
var _last_text := ""
var _last_shown_ms := 0


func _ready() -> void:
	theme_type_variation = &"Toast"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	# Anclado abajo al centro; si el texto ocupa varias líneas crece hacia arriba
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = -220.0
	offset_right = 220.0
	offset_top = -96.0
	offset_bottom = -40.0

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_label)


func show_message(text: String, is_error := false) -> void:
	var now := Time.get_ticks_msec()
	if text == _last_text and now - _last_shown_ms < DUPLICATE_WINDOW_MS:
		return
	_last_text = text
	_last_shown_ms = now

	_label.text = text
	_label.add_theme_color_override("font_color", Color(1, 0.6, 0.6) if is_error else Color(1, 0.92, 0.75))
	visible = true
	modulate.a = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.2)
	_tween.tween_interval(VISIBLE_SECONDS)
	_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	_tween.tween_callback(func(): visible = false)
