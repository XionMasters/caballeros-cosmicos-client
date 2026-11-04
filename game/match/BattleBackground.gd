# BattleBackground.gd
# Fondo de la partida.
#   - Base: cosmos animado (mismo shader que los menús, sin ilustración).
#   - Con una carta de escenario en juego: la ilustración grande de ese escenario
#     a pantalla completa, con fundido, oscurecida para que el tablero se lea encima.
#
# Las ilustraciones las sirve el servidor en /assets/stage-backgrounds/{code}.webp
# (Server-SS/src/assets/stage-backgrounds/). Si un escenario aún no tiene la suya,
# se mantiene el fondo base.
class_name BattleBackground
extends Control

const COSMOS_SHADER := preload("res://assets/shaders/cosmos_background.gdshader")
const STAGE_BG_PATH := "/assets/stage-backgrounds/%s.webp"
const FADE_SECONDS := 0.8
## Oscurecido sobre la ilustración del escenario (0 = sin oscurecer, 1 = negro)
const STAGE_SHADE_ALPHA := 0.6

var _cosmos: ColorRect
var _cosmos_material: ShaderMaterial
var _stage_art: TextureRect
var _shade: ColorRect
var _fade: Tween

var _current_code := ""
## code -> Texture2D, o null si el servidor no tiene ilustración para ese escenario
var _texture_cache := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_cosmos = ColorRect.new()
	_cosmos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cosmos_material = ShaderMaterial.new()
	_cosmos_material.shader = COSMOS_SHADER
	_cosmos.material = _cosmos_material
	add_child(_cosmos)
	_cosmos.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_stage_art = TextureRect.new()
	_stage_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_stage_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_stage_art.modulate.a = 0.0
	add_child(_stage_art)
	_stage_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_shade = ColorRect.new()
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.color = UIPalette.alpha(UIPalette.ABYSS, STAGE_SHADE_ALPHA)
	_shade.modulate.a = 0.0
	add_child(_shade)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	resized.connect(_on_resized)
	_on_resized()


func _on_resized() -> void:
	if _cosmos_material and size.y > 0.0:
		_cosmos_material.set_shader_parameter("aspect", size.x / size.y)


## Muestra la ilustración del escenario en juego, o vuelve al fondo base si `stage` es null.
func set_stage(stage: CardInstance) -> void:
	var code := _stage_code(stage)
	if code == _current_code:
		return
	_current_code = code

	if code.is_empty():
		_show_texture(null)
		return

	if _texture_cache.has(code):
		_show_texture(_texture_cache[code])
		return

	ApiClient.get_image_with_callback(STAGE_BG_PATH % code, func(image: Image, _tag = null) -> void:
		var texture: Texture2D = ImageTexture.create_from_image(image) if image else null
		_texture_cache[code] = texture
		if texture == null:
			print("[BattleBackground] El escenario '%s' aún no tiene ilustración grande; se mantiene el fondo base" % code)
		# Solo aplicarla si sigue siendo el escenario en juego cuando llega la descarga
		if is_instance_valid(self) and code == _current_code:
			_show_texture(texture)
	, "stage_bg_%s" % code)


func _stage_code(stage: CardInstance) -> String:
	if stage == null or stage.base_data == null:
		return ""
	if not stage.base_data.code.is_empty():
		return stage.base_data.code
	# Respaldo: el image_url de la carta compuesta es /assets/cards/{code}.webp
	return stage.base_data.image_url.get_file().get_basename()


func _show_texture(texture: Texture2D) -> void:
	if _fade and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()

	# Si ya hay un escenario visible, se desvanece antes de cambiar
	if _stage_art.modulate.a > 0.01:
		_fade.tween_property(_stage_art, "modulate:a", 0.0, FADE_SECONDS * 0.5)
		_fade.parallel().tween_property(_shade, "modulate:a", 0.0, FADE_SECONDS * 0.5)

	_fade.tween_callback(func() -> void: _stage_art.texture = texture)

	if texture:
		_fade.tween_property(_stage_art, "modulate:a", 1.0, FADE_SECONDS).set_trans(Tween.TRANS_SINE)
		_fade.parallel().tween_property(_shade, "modulate:a", 1.0, FADE_SECONDS).set_trans(Tween.TRANS_SINE)
