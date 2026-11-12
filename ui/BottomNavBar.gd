class_name BottomNavBar
extends PanelContainer
## Barra de navegación inferior de los menús (Tienda · Colección · Jugar · Mazos · Perfil).
## Se ancla sola al borde inferior a todo lo ancho. La pestaña de la pantalla actual
## se marca con `active_tab` y no navega.
##
## Uso en una escena: un nodo PanelContainer con este script como hijo directo de la raíz,
## y dejar `BAR_HEIGHT` + margen libre abajo en el layout de la pantalla.

signal tab_pressed(tab_id: String)

const BAR_HEIGHT := 112.0

const TABS := [
	{ "id": "shop", "label": "TIENDA", "icon": "res://assets/ui-icons/lobby/shop.svg" },
	{ "id": "collection", "label": "COLECCIÓN", "icon": "res://assets/ui-icons/lobby/collection.svg" },
	{ "id": "home", "label": "JUGAR", "icon": "res://assets/ui-icons/lobby/battle.svg" },
	{ "id": "decks", "label": "MAZOS", "icon": "res://assets/ui-icons/lobby/decks.svg" },
	{ "id": "profile", "label": "PERFIL", "icon": "res://assets/ui-icons/lobby/profile.svg" },
]

@export_enum("home", "shop", "collection", "decks", "profile") var active_tab: String = "home"

var _buttons: Dictionary = {}


func _ready() -> void:
	theme_type_variation = &"NavBar"
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -BAR_HEIGHT
	custom_minimum_size.y = BAR_HEIGHT
	mouse_filter = Control.MOUSE_FILTER_STOP

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	add_child(row)

	for tab in TABS:
		var button := _make_tab(tab)
		row.add_child(button)
		_buttons[tab.id] = button

	_play_intro()


func _make_tab(tab: Dictionary) -> Button:
	var is_active: bool = tab.id == active_tab
	var is_home: bool = tab.id == "home"

	var button := Button.new()
	button.name = "Tab_%s" % tab.id
	button.text = tab.label
	button.icon = load(tab.icon)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.add_theme_constant_override("icon_max_width", 52 if is_home else 42)
	button.theme_type_variation = &"NavTabActive" if is_active else &"NavTab"
	button.custom_minimum_size = Vector2(230 if is_home else 200, BAR_HEIGHT - 14)
	button.size_flags_vertical = Control.SIZE_SHRINK_END
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if is_home:
		button.add_theme_font_size_override("font_size", 26)

	button.pressed.connect(_on_tab_pressed.bind(tab.id))
	if not is_active:
		button.mouse_entered.connect(_hover.bind(button, true))
		button.mouse_exited.connect(_hover.bind(button, false))
	return button


func _hover(button: Button, entered: bool) -> void:
	button.pivot_offset = Vector2(button.size.x / 2.0, button.size.y)
	var target := Vector2(1.06, 1.06) if entered else Vector2.ONE
	create_tween().tween_property(button, "scale", target, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_tab_pressed(tab_id: String) -> void:
	tab_pressed.emit(tab_id)
	if tab_id == active_tab:
		return
	match tab_id:
		"home": SceneTransition.go_to_mainlobby()
		"shop": SceneTransition.go_to_shop()
		"collection": SceneTransition.go_to_mycards()
		"decks": SceneTransition.go_to_decks()
		"profile": SceneTransition.go_to_profile()


func _play_intro() -> void:
	# La barra sube desde abajo al entrar en la pantalla
	var row := get_child(0) as Control
	row.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(row, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)
