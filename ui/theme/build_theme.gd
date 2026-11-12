extends SceneTree
## Genera ui/theme/cosmic_theme.tres (el tema global del cliente) a partir de UIPalette.
##
## El .tres es un archivo generado: para cambiar el aspecto, edita este script o la
## paleta y vuelve a ejecutarlo desde la carpeta del proyecto:
##   Godot_v4.5.1-stable_win64_console.exe --headless --path . --script res://ui/theme/build_theme.gd
##
## Estilo: botones "gruesos" con canto inferior (relieve), el principal en oro y
## ligeramente inclinado; tipografía condensada e itálica para títulos y botones;
## paneles de cristal oscuro con borde luminoso.

const P := preload("res://ui/theme/UIPalette.gd")
const OUT := "res://ui/theme/cosmic_theme.tres"

## Inclinación de los botones principales (paralelogramo)
const SKEW := Vector2(0.18, 0.0)

var _display: Font   ## Títulos grandes y botón JUGAR (Black Italic)
var _heading: Font   ## Títulos de sección y pestañas (ExtraBold Italic)
var _ui: Font        ## Botones (Bold)
var _ui_semi: Font   ## Botones secundarios y chips (SemiBold)
var _body: Font      ## Texto corrido (Inter 400)
var _body_semi: Font ## Texto destacado (Inter 600)


func _init() -> void:
	_load_fonts()
	var theme := Theme.new()
	theme.default_font = _body
	theme.default_font_size = 18

	_labels(theme)
	_buttons(theme)
	_panels(theme)
	_inputs(theme)
	_tabs(theme)
	_misc(theme)
	_nav_bar(theme)

	var err := ResourceSaver.save(theme, OUT)
	if err == OK:
		print("[build_theme] Tema guardado en %s" % OUT)
	else:
		push_error("[build_theme] No se pudo guardar el tema (%d)" % err)
	quit(err)


# ─────────────────────────────────────────────────────────────────────────────
# Fuentes
# ─────────────────────────────────────────────────────────────────────────────

func _load_fonts() -> void:
	_display = load("res://assets/fonts/BarlowCondensed-BlackItalic.ttf")
	_heading = load("res://assets/fonts/BarlowCondensed-ExtraBoldItalic.ttf")
	_ui = load("res://assets/fonts/BarlowCondensed-Bold.ttf")
	_ui_semi = load("res://assets/fonts/BarlowCondensed-SemiBold.ttf")

	var inter: FontFile = load("res://assets/fonts/Inter-Variable.ttf")
	_body = _inter(inter, 400)
	_body_semi = _inter(inter, 600)


func _inter(base: FontFile, weight: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = base
	# 2003265652 = etiqueta OpenType "wght"
	font.variation_opentype = { 2003265652: weight }
	return font


# ─────────────────────────────────────────────────────────────────────────────
# Ayudas para estilos
# ─────────────────────────────────────────────────────────────────────────────

func _box(bg: Color, radius := 12, border := Color.TRANSPARENT, border_width := 0,
		margin := Vector4(14, 10, 14, 10)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border_width > 0:
		s.set_border_width_all(border_width)
		s.border_color = border
	s.content_margin_left = margin.x
	s.content_margin_top = margin.y
	s.content_margin_right = margin.z
	s.content_margin_bottom = margin.w
	s.anti_aliasing = true
	return s


func _shadow(s: StyleBoxFlat, color: Color, size: int, offset := Vector2.ZERO) -> StyleBoxFlat:
	s.shadow_color = color
	s.shadow_size = size
	s.shadow_offset = offset
	return s


func _empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


## Juego de estilos de un botón con relieve: la cara del botón y un "canto" sólido
## debajo (sombra desplazada). Al pulsar, el canto se reduce y el texto baja.
func _chunky(theme: Theme, type: String, face: Color, face_hover: Color, border: Color,
		slab: Color, radius: int, margin: Vector2, depth := 5, skew := Vector2.ZERO,
		border_width := 2) -> void:
	var m := Vector4(margin.x, margin.y, margin.x, margin.y)

	var normal := _shadow(_box(face, radius, border, border_width, m), slab, 1, Vector2(0, depth))
	normal.skew = skew

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = face_hover
	hover.border_color = border.lightened(0.25)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = face.darkened(0.12)
	pressed.shadow_offset = Vector2(0, 1)
	pressed.content_margin_top = margin.y + depth - 1
	pressed.content_margin_bottom = maxf(margin.y - depth + 1, 0)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(face.lerp(P.NIGHT, 0.65), 0.85)
	disabled.border_color = P.alpha(border, 0.25)
	disabled.shadow_color = P.alpha(slab, 0.5)

	var focus := _box(Color.TRANSPARENT, radius + 3, P.ACCENT, 2, Vector4.ZERO)
	focus.draw_center = false
	focus.expand_margin_left = 4
	focus.expand_margin_top = 4
	focus.expand_margin_right = 4
	focus.expand_margin_bottom = 4 + depth
	focus.skew = skew

	theme.set_stylebox("normal", type, normal)
	theme.set_stylebox("hover", type, hover)
	theme.set_stylebox("pressed", type, pressed)
	theme.set_stylebox("hover_pressed", type, pressed)
	theme.set_stylebox("disabled", type, disabled)
	theme.set_stylebox("focus", type, focus)


func _font_colors(theme: Theme, type: String, normal: Color, hover: Color, pressed: Color,
		disabled: Color) -> void:
	theme.set_color("font_color", type, normal)
	theme.set_color("font_focus_color", type, normal)
	theme.set_color("font_hover_color", type, hover)
	theme.set_color("font_pressed_color", type, pressed)
	theme.set_color("font_hover_pressed_color", type, pressed)
	theme.set_color("font_disabled_color", type, disabled)


func _variation(theme: Theme, type: String, base: String) -> void:
	theme.set_type_variation(type, base)


## Título con contorno oscuro grueso y sombra, como los rótulos de un juego de cartas
func _title_label(theme: Theme, type: String, font: Font, size: int, color: Color,
		outline := 8, shadow_y := 4) -> void:
	_variation(theme, type, "Label")
	theme.set_font("font", type, font)
	theme.set_font_size("font_size", type, size)
	theme.set_color("font_color", type, color)
	theme.set_color("font_outline_color", type, P.OUTLINE)
	theme.set_constant("outline_size", type, outline)
	theme.set_color("font_shadow_color", type, Color(0, 0, 0, 0.55))
	theme.set_constant("shadow_offset_x", type, 0)
	theme.set_constant("shadow_offset_y", type, shadow_y)
	theme.set_constant("shadow_outline_size", type, outline)


# ─────────────────────────────────────────────────────────────────────────────
# Textos
# ─────────────────────────────────────────────────────────────────────────────

func _labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", P.TEXT)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.45))
	theme.set_constant("shadow_offset_x", "Label", 0)
	theme.set_constant("shadow_offset_y", "Label", 1)

	_title_label(theme, "HeroTitle", _display, 64, P.TEXT, 12, 6)
	_title_label(theme, "TitleLabel", _display, 44, P.TEXT, 10, 5)
	_title_label(theme, "SectionTitle", _heading, 24, P.GOLD_LIGHT, 6, 3)
	_title_label(theme, "StatValue", _display, 42, P.GOLD_LIGHT, 8, 4)

	# Rótulo "eyebrow" sobre los títulos (ej.: MAZO ACTIVO)
	_variation(theme, "Eyebrow", "Label")
	theme.set_font("font", "Eyebrow", _heading)
	theme.set_font_size("font_size", "Eyebrow", 18)
	theme.set_color("font_color", "Eyebrow", P.ACCENT)

	_variation(theme, "Subtitle", "Label")
	theme.set_color("font_color", "Subtitle", P.TEXT_MUTED)
	theme.set_font_size("font_size", "Subtitle", 15)

	_variation(theme, "Caption", "Label")
	theme.set_color("font_color", "Caption", P.TEXT_MUTED)
	theme.set_font_size("font_size", "Caption", 13)

	_variation(theme, "PlayLabel", "Label")
	theme.set_font("font", "PlayLabel", _display)
	theme.set_font_size("font_size", "PlayLabel", 44)
	theme.set_color("font_color", "PlayLabel", P.ON_GOLD)
	theme.set_color("font_shadow_color", "PlayLabel", P.alpha(P.GOLD_LIGHT, 0.7))
	theme.set_constant("shadow_offset_x", "PlayLabel", 0)
	theme.set_constant("shadow_offset_y", "PlayLabel", 2)

	_variation(theme, "PlayHint", "Label")
	theme.set_font("font", "PlayHint", _ui)
	theme.set_font_size("font_size", "PlayHint", 17)
	theme.set_color("font_color", "PlayHint", P.alpha(P.ON_GOLD, 0.75))

	theme.set_color("default_color", "RichTextLabel", P.TEXT)
	theme.set_font("bold_font", "RichTextLabel", _body_semi)
	theme.set_font("normal_font", "RichTextLabel", _body)


# ─────────────────────────────────────────────────────────────────────────────
# Botones
# ─────────────────────────────────────────────────────────────────────────────

func _buttons(theme: Theme) -> void:
	# Botón por defecto: violeta con relieve
	_chunky(theme, "Button", P.RAISED, P.HIGHLIGHT, P.alpha(P.EDGE, 0.85), P.SLAB, 12, Vector2(16, 9))
	theme.set_font("font", "Button", _ui)
	theme.set_font_size("font_size", "Button", 21)
	_font_colors(theme, "Button", P.TEXT, Color.WHITE, P.GOLD_LIGHT, P.alpha(P.TEXT_MUTED, 0.6))
	theme.set_color("icon_normal_color", "Button", Color(1, 1, 1, 0.95))
	theme.set_color("icon_hover_color", "Button", Color.WHITE)
	theme.set_color("icon_pressed_color", "Button", P.GOLD_LIGHT)
	theme.set_constant("h_separation", "Button", 10)
	theme.set_constant("outline_size", "Button", 0)

	# Principal: oro, inclinado y con canto profundo
	_variation(theme, "PlayButton", "Button")
	_chunky(theme, "PlayButton", P.GOLD_STRONG, P.GOLD, P.GOLD_LIGHT, P.GOLD_DEEP, 14,
		Vector2(26, 12), 7, SKEW, 3)
	theme.set_font("font", "PlayButton", _display)
	theme.set_font_size("font_size", "PlayButton", 28)
	_font_colors(theme, "PlayButton", P.ON_GOLD, Color.BLACK, Color.BLACK, P.alpha(P.ON_GOLD, 0.55))
	theme.set_color("icon_normal_color", "PlayButton", P.ON_GOLD)
	theme.set_color("icon_hover_color", "PlayButton", Color.BLACK)
	theme.set_color("icon_pressed_color", "PlayButton", Color.BLACK)

	# Acción secundaria destacada: cian (ej.: "Partida de prueba", "Editar")
	_variation(theme, "AccentButton", "Button")
	_chunky(theme, "AccentButton", Color("#123A7A"), Color("#1A4F9E"), P.ACCENT, P.SLAB, 12,
		Vector2(20, 10), 5, SKEW)
	theme.set_font("font", "AccentButton", _heading)
	theme.set_font_size("font_size", "AccentButton", 22)
	_font_colors(theme, "AccentButton", P.TEXT, Color.WHITE, P.ACCENT, P.alpha(P.TEXT_MUTED, 0.6))

	# Terciario: solo contorno
	_variation(theme, "GhostButton", "Button")
	var ghost := _box(Color(1, 1, 1, 0.04), 12, Color(1, 1, 1, 0.22), 2, Vector4(16, 8, 16, 8))
	var ghost_hover := ghost.duplicate() as StyleBoxFlat
	ghost_hover.bg_color = Color(1, 1, 1, 0.1)
	ghost_hover.border_color = P.GOLD_LIGHT
	var ghost_pressed := ghost_hover.duplicate() as StyleBoxFlat
	ghost_pressed.bg_color = Color(0, 0, 0, 0.25)
	theme.set_stylebox("normal", "GhostButton", ghost)
	theme.set_stylebox("hover", "GhostButton", ghost_hover)
	theme.set_stylebox("pressed", "GhostButton", ghost_pressed)
	theme.set_stylebox("hover_pressed", "GhostButton", ghost_pressed)
	theme.set_stylebox("disabled", "GhostButton", ghost)
	theme.set_font("font", "GhostButton", _ui_semi)
	theme.set_font_size("font_size", "GhostButton", 19)
	_font_colors(theme, "GhostButton", P.TEXT, P.GOLD_LIGHT, P.GOLD_LIGHT, P.alpha(P.TEXT_MUTED, 0.5))

	# Filtro conmutable (rarezas, pestañas simples): píldora que se rellena de oro al activarse
	_variation(theme, "FilterChip", "Button")
	var chip := _box(Color(P.ABYSS, 0.75), 20, P.alpha(P.EDGE, 0.5), 2, Vector4(18, 6, 18, 6))
	chip.skew = SKEW
	var chip_hover := chip.duplicate() as StyleBoxFlat
	chip_hover.bg_color = Color(P.RAISED, 0.9)
	chip_hover.border_color = P.EDGE
	var chip_on := _shadow(_box(P.GOLD_STRONG, 20, P.GOLD_LIGHT, 2, Vector4(18, 6, 18, 6)),
		P.GOLD_DEEP, 1, Vector2(0, 4))
	chip_on.skew = SKEW
	theme.set_stylebox("normal", "FilterChip", chip)
	theme.set_stylebox("hover", "FilterChip", chip_hover)
	theme.set_stylebox("pressed", "FilterChip", chip_on)
	theme.set_stylebox("hover_pressed", "FilterChip", chip_on)
	theme.set_stylebox("focus", "FilterChip", _empty())
	theme.set_stylebox("disabled", "FilterChip", chip)
	theme.set_font("font", "FilterChip", _heading)
	theme.set_font_size("font_size", "FilterChip", 20)
	_font_colors(theme, "FilterChip", P.TEXT_MUTED, Color.WHITE, P.ON_GOLD, P.alpha(P.TEXT_MUTED, 0.5))

	# Botón redondo de icono (chat, salir, ajustes)
	_variation(theme, "IconButton", "Button")
	_chunky(theme, "IconButton", Color(P.PANEL, 0.92), P.RAISED, P.alpha(P.EDGE, 0.6), P.SLAB, 28,
		Vector2(10, 10), 4)
	theme.set_color("icon_normal_color", "IconButton", P.TEXT)
	theme.set_color("icon_hover_color", "IconButton", P.GOLD_LIGHT)
	theme.set_color("icon_pressed_color", "IconButton", P.GOLD)

	# Peligro
	_variation(theme, "DangerButton", "Button")
	_chunky(theme, "DangerButton", Color("#7A1430"), Color("#9C1C3E"), P.DANGER, P.SLAB, 12,
		Vector2(16, 9))
	_font_colors(theme, "DangerButton", Color("#FFE1E5"), Color.WHITE, Color.WHITE, P.alpha(P.TEXT_MUTED, 0.6))

	# Tarjetas de navegación (accesos grandes)
	_variation(theme, "NavTile", "Button")
	_chunky(theme, "NavTile", Color(P.PANEL, 0.92), P.RAISED, P.alpha(P.EDGE, 0.7), P.SLAB, 18,
		Vector2(12, 16), 6)
	theme.set_font("font", "NavTile", _heading)
	theme.set_font_size("font_size", "NavTile", 26)
	_font_colors(theme, "NavTile", P.TEXT, P.GOLD_LIGHT, P.GOLD_LIGHT, P.TEXT_MUTED)

	# Casillas de verificación y desplegables: mismo lenguaje
	for type in ["CheckBox", "CheckButton"]:
		theme.set_font("font", type, _body_semi)
		_font_colors(theme, type, P.TEXT, Color.WHITE, P.GOLD_LIGHT, P.alpha(P.TEXT_MUTED, 0.5))
		theme.set_stylebox("normal", type, _empty())
		theme.set_stylebox("hover", type, _empty())
		theme.set_stylebox("pressed", type, _empty())
		theme.set_stylebox("hover_pressed", type, _empty())
		theme.set_stylebox("focus", type, _empty())

	_chunky(theme, "OptionButton", P.RAISED, P.HIGHLIGHT, P.alpha(P.EDGE, 0.85), P.SLAB, 12, Vector2(16, 9), 4)
	theme.set_font("font", "OptionButton", _ui)
	theme.set_font_size("font_size", "OptionButton", 20)
	_font_colors(theme, "OptionButton", P.TEXT, Color.WHITE, P.GOLD_LIGHT, P.alpha(P.TEXT_MUTED, 0.6))

	# LinkButton (textos clicables)
	theme.set_color("font_color", "LinkButton", P.ACCENT)
	theme.set_color("font_hover_color", "LinkButton", P.GOLD_LIGHT)


# ─────────────────────────────────────────────────────────────────────────────
# Paneles
# ─────────────────────────────────────────────────────────────────────────────

func _panels(theme: Theme) -> void:
	# Cristal oscuro con borde luminoso suave
	var panel := _shadow(
		_box(Color(P.PANEL, 0.78), 18, P.alpha(P.EDGE, 0.35), 2, Vector4(18, 16, 18, 16)),
		Color(0, 0, 0, 0.45), 18, Vector2(0, 8))
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PanelContainer", panel)

	# Cabecera de pantalla: sin caja; el título grande con contorno se sostiene solo
	_variation(theme, "HeaderPanel", "PanelContainer")
	theme.set_stylebox("panel", "HeaderPanel",
		_box(Color.TRANSPARENT, 0, Color.TRANSPARENT, 0, Vector4(6, 6, 6, 10)))

	# Panel protagonista (diálogos, banners)
	_variation(theme, "BannerPanel", "PanelContainer")
	var banner := _shadow(_box(Color(P.NIGHT, 0.96), 22, P.alpha(P.GOLD, 0.85), 3, Vector4(0, 0, 0, 0)),
		P.alpha(P.GOLD, 0.22), 26)
	theme.set_stylebox("panel", "BannerPanel", banner)

	# Píldora (usuario, monedas, contadores)
	_variation(theme, "Chip", "PanelContainer")
	theme.set_stylebox("panel", "Chip",
		_box(Color(P.ABYSS, 0.85), 40, P.alpha(P.EDGE, 0.55), 2, Vector4(14, 6, 16, 6)))

	_variation(theme, "CurrencyPill", "PanelContainer")
	theme.set_stylebox("panel", "CurrencyPill", _shadow(
		_box(Color(P.ABYSS, 0.9), 40, P.GOLD, 2, Vector4(10, 4, 18, 4)),
		P.alpha(P.GOLD, 0.25), 10))

	# Elementos de lista (mazos, sobres, avatares)
	_variation(theme, "ItemCard", "PanelContainer")
	theme.set_stylebox("panel", "ItemCard", _shadow(
		_box(Color(P.PANEL, 0.9), 16, P.alpha(P.EDGE, 0.35), 2, Vector4(12, 12, 12, 12)),
		Color(0, 0, 0, 0.4), 10, Vector2(0, 5)))

	_variation(theme, "ItemCardSelected", "PanelContainer")
	theme.set_stylebox("panel", "ItemCardSelected", _shadow(
		_box(Color(P.HIGHLIGHT, 0.55), 16, P.GOLD, 3, Vector4(12, 12, 12, 12)),
		P.alpha(P.GOLD, 0.4), 16))

	_variation(theme, "StatTile", "PanelContainer")
	var stat := _box(Color(P.ABYSS, 0.7), 14, P.alpha(P.EDGE, 0.3), 2, Vector4(12, 10, 12, 10))
	stat.border_width_bottom = 4
	stat.border_color = P.alpha(P.GOLD, 0.7)
	theme.set_stylebox("panel", "StatTile", stat)

	# Tarjeta de novedad (franja de color a la izquierda; el color lo pone el script)
	_variation(theme, "NewsCard", "PanelContainer")
	var news := _box(Color(P.ABYSS, 0.72), 14, P.ACCENT, 0, Vector4(18, 12, 14, 12))
	news.border_width_left = 5
	theme.set_stylebox("panel", "NewsCard", news)

	_variation(theme, "Toast", "PanelContainer")
	theme.set_stylebox("panel", "Toast", _shadow(
		_box(Color(P.NIGHT, 0.97), 16, P.GOLD, 3, Vector4(24, 14, 24, 14)),
		Color(0, 0, 0, 0.55), 16, Vector2(0, 6)))

	# Ventanas y diálogos (ConfirmationDialog, AcceptDialog)
	var popup := _shadow(_box(Color(P.NIGHT, 0.98), 16, P.alpha(P.GOLD, 0.8), 2, Vector4(16, 14, 16, 14)),
		Color(0, 0, 0, 0.6), 18)
	theme.set_stylebox("panel", "AcceptDialog", popup)
	theme.set_stylebox("panel", "PopupPanel", popup)
	theme.set_stylebox("panel", "TooltipPanel",
		_box(Color(P.ABYSS, 0.96), 10, P.alpha(P.EDGE, 0.7), 2, Vector4(10, 6, 10, 6)))
	theme.set_color("font_color", "TooltipLabel", P.TEXT)

	var window := _shadow(_box(Color(P.NIGHT, 0.98), 16, P.alpha(P.GOLD, 0.8), 2, Vector4.ZERO),
		Color(0, 0, 0, 0.6), 20)
	window.expand_margin_top = 34
	window.expand_margin_left = 6
	window.expand_margin_right = 6
	window.expand_margin_bottom = 6
	theme.set_stylebox("embedded_border", "Window", window)
	theme.set_stylebox("embedded_unfocused_border", "Window", window)
	theme.set_font("title_font", "Window", _heading)
	theme.set_font_size("title_font_size", "Window", 22)
	theme.set_color("title_color", "Window", P.GOLD_LIGHT)

	theme.set_stylebox("panel", "PopupMenu", popup)
	var popup_hover := _box(P.HIGHLIGHT, 8, Color.TRANSPARENT, 0, Vector4(8, 4, 8, 4))
	theme.set_stylebox("hover", "PopupMenu", popup_hover)
	theme.set_color("font_color", "PopupMenu", P.TEXT)
	theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	theme.set_font("font", "PopupMenu", _body_semi)


# ─────────────────────────────────────────────────────────────────────────────
# Campos de texto
# ─────────────────────────────────────────────────────────────────────────────

func _inputs(theme: Theme) -> void:
	var field := _box(Color(P.ABYSS, 0.92), 12, P.alpha(P.EDGE, 0.45), 2, Vector4(16, 10, 16, 10))
	var focus := _shadow(_box(Color.TRANSPARENT, 12, P.ACCENT, 2, Vector4(16, 10, 16, 10)),
		P.alpha(P.ACCENT, 0.25), 8)
	focus.draw_center = false

	for type in ["LineEdit", "TextEdit"]:
		theme.set_stylebox("normal", type, field)
		theme.set_stylebox("focus", type, focus)
		theme.set_stylebox("read_only", type, field)
		theme.set_color("font_color", type, P.TEXT)
		theme.set_color("font_placeholder_color", type, P.alpha(P.TEXT_MUTED, 0.65))
		theme.set_color("caret_color", type, P.ACCENT)
		theme.set_color("selection_color", type, P.alpha(P.ACCENT, 0.35))

	theme.set_stylebox("panel", "ItemList", field)
	theme.set_color("font_color", "ItemList", P.TEXT)
	theme.set_color("font_hovered_color", "ItemList", Color.WHITE)
	theme.set_color("font_selected_color", "ItemList", P.GOLD_LIGHT)


# ─────────────────────────────────────────────────────────────────────────────
# Pestañas
# ─────────────────────────────────────────────────────────────────────────────

func _tabs(theme: Theme) -> void:
	# Pestañas como píldoras: la activa en oro
	var selected := _shadow(_box(P.GOLD_STRONG, 12, P.GOLD_LIGHT, 2, Vector4(22, 8, 22, 8)),
		P.GOLD_DEEP, 1, Vector2(0, 4))
	selected.skew = SKEW
	var unselected := _box(Color(P.ABYSS, 0.7), 12, P.alpha(P.EDGE, 0.4), 2, Vector4(22, 8, 22, 8))
	unselected.skew = SKEW
	var hovered := unselected.duplicate() as StyleBoxFlat
	hovered.bg_color = Color(P.RAISED, 0.9)
	hovered.border_color = P.EDGE

	for type in ["TabContainer", "TabBar"]:
		theme.set_stylebox("tab_selected", type, selected)
		theme.set_stylebox("tab_unselected", type, unselected)
		theme.set_stylebox("tab_hovered", type, hovered)
		theme.set_stylebox("tab_focus", type, _empty())
		theme.set_font("font", type, _heading)
		theme.set_font_size("font_size", type, 22)
		theme.set_color("font_selected_color", type, P.ON_GOLD)
		theme.set_color("font_unselected_color", type, P.TEXT_MUTED)
		theme.set_color("font_hovered_color", type, Color.WHITE)
		theme.set_constant("h_separation", type, 10)

	theme.set_stylebox("tabbar_background", "TabContainer", _box(Color.TRANSPARENT, 0, Color.TRANSPARENT, 0, Vector4(0, 0, 0, 10)))
	theme.set_stylebox("panel", "TabContainer",
		_shadow(_box(Color(P.PANEL, 0.78), 18, P.alpha(P.EDGE, 0.35), 2, Vector4(16, 16, 16, 16)),
			Color(0, 0, 0, 0.4), 14, Vector2(0, 6)))
	theme.set_constant("side_margin", "TabContainer", 0)


# ─────────────────────────────────────────────────────────────────────────────
# Barras, separadores y scroll
# ─────────────────────────────────────────────────────────────────────────────

func _misc(theme: Theme) -> void:
	var bar_bg := _box(Color(P.ABYSS, 0.9), 8, P.alpha(P.EDGE, 0.35), 2, Vector4.ZERO)
	var bar_fill := _shadow(_box(P.GOLD_STRONG, 8, Color.TRANSPARENT, 0, Vector4.ZERO),
		P.alpha(P.GOLD, 0.35), 6)
	theme.set_stylebox("background", "ProgressBar", bar_bg)
	theme.set_stylebox("fill", "ProgressBar", bar_fill)
	theme.set_color("font_color", "ProgressBar", P.TEXT)
	theme.set_font("font", "ProgressBar", _ui)

	var grabber := _box(P.alpha(P.EDGE, 0.55), 6, Color.TRANSPARENT, 0, Vector4.ZERO)
	var grabber_hover := _box(P.GOLD, 6, Color.TRANSPARENT, 0, Vector4.ZERO)
	var track := _box(Color(0, 0, 0, 0.18), 6, Color.TRANSPARENT, 0, Vector4(4, 4, 4, 4))
	for type in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("grabber", type, grabber)
		theme.set_stylebox("grabber_highlight", type, grabber_hover)
		theme.set_stylebox("grabber_pressed", type, grabber_hover)
		theme.set_stylebox("scroll", type, track)
		theme.set_stylebox("scroll_focus", type, track)

	var sep := StyleBoxLine.new()
	sep.color = P.alpha(P.EDGE, 0.3)
	sep.thickness = 2
	theme.set_stylebox("separator", "HSeparator", sep)
	var vsep := sep.duplicate() as StyleBoxLine
	vsep.vertical = true
	theme.set_stylebox("separator", "VSeparator", vsep)

	var slider := _box(Color(P.ABYSS, 0.9), 6, P.alpha(P.EDGE, 0.4), 2, Vector4(0, 4, 0, 4))
	theme.set_stylebox("slider", "HSlider", slider)
	theme.set_stylebox("grabber_area", "HSlider", _box(P.GOLD_STRONG, 6, Color.TRANSPARENT, 0, Vector4(0, 4, 0, 4)))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _box(P.GOLD, 6, Color.TRANSPARENT, 0, Vector4(0, 4, 0, 4)))


# ─────────────────────────────────────────────────────────────────────────────
# Barra de navegación inferior (ui/BottomNavBar.gd)
# ─────────────────────────────────────────────────────────────────────────────

func _nav_bar(theme: Theme) -> void:
	_variation(theme, "NavBar", "PanelContainer")
	var bar := _shadow(_box(Color(P.ABYSS, 0.94), 0, P.alpha(P.EDGE, 0.6), 0, Vector4(24, 0, 24, 0)),
		Color(0, 0, 0, 0.6), 24, Vector2(0, -4))
	bar.border_width_top = 3
	theme.set_stylebox("panel", "NavBar", bar)

	# Pestaña normal: transparente, se ilumina al pasar el ratón
	_variation(theme, "NavTab", "Button")
	var tab := _box(Color.TRANSPARENT, 16, Color.TRANSPARENT, 0, Vector4(8, 10, 8, 8))
	var tab_hover := _box(Color(P.RAISED, 0.55), 16, Color.TRANSPARENT, 0, Vector4(8, 10, 8, 8))
	theme.set_stylebox("normal", "NavTab", tab)
	theme.set_stylebox("hover", "NavTab", tab_hover)
	theme.set_stylebox("pressed", "NavTab", tab_hover)
	theme.set_stylebox("hover_pressed", "NavTab", tab_hover)
	theme.set_stylebox("focus", "NavTab", _empty())
	theme.set_stylebox("disabled", "NavTab", tab)
	theme.set_font("font", "NavTab", _heading)
	theme.set_font_size("font_size", "NavTab", 22)
	_font_colors(theme, "NavTab", P.TEXT_MUTED, Color.WHITE, P.GOLD_LIGHT, P.alpha(P.TEXT_MUTED, 0.4))
	theme.set_color("icon_normal_color", "NavTab", P.alpha(P.TEXT_MUTED, 0.95))
	theme.set_color("icon_hover_color", "NavTab", Color.WHITE)
	theme.set_color("icon_pressed_color", "NavTab", P.GOLD_LIGHT)
	theme.set_color("icon_disabled_color", "NavTab", P.alpha(P.TEXT_MUTED, 0.4))
	theme.set_constant("h_separation", "NavTab", 4)

	# Pestaña activa: placa elevada con filo dorado
	_variation(theme, "NavTabActive", "Button")
	var active := _shadow(_box(P.HIGHLIGHT, 16, P.GOLD, 0, Vector4(8, 10, 8, 8)),
		P.alpha(P.GOLD, 0.35), 18)
	active.border_width_top = 4
	theme.set_stylebox("normal", "NavTabActive", active)
	theme.set_stylebox("hover", "NavTabActive", active)
	theme.set_stylebox("pressed", "NavTabActive", active)
	theme.set_stylebox("hover_pressed", "NavTabActive", active)
	theme.set_stylebox("focus", "NavTabActive", _empty())
	theme.set_font("font", "NavTabActive", _heading)
	theme.set_font_size("font_size", "NavTabActive", 22)
	_font_colors(theme, "NavTabActive", P.GOLD_LIGHT, P.GOLD_LIGHT, P.GOLD_LIGHT, P.GOLD_LIGHT)
	theme.set_color("icon_normal_color", "NavTabActive", P.GOLD_LIGHT)
	theme.set_color("icon_hover_color", "NavTabActive", P.GOLD_LIGHT)
	theme.set_color("icon_pressed_color", "NavTabActive", P.GOLD_LIGHT)
	theme.set_constant("h_separation", "NavTabActive", 4)

	# Insignia de notificación (mensajes sin leer)
	_variation(theme, "Badge", "PanelContainer")
	theme.set_stylebox("panel", "Badge",
		_box(P.MAGENTA, 20, Color.WHITE, 2, Vector4(7, 0, 7, 1)))
	_variation(theme, "BadgeLabel", "Label")
	theme.set_font("font", "BadgeLabel", _ui)
	theme.set_font_size("font_size", "BadgeLabel", 15)
	theme.set_color("font_color", "BadgeLabel", Color.WHITE)
