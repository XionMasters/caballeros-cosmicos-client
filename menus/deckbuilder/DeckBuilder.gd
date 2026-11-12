extends Control

# DeckBuilder.gd
# Editor de mazos.
#
#   Cabecera  → volver, nombre del mazo (editable), contador 40–60 con barra,
#               estado de validez, AUTOCOMPLETAR, ACTIVAR y GUARDAR.
#   Izquierda → la colección agrupada por coste (búsqueda, filtros por tipo y coste,
#               ocultar agotadas) o los dorsos. Cada carta tiene «−» y «+» con el contador
#               «en mazo / máximo»; también: clic en la carta añade, clic derecho abre el
#               detalle y se puede arrastrar al mazo.
#   Derecha   → el mazo: total por tipo, curva de coste (pulsar una barra filtra la colección
#               por ese coste) y la lista agrupada por coste (clic: detalle; «−»: quita una
#               copia; ★: portada).
#
# Los cambios de cartas son locales hasta GUARDAR (sync_deck_cards). El nombre, el dorso
# y la portada se guardan al momento.

const CARD_DETAIL_VIEW_SCENE = preload("res://cards/CardDetailView.tscn")
const CARD_DISPLAY_SCENE = preload("res://cards/CardDisplay.tscn")
const MIN_DECK_SIZE = 40
const MAX_DECK_SIZE = 60
const MAX_COPIES_PER_CARD = 3
const TILE_SIZE := Vector2(140, 210)
const MAX_COST_BUCKET := 7  # el último grupo de coste es «7+»
const TYPE_FILTERS := [
	["", "Todas"], ["knight", "Caballeros"], ["technique", "Técnicas"], ["item", "Objetos"],
	["stage", "Escenarios"], ["helper", "Ayudantes"], ["event", "Ocasiones"],
]

# Estado
var current_deck: Dictionary = {}
var user_cards: Array = []
var deck_cards: Dictionary = {}  # card_id -> cantidad
var is_modified: bool = false
var available_deck_backs: Array = []
var selected_deck_back: Dictionary = {}

var _card_data_cache: Dictionary = {}  # card_id -> CardData
var _deck_card_dicts: Dictionary = {}  # card_id -> carta tal como llega en el mazo (modelo Card completo)
var _type_filter := ""
var _cost_filter := -1  # -1 = todos; MAX_COST_BUCKET = «7+»
var _search_timer: Timer
var _server_validation: Dictionary = {}

# Nodos
@onready var toast: ToastNotice = %Toast
var card_detail_view: Control
var _name_edit: LineEdit
var _count_label: Label
var _count_bar: ProgressBar
var _status_label: Label
var _save_button: Button
var _active_button: Button
var _auto_button: Button
var _cards_tab: Button
var _backs_tab: Button
var _cards_view: VBoxContainer
var _backs_view: VBoxContainer
var _search: LineEdit
var _hide_used: CheckButton
var _groups: VBoxContainer  # secciones de la colección, una por coste
var _tiles: Array = []
var _grid_empty: Label
var _cost_chips: Array = []  # índice 0 = «Todos», luego costes 0..7+
var _type_chips: Array = []
var _deck_title: Label
var _curve: CostCurve
var _type_counts: Dictionary = {}  # tipo -> { "panel", "value" }
var _deck_list: VBoxContainer
var _deck_empty: Label
var _current_back_preview: TextureRect
var _current_back_name: Label
var _backs_grid: HFlowContainer
var _loading: Label


func _ready():
	_build_ui()

	card_detail_view = CARD_DETAIL_VIEW_SCENE.instantiate()
	add_child(card_detail_view)
	card_detail_view.hide()
	card_detail_view.card_add_requested.connect(func(card: CardData): _try_add(card.id))
	card_detail_view.card_remove_requested.connect(func(card: CardData): _remove_one(card.id))

	CardsManager.cards_loaded.connect(_on_cards_loaded)
	# El catálogo completo trae límites de copias, únicas y etiquetas que la colección no incluye
	CardDatabase.cards_loaded.connect(func(_count): _rebuild_card_cache())
	if not CardDatabase.is_loaded and not CardDatabase.is_loading:
		var lang := "es"
		if LocalizationManager and LocalizationManager.has_method("get_language_code"):
			lang = LocalizationManager.get_language_code()
		CardDatabase.fetch_all_cards(lang)
	DecksManager.deck_updated.connect(_on_deck_updated)
	DecksManager.deck_validated.connect(_on_deck_validated)
	DecksManager.deck_generated.connect(_on_deck_generated)
	DecksManager.error_occurred.connect(_on_error_occurred)

	_search_timer = Timer.new()
	_search_timer.one_shot = true
	_search_timer.wait_time = 0.2
	_search_timer.timeout.connect(display_collection)
	add_child(_search_timer)

	if SceneTransition.has_pending_deck():
		load_deck(SceneTransition.get_pending_deck())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not card_detail_view.visible:
		get_viewport().set_input_as_handled()
		_on_back_pressed()


# ============================================================================
# CONSTRUCCIÓN DE LA INTERFAZ
# ============================================================================

func _build_ui() -> void:
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 18)
	add_child(root)
	move_child(root, 1)  # encima del fondo, debajo del toast

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	root.add_child(layout)

	layout.add_child(_build_header())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	layout.add_child(body)
	body.add_child(_build_collection_panel())
	body.add_child(_build_deck_panel())

	_loading = Label.new()
	_loading.theme_type_variation = &"Subtitle"
	_loading.text = "Cargando…"
	_loading.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_loading.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_loading.visible = false
	add_child(_loading)


func _build_header() -> Control:
	var header := PanelContainer.new()
	header.theme_type_variation = &"HeaderPanel"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	header.add_child(row)

	var back := Button.new()
	back.theme_type_variation = &"IconButton"
	back.icon = preload("res://assets/ui-icons/lobby/back.svg")
	back.expand_icon = true
	back.custom_minimum_size = Vector2(52, 52)
	back.tooltip_text = "Volver a tus mazos"
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_on_back_pressed)
	row.add_child(back)

	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", -2)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title_box)

	var eyebrow := Label.new()
	eyebrow.theme_type_variation = &"Eyebrow"
	eyebrow.text = "EDITOR DE MAZO"
	title_box.add_child(eyebrow)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Nombre del mazo"
	_name_edit.max_length = 40
	_name_edit.flat = true
	_name_edit.add_theme_font_size_override("font_size", 28)
	_name_edit.add_theme_color_override("font_color", UIPalette.GOLD_LIGHT)
	_name_edit.custom_minimum_size = Vector2(320, 0)
	_name_edit.tooltip_text = "Pulsa para cambiar el nombre"
	_name_edit.text_submitted.connect(func(_t): _name_edit.release_focus())
	_name_edit.focus_exited.connect(_commit_rename)
	title_box.add_child(_name_edit)

	var count_box := VBoxContainer.new()
	count_box.add_theme_constant_override("separation", 2)
	count_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	count_box.custom_minimum_size = Vector2(190, 0)
	row.add_child(count_box)

	_count_label = Label.new()
	_count_label.theme_type_variation = &"StatValue"
	_count_label.add_theme_font_size_override("font_size", 28)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_box.add_child(_count_label)

	_count_bar = ProgressBar.new()
	_count_bar.min_value = 0
	_count_bar.max_value = MAX_DECK_SIZE
	_count_bar.show_percentage = false
	_count_bar.custom_minimum_size = Vector2(190, 8)
	count_box.add_child(_count_bar)

	_status_label = Label.new()
	_status_label.theme_type_variation = &"Caption"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(190, 0)
	count_box.add_child(_status_label)

	_auto_button = _header_button("AUTOCOMPLETAR", &"GhostButton", "Genera un mazo equilibrado con tus cartas (se guarda al momento)")
	_auto_button.pressed.connect(_on_auto_generate_pressed)
	row.add_child(_auto_button)

	_active_button = _header_button("ACTIVAR", &"GhostButton", "Usar este mazo para jugar")
	_active_button.pressed.connect(_on_set_active_pressed)
	row.add_child(_active_button)

	_save_button = _header_button("GUARDAR", &"PlayButton", "Guardar los cambios de cartas")
	_save_button.custom_minimum_size = Vector2(170, 56)
	_save_button.pressed.connect(_on_save_pressed)
	row.add_child(_save_button)
	return header


func _header_button(text: String, variation: StringName, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(0, 52)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


func _build_collection_panel() -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ItemCard"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	# Pestañas CARTAS / DORSO
	var tabs_row := HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 8)
	column.add_child(tabs_row)
	var tab_group := ButtonGroup.new()
	_cards_tab = _chip("CARTAS", tab_group, true)
	_cards_tab.pressed.connect(func(): _show_tab(true))
	tabs_row.add_child(_cards_tab)
	_backs_tab = _chip("DORSO", tab_group, false)
	_backs_tab.pressed.connect(func(): _show_tab(false))
	tabs_row.add_child(_backs_tab)

	var hint := Label.new()
	hint.theme_type_variation = &"Caption"
	hint.text = "+ añade una copia  ·  − la quita  ·  Clic derecho: detalle"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tabs_row.add_child(hint)

	# Vista de cartas
	_cards_view = VBoxContainer.new()
	_cards_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_view.add_theme_constant_override("separation", 10)
	column.add_child(_cards_view)

	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 6)
	_cards_view.add_child(filters)

	_search = LineEdit.new()
	_search.placeholder_text = "Buscar carta…"
	_search.clear_button_enabled = true
	_search.custom_minimum_size = Vector2(190, 40)
	_search.text_changed.connect(func(_t): _search_timer.start())
	filters.add_child(_search)

	var type_group := ButtonGroup.new()
	for option in TYPE_FILTERS:
		var chip := _chip(option[1], type_group, option[0] == "")
		var type_key: String = option[0]
		chip.set_meta("type_key", type_key)
		chip.pressed.connect(func():
			_type_filter = type_key
			display_collection()
		)
		filters.add_child(chip)
		_type_chips.append(chip)

	# Segunda fila: filtro por coste y ocultar agotadas
	var cost_row := HBoxContainer.new()
	cost_row.add_theme_constant_override("separation", 6)
	_cards_view.add_child(cost_row)

	var cost_label := Label.new()
	cost_label.theme_type_variation = &"Eyebrow"
	cost_label.text = "COSTE"
	cost_label.custom_minimum_size = Vector2(60, 0)
	cost_row.add_child(cost_label)

	var cost_group := ButtonGroup.new()
	for i in range(-1, MAX_COST_BUCKET + 1):
		var text := "Todos" if i == -1 else (str(i) if i < MAX_COST_BUCKET else "%d+" % i)
		var chip := _chip(text, cost_group, i == -1)
		chip.custom_minimum_size = Vector2(44 if i >= 0 else 70, 36)
		var cost_value := i
		chip.pressed.connect(func(): _set_cost_filter(cost_value))
		cost_row.add_child(chip)
		_cost_chips.append(chip)

	_hide_used = CheckButton.new()
	_hide_used.text = "Ocultar agotadas"
	_hide_used.tooltip_text = "Oculta las cartas de las que ya pusiste todas tus copias"
	_hide_used.toggled.connect(func(_on): display_collection())
	_hide_used.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hide_used.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_row.add_child(_hide_used)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_cards_view.add_child(scroll)

	var grid_box := VBoxContainer.new()
	grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid_box)

	_groups = VBoxContainer.new()
	_groups.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_groups.add_theme_constant_override("separation", 14)
	grid_box.add_child(_groups)

	_grid_empty = Label.new()
	_grid_empty.theme_type_variation = &"Subtitle"
	_grid_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grid_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_grid_empty.visible = false
	grid_box.add_child(_grid_empty)

	# Vista de dorsos
	_backs_view = VBoxContainer.new()
	_backs_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_backs_view.add_theme_constant_override("separation", 12)
	_backs_view.visible = false
	column.add_child(_backs_view)

	var current_row := HBoxContainer.new()
	current_row.add_theme_constant_override("separation", 16)
	_backs_view.add_child(current_row)

	_current_back_preview = TextureRect.new()
	_current_back_preview.custom_minimum_size = Vector2(120, 180)
	_current_back_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_current_back_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	current_row.add_child(_current_back_preview)

	var current_info := VBoxContainer.new()
	current_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	current_row.add_child(current_info)
	var current_eyebrow := Label.new()
	current_eyebrow.theme_type_variation = &"Eyebrow"
	current_eyebrow.text = "DORSO ACTUAL"
	current_info.add_child(current_eyebrow)
	_current_back_name = Label.new()
	_current_back_name.theme_type_variation = &"SectionTitle"
	current_info.add_child(_current_back_name)
	var back_hint := Label.new()
	back_hint.theme_type_variation = &"Caption"
	back_hint.text = "El rival ve este dorso en tu mano y en tu mazo. Se guarda al elegirlo."
	current_info.add_child(back_hint)

	var backs_scroll := ScrollContainer.new()
	backs_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	backs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_backs_view.add_child(backs_scroll)
	_backs_grid = HFlowContainer.new()
	_backs_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_backs_grid.add_theme_constant_override("h_separation", 14)
	_backs_grid.add_theme_constant_override("v_separation", 14)
	backs_scroll.add_child(_backs_grid)
	return panel


func _build_deck_panel() -> Control:
	var panel := PanelContainer.new()
	panel.set_script(preload("res://menus/deckbuilder/DeckPanelDropZone.gd"))
	panel.theme_type_variation = &"ItemCard"
	panel.custom_minimum_size = Vector2(372, 0)
	# card_dropped lo declara DeckPanelDropZone (asignado en tiempo de ejecución)
	panel.connect("card_dropped", func(card: CardData): _try_add(card.id))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	_deck_title = Label.new()
	_deck_title.theme_type_variation = &"SectionTitle"
	column.add_child(_deck_title)

	# Total por tipo de carta (pulsar uno filtra la colección por ese tipo)
	var types_grid := GridContainer.new()
	types_grid.columns = 3
	types_grid.add_theme_constant_override("h_separation", 6)
	types_grid.add_theme_constant_override("v_separation", 6)
	column.add_child(types_grid)
	for option in TYPE_FILTERS.slice(1):
		types_grid.add_child(_type_total_tile(option[0], option[1]))

	_curve = CostCurve.new()
	_curve.custom_minimum_size = Vector2(0, 112)
	_curve.tooltip_text = "Pulsa una barra para ver solo las cartas de ese coste"
	_curve.bar_clicked.connect(func(cost: int): _set_cost_filter(-1 if cost == _cost_filter else cost))
	column.add_child(_curve)

	var separator := HSeparator.new()
	column.add_child(separator)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var list_box := VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_box)

	_deck_list = VBoxContainer.new()
	_deck_list.add_theme_constant_override("separation", 4)
	_deck_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_child(_deck_list)

	_deck_empty = Label.new()
	_deck_empty.theme_type_variation = &"Subtitle"
	_deck_empty.text = "Tu mazo está vacío.\nHaz clic en las cartas de la colección o arrástralas aquí."
	_deck_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deck_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list_box.add_child(_deck_empty)
	return panel


func _type_total_tile(type_key: String, title: String) -> Control:
	var tile := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UIPalette.alpha(UIPalette.RAISED, 0.55)
	style.set_corner_radius_all(8)
	style.border_color = UIPalette.alpha(UIPalette.EDGE, 0.35)
	style.set_border_width_all(1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 4
	tile.add_theme_stylebox_override("panel", style)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.tooltip_text = "Ver solo %s en la colección" % title.to_lower()
	tile.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_type_filter(type_key)
	)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(box)

	var value := Label.new()
	value.theme_type_variation = &"StatValue"
	value.add_theme_font_size_override("font_size", 26)
	value.text = "0"
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(value)

	var name_label := Label.new()
	name_label.theme_type_variation = &"Caption"
	name_label.text = title
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)

	_type_counts[type_key] = {"panel": tile, "value": value}
	return tile


func _select_type_filter(type_key: String) -> void:
	_type_filter = "" if _type_filter == type_key else type_key
	for chip in _type_chips:
		chip.button_pressed = chip.get_meta("type_key", "") == _type_filter
	_show_tab(true)
	_cards_tab.button_pressed = true
	display_collection()


func _chip(text: String, group: ButtonGroup, pressed: bool) -> Button:
	var chip := Button.new()
	chip.text = text
	chip.theme_type_variation = &"FilterChip"
	chip.toggle_mode = true
	chip.button_group = group
	chip.button_pressed = pressed
	chip.custom_minimum_size = Vector2(0, 38)
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return chip


func _show_tab(cards: bool) -> void:
	_cards_view.visible = cards
	_backs_view.visible = not cards


# ============================================================================
# CARGA
# ============================================================================

func load_deck(deck: Dictionary):
	current_deck = deck
	is_modified = false
	_name_edit.text = deck.get("name", "Sin nombre")
	_update_active_button()

	if deck.get("current_deck_back_id"):
		var back_info = deck.get("deck_back", {})
		if not back_info is Dictionary:
			back_info = {}
		selected_deck_back = {
			"id": deck.get("current_deck_back_id"),
			"name": back_info.get("name", "Dorso"),
			"image_url": back_info.get("image_url", ""),
		}

	_read_deck_cards(deck)

	_loading.visible = true
	CardsManager.fetch_user_cards()
	_refresh_deck_from_server()
	_load_available_deck_backs()
	_refresh_deck_view()


func _read_deck_cards(deck: Dictionary) -> void:
	deck_cards.clear()
	for card in deck.get("cards", []):
		if not card is Dictionary:
			continue
		var card_id: String = str(card.get("id", ""))
		var deck_card = card.get("DeckCard", {})
		var quantity: int = int(deck_card.get("quantity", 1)) if deck_card is Dictionary else 1
		if card_id != "":
			deck_cards[card_id] = quantity
			_deck_card_dicts[card_id] = card
			_card_data_cache[card_id] = _resolve_card(card_id)


func _refresh_deck_from_server() -> void:
	var deck_id: String = str(current_deck.get("id", ""))
	if deck_id != "":
		DecksManager.fetch_deck(deck_id)


func _on_cards_loaded(cards: Array):
	_loading.visible = false
	user_cards = cards
	_rebuild_card_cache()


func _rebuild_card_cache() -> void:
	for row in user_cards:
		if row is Dictionary:
			var card_id := str(row.get("id", ""))
			_card_data_cache[card_id] = _resolve_card(card_id)
	for card_id in _deck_card_dicts:
		_card_data_cache[card_id] = _resolve_card(card_id)
	display_collection()
	_refresh_deck_view()


func _resolve_card(card_id: String) -> CardData:
	"""Datos de una carta: catálogo > carta del mazo > fila de la colección.
	Las filas de /user-cards traen los datos anidados en `card` y sin límites de copias."""
	if CardDatabase.is_loaded and CardDatabase.has_card(card_id):
		return CardDatabase.get_card(card_id)
	if _deck_card_dicts.has(card_id):
		return _dict_to_card_data(_deck_card_dicts[card_id])
	for row in user_cards:
		if row is Dictionary and str(row.get("id", "")) == card_id:
			return _dict_to_card_data(_flatten_collection_row(row))
	return null


static func _flatten_collection_row(row: Dictionary) -> Dictionary:
	var nested = row.get("card", null)
	if not nested is Dictionary:
		return row
	var flat: Dictionary = nested.duplicate()
	flat["id"] = row.get("id", nested.get("id", ""))
	if nested.get("knight_attributes") is Dictionary:
		flat["card_knight"] = nested["knight_attributes"]
	return flat


# ============================================================================
# COLECCIÓN
# ============================================================================

func _set_cost_filter(cost: int) -> void:
	_cost_filter = cost
	var index := cost + 1
	if index >= 0 and index < _cost_chips.size():
		_cost_chips[index].button_pressed = true
	_curve.set_selected(cost)
	_show_tab(true)
	_cards_tab.button_pressed = true
	display_collection()


static func _cost_bucket(cost: int) -> int:
	return clampi(cost, 0, MAX_COST_BUCKET)


static func _cost_title(bucket: int) -> String:
	return "COSTE %d" % bucket if bucket < MAX_COST_BUCKET else "COSTE %d O MÁS" % bucket


func display_collection():
	for child in _groups.get_children():
		child.queue_free()
	_tiles.clear()

	var query := _search.text.strip_edges().to_lower()
	var entries := []
	for card_dict in user_cards:
		if not card_dict is Dictionary:
			continue
		var card := _card_data(str(card_dict.get("id", "")))
		if card == null:
			continue
		if _type_filter != "" and card.type != _type_filter:
			continue
		if _cost_filter >= 0 and _cost_bucket(card.cost) != _cost_filter:
			continue
		if query != "" and card.name.to_lower().find(query) == -1:
			continue
		if _hide_used.button_pressed and _copies_left(card) <= 0:
			continue
		entries.append(card)

	entries.sort_custom(func(a: CardData, b: CardData):
		if a.cost != b.cost:
			return a.cost < b.cost
		return a.name < b.name
	)

	_grid_empty.visible = entries.is_empty()
	if entries.is_empty():
		_grid_empty.text = "Todavía no tienes cartas: consíguelas abriendo sobres en la Tienda." \
			if user_cards.is_empty() else "Ninguna carta coincide con los filtros."
		return

	# Una sección por coste: cabecera y sus cartas
	var current_bucket := -999
	var flow: HFlowContainer = null
	for card in entries:
		var bucket := _cost_bucket(card.cost)
		if bucket != current_bucket:
			current_bucket = bucket
			var count := 0
			for other in entries:
				if _cost_bucket(other.cost) == bucket:
					count += 1
			_groups.add_child(_section_header(_cost_title(bucket), count, bucket))
			flow = HFlowContainer.new()
			flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			flow.add_theme_constant_override("h_separation", 12)
			flow.add_theme_constant_override("v_separation", 14)
			_groups.add_child(flow)

		var tile := CollectionTile.new()
		tile.setup(card, TILE_SIZE)
		tile.add_requested.connect(func(c: CardData): _try_add(c.id))
		tile.remove_requested.connect(func(c: CardData): _remove_one(c.id))
		tile.detail_requested.connect(_show_detail)
		flow.add_child(tile)
		_tiles.append(tile)
		tile.set_counts(int(deck_cards.get(card.id, 0)), _owned_quantity(card.id), _max_copies(card))


func _section_header(title: String, count: int, bucket: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var gem := Label.new()
	gem.text = str(bucket) if bucket < MAX_COST_BUCKET else "%d+" % bucket
	gem.custom_minimum_size = Vector2(36, 36)
	gem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gem.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gem.add_theme_font_size_override("font_size", 18)
	gem.add_theme_color_override("font_color", Color.WHITE)
	var gem_style := StyleBoxFlat.new()
	gem_style.bg_color = UIPalette.COSMOS.darkened(0.25)
	gem_style.set_corner_radius_all(18)
	gem_style.border_color = UIPalette.alpha(Color.WHITE, 0.7)
	gem_style.set_border_width_all(2)
	gem.add_theme_stylebox_override("normal", gem_style)
	row.add_child(gem)

	var label := Label.new()
	label.theme_type_variation = &"SectionTitle"
	label.add_theme_font_size_override("font_size", 20)
	label.text = title
	row.add_child(label)

	var amount := Label.new()
	amount.theme_type_variation = &"Caption"
	amount.text = "%d %s" % [count, "carta" if count == 1 else "cartas"]
	row.add_child(amount)

	var line := HSeparator.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(line)
	return row


func _refresh_tiles() -> void:
	for tile in _tiles:
		if is_instance_valid(tile):
			var card: CardData = tile.card
			tile.set_counts(int(deck_cards.get(card.id, 0)), _owned_quantity(card.id), _max_copies(card))


func _show_detail(card: CardData) -> void:
	var texture = CardsManager._image_cache.get(card.id, null)
	var in_deck: int = int(deck_cards.get(card.id, 0))
	card_detail_view.show_card(card, texture, _copies_left(card) > 0, in_deck > 0)


# ============================================================================
# REGLAS DE AÑADIR / QUITAR
# ============================================================================

func _try_add(card_id: String) -> void:
	var card := _card_data(card_id)
	if card == null:
		return
	var owned := _owned_quantity(card_id)
	var in_deck: int = int(deck_cards.get(card_id, 0))
	if owned == 0:
		_notify("No tienes esta carta en tu colección", true)
		return
	if in_deck >= owned:
		_notify("Ya pusiste todas tus copias de «%s»" % card.name, true)
		return
	var max_allowed := _max_copies(card)
	if in_deck >= max_allowed:
		_notify("«%s» es única: máximo 1 copia" % card.name if card.unique
			else "Máximo %d copias de «%s»" % [max_allowed, card.name], true)
		return
	if get_total_deck_size() >= MAX_DECK_SIZE:
		_notify("El mazo ya tiene el máximo de %d cartas" % MAX_DECK_SIZE, true)
		return

	deck_cards[card_id] = in_deck + 1
	_mark_modified()
	_refresh_deck_view(card_id)
	_refresh_tiles()


func _remove_one(card_id: String) -> void:
	if not deck_cards.has(card_id):
		return
	deck_cards[card_id] -= 1
	if deck_cards[card_id] <= 0:
		deck_cards.erase(card_id)
	_mark_modified()
	_refresh_deck_view()
	_refresh_tiles()


func _mark_modified() -> void:
	is_modified = true
	_server_validation = {}


func get_total_deck_size() -> int:
	var total := 0
	for quantity in deck_cards.values():
		total += int(quantity)
	return total


func _copies_left(card: CardData) -> int:
	var in_deck: int = int(deck_cards.get(card.id, 0))
	return mini(_owned_quantity(card.id), _max_copies(card)) - in_deck


func _max_copies(card: CardData) -> int:
	if card.unique:
		return 1
	return card.max_copies if card.max_copies > 0 else MAX_COPIES_PER_CARD


func _owned_quantity(card_id: String) -> int:
	for card_dict in user_cards:
		if card_dict is Dictionary and str(card_dict.get("id", "")) == card_id:
			return int(card_dict.get("quantity", 0))
	return 0


func _card_data(card_id: String) -> CardData:
	return _card_data_cache.get(card_id, null)


# ============================================================================
# PANEL DEL MAZO
# ============================================================================

func _refresh_deck_view(highlight_id: String = "") -> void:
	var total := get_total_deck_size()
	_deck_title.text = "TU MAZO  ·  %d" % total

	# Contador y barra de la cabecera
	_count_label.text = "%d / %d" % [total, MAX_DECK_SIZE]
	_count_bar.value = total
	var in_range := total >= MIN_DECK_SIZE and total <= MAX_DECK_SIZE
	_count_label.add_theme_color_override("font_color", UIPalette.HEAL if in_range else UIPalette.POWER)
	_count_bar.modulate = UIPalette.HEAL if in_range else UIPalette.POWER
	_update_status()

	# Curva de coste y reparto por tipo
	var curve := []
	curve.resize(8)
	curve.fill(0)
	var by_type := {}
	var cost_sum := 0
	for card_id in deck_cards:
		var card := _card_data(card_id)
		if card == null:
			continue
		var qty: int = int(deck_cards[card_id])
		curve[clampi(card.cost, 0, 7)] += qty
		by_type[card.type] = int(by_type.get(card.type, 0)) + qty
		cost_sum += card.cost * qty
	_curve.set_values(curve, float(cost_sum) / total if total > 0 else 0.0)
	for type_key in _type_counts:
		var n: int = int(by_type.get(type_key, 0))
		var entry: Dictionary = _type_counts[type_key]
		entry.value.text = str(n)
		entry.value.add_theme_color_override("font_color", UIPalette.GOLD_LIGHT if n > 0 else UIPalette.alpha(UIPalette.TEXT_MUTED, 0.6))
		entry.panel.modulate.a = 1.0 if n > 0 else 0.6

	# Lista: por coste y nombre
	for child in _deck_list.get_children():
		child.queue_free()
	_deck_empty.visible = deck_cards.is_empty()
	var ids := deck_cards.keys()
	ids.sort_custom(func(a, b):
		var ca := _card_data(a)
		var cb := _card_data(b)
		if ca == null or cb == null:
			return ca != null
		if ca.cost != cb.cost:
			return ca.cost < cb.cost
		return ca.name < cb.name
	)
	var cover_id: String = str(current_deck.get("deck_cover_card_id", ""))
	var current_bucket := -999
	for card_id in ids:
		var card := _card_data(card_id)
		if card == null:
			continue
		var bucket := _cost_bucket(card.cost)
		if bucket != current_bucket:
			current_bucket = bucket
			var copies := 0
			for other_id in ids:
				var other := _card_data(other_id)
				if other != null and _cost_bucket(other.cost) == bucket:
					copies += int(deck_cards[other_id])
			var header := Label.new()
			header.theme_type_variation = &"Eyebrow"
			header.text = "%s  ·  %d" % [_cost_title(bucket), copies]
			header.add_theme_color_override("font_color", UIPalette.COSMOS)
			_deck_list.add_child(header)
		var row := DeckRow.new()
		row.setup(card, int(deck_cards[card_id]), card_id == cover_id)
		row.remove_requested.connect(func(c: CardData): _remove_one(c.id))
		row.detail_requested.connect(_show_detail)
		row.cover_requested.connect(func(c: CardData): _on_set_cover_card(c.id))
		_deck_list.add_child(row)
		if card_id == highlight_id:
			row.flash()


func _update_status() -> void:
	var total := get_total_deck_size()
	var text := ""
	var color := UIPalette.TEXT_MUTED
	if total < MIN_DECK_SIZE:
		text = "Faltan %d cartas (mínimo %d)" % [MIN_DECK_SIZE - total, MIN_DECK_SIZE]
		color = UIPalette.POWER
	elif total > MAX_DECK_SIZE:
		text = "Sobran %d cartas" % (total - MAX_DECK_SIZE)
		color = UIPalette.LIFE
	elif is_modified:
		text = "Cambios sin guardar"
		color = UIPalette.GOLD_LIGHT
	elif not _server_validation.is_empty():
		var errors: Array = _server_validation.get("errors", [])
		var warnings: Array = _server_validation.get("warnings", [])
		if not _server_validation.get("valid", true) and not errors.is_empty():
			text = str(errors[0])
			color = UIPalette.LIFE
		elif not warnings.is_empty():
			text = str(warnings[0])
			color = UIPalette.POWER
		else:
			text = "Mazo listo para jugar"
			color = UIPalette.HEAL
	else:
		text = "Mazo listo para jugar"
		color = UIPalette.HEAL
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)

	var in_range := total >= MIN_DECK_SIZE and total <= MAX_DECK_SIZE
	_save_button.disabled = not is_modified or not in_range
	_save_button.text = "GUARDAR" if is_modified else "GUARDADO"


func _update_active_button() -> void:
	var is_active: bool = current_deck.get("is_active", false)
	_active_button.text = "✓ ACTIVO" if is_active else "ACTIVAR"
	_active_button.disabled = is_active


# ============================================================================
# ACCIONES DE LA CABECERA
# ============================================================================

func _on_back_pressed():
	if not is_modified:
		_leave()
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Cambios sin guardar"
	dialog.dialog_text = "Tienes cambios de cartas sin guardar.\n¿Salir y descartarlos?"
	dialog.ok_button_text = "Descartar y salir"
	dialog.cancel_button_text = "Seguir editando"
	add_child(dialog)
	dialog.confirmed.connect(_leave)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()


func _leave() -> void:
	SceneTransition.pending_deck_data.clear()
	SceneTransition.go_to_decks()


func _commit_rename() -> void:
	var new_name := _name_edit.text.strip_edges()
	var deck_id: String = str(current_deck.get("id", ""))
	if deck_id == "" or new_name == "" or new_name == str(current_deck.get("name", "")):
		_name_edit.text = str(current_deck.get("name", new_name))
		return
	current_deck["name"] = new_name
	DecksManager.update_deck(deck_id, new_name)
	_notify("Nombre guardado")


func _on_save_pressed():
	var total := get_total_deck_size()
	if total < MIN_DECK_SIZE or total > MAX_DECK_SIZE:
		return
	_loading.visible = true
	var cards_array := []
	for card_id in deck_cards:
		cards_array.append({"card_id": card_id, "quantity": deck_cards[card_id]})
	DecksManager.sync_deck_cards(str(current_deck.get("id", "")), cards_array)


func _on_set_active_pressed():
	_loading.visible = true
	DecksManager.set_active_deck(str(current_deck.get("id", "")))


func _on_auto_generate_pressed():
	var deck_id: String = str(current_deck.get("id", ""))
	if deck_id == "":
		_notify("No hay mazo cargado", true)
		return
	_loading.text = "Generando mazo equilibrado…"
	_loading.visible = true
	DecksManager.auto_generate_deck(deck_id, "balanced")


# ============================================================================
# RESPUESTAS DEL SERVIDOR
# ============================================================================

func _on_deck_updated(deck: Dictionary):
	_loading.visible = false
	if str(deck.get("id", "")) != str(current_deck.get("id", "")):
		return
	var had_changes := is_modified
	for key in deck:
		current_deck[key] = deck[key]
	_update_active_button()
	# Cartas del servidor: al cargar (sin cambios locales) o como respuesta a GUARDAR.
	# Si se está editando, no pisar los cambios con otra respuesta (renombrar, activar…).
	var takes_cards: bool = deck.has("cards") and (not had_changes or _is_save_echo(deck))
	if takes_cards:
		_read_deck_cards(deck)
		if had_changes:
			_notify("Mazo guardado")
		is_modified = false
		_refresh_deck_view()
		_refresh_tiles()
		DecksManager.validate_deck(str(current_deck.get("id", "")))
	else:
		_update_status()


func _is_save_echo(deck: Dictionary) -> bool:
	"""True si el mazo que llega coincide con lo editado (respuesta a GUARDAR)"""
	var saved := {}
	for card in deck.get("cards", []):
		if card is Dictionary:
			var dc = card.get("DeckCard", {})
			saved[str(card.get("id", ""))] = int(dc.get("quantity", 1)) if dc is Dictionary else 1
	if saved.size() != deck_cards.size():
		return false
	for card_id in deck_cards:
		if int(saved.get(card_id, -1)) != int(deck_cards[card_id]):
			return false
	return true


func _on_deck_validated(validation: Dictionary):
	if is_modified:
		return  # valida lo guardado en el servidor, no lo que se está editando
	_server_validation = validation
	_update_status()


func _on_deck_generated(deck: Dictionary, info: Dictionary):
	_loading.visible = false
	_loading.text = "Cargando…"
	for key in deck:
		current_deck[key] = deck[key]
	_read_deck_cards(deck)
	is_modified = false
	_refresh_deck_view()
	_refresh_tiles()
	var stats: Dictionary = info.get("stats", {})
	_notify("Mazo generado y guardado: %d cartas, coste medio %.1f" % [int(stats.get("total_cards", get_total_deck_size())), float(stats.get("avg_cost", 0.0))])
	DecksManager.validate_deck(str(current_deck.get("id", "")))


func _on_error_occurred(error_message: String):
	_loading.visible = false
	_notify(error_message, true)


# ============================================================================
# DORSOS
# ============================================================================

func _load_available_deck_backs() -> void:
	ApiClient.get_request_with_callback("/profile/deck-backs", "load_deck_backs",
		func(success: bool, data: Variant, error: String) -> void:
			if not success:
				_notify("No se pudieron cargar los dorsos: " + error, true)
				return
			if data is Array:
				available_deck_backs = data
			elif data is Dictionary and data.has("data"):
				available_deck_backs = data["data"] if data["data"] is Array else [data["data"]]
			else:
				available_deck_backs = []
			_display_deck_back_options()
			_update_deck_back_preview()
	)


func _display_deck_back_options() -> void:
	for child in _backs_grid.get_children():
		child.queue_free()
	if available_deck_backs.is_empty():
		var empty := Label.new()
		empty.theme_type_variation = &"Subtitle"
		empty.text = "No tienes otros dorsos todavía."
		_backs_grid.add_child(empty)
		return

	for back in available_deck_backs:
		if not back is Dictionary:
			continue
		var is_selected: bool = str(selected_deck_back.get("id", "")) == str(back.get("id", ""))
		var card := PanelContainer.new()
		card.theme_type_variation = &"ItemCardSelected" if is_selected else &"ItemCard"
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		card.add_child(box)

		var preview := TextureRect.new()
		preview.custom_minimum_size = Vector2(110, 165)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(preview)
		_load_back_image(str(back.get("image_url", "")), preview)

		var name_label := Label.new()
		name_label.text = str(back.get("name", "Dorso"))
		name_label.theme_type_variation = &"Caption"
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.custom_minimum_size = Vector2(110, 0)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(name_label)

		var select := Button.new()
		select.text = "✓ EN USO" if is_selected else "ELEGIR"
		select.theme_type_variation = &"GhostButton" if is_selected else &"AccentButton"
		select.disabled = is_selected
		select.pressed.connect(_on_deck_back_selected.bind(back))
		box.add_child(select)
		_backs_grid.add_child(card)


func _update_deck_back_preview() -> void:
	if selected_deck_back.is_empty():
		_current_back_name.text = "Dorso por defecto"
		_current_back_preview.texture = CardsManager.get_default_card_back()
		return
	_current_back_name.text = str(selected_deck_back.get("name", "Dorso"))
	_load_back_image(str(selected_deck_back.get("image_url", "")), _current_back_preview)


func _load_back_image(image_url: String, target: TextureRect) -> void:
	if image_url.is_empty():
		target.texture = CardsManager.get_default_card_back()
		return
	var on_loaded := func(image: Image, _tag = null) -> void:
		if image and is_instance_valid(target):
			target.texture = ImageTexture.create_from_image(image)
	ApiClient.get_image_with_callback(image_url, on_loaded, "deck_back_%s" % image_url.md5_text())


func _on_deck_back_selected(back: Dictionary) -> void:
	selected_deck_back = back
	_display_deck_back_options()
	_update_deck_back_preview()

	var deck_id: String = str(current_deck.get("id", ""))
	var back_id: String = str(back.get("id", ""))
	if deck_id == "" or back_id == "":
		return
	ApiClient.put_request_with_callback("/profile/deck-back", {"deck_id": deck_id, "deck_back_id": back_id}, "save_deck_back",
		func(success: bool, _data: Variant, error: String) -> void:
			if success:
				current_deck["current_deck_back_id"] = back_id
				_notify("Dorso guardado")
			else:
				_notify("No se pudo guardar el dorso: " + error, true)
	)


# ============================================================================
# PORTADA
# ============================================================================

func _on_set_cover_card(card_id: String) -> void:
	var deck_id: String = str(current_deck.get("id", ""))
	if deck_id == "":
		return
	var new_cover_id = null if str(current_deck.get("deck_cover_card_id", "")) == card_id else card_id
	ApiClient.put_request_with_callback("/decks/%s/cover-card" % deck_id, {"card_id": new_cover_id}, "set_cover_card",
		func(success: bool, _data: Variant, error: String) -> void:
			if not success:
				_notify("No se pudo guardar la portada: " + error, true)
				return
			current_deck["deck_cover_card_id"] = new_cover_id
			_refresh_deck_view()
			_notify("Portada del mazo actualizada" if new_cover_id != null else "Portada quitada")
	)


# ============================================================================
# UTILIDADES
# ============================================================================

func _notify(message: String, is_error := false) -> void:
	toast.show_message(message, is_error)


func _dict_to_card_data(card_dict: Dictionary) -> CardData:
	"""Carta de la colección o del mazo (formato del servidor) → CardData"""
	var card_data := CardData.new()
	card_data.id = str(card_dict.get("id", ""))
	card_data.code = str(card_dict.get("code", ""))
	card_data.name = str(card_dict.get("name", ""))
	# El servidor puede enviar object/occasion o nombres en español: mismo vocabulario que el catálogo
	card_data.type = CardData._normalize_type(str(card_dict.get("type", "")))
	card_data.rarity = CardData._normalize_rarity(str(card_dict.get("rarity", "")))
	card_data.card_set = str(card_dict.get("card_set", ""))
	var tags_list: Array[String] = []
	var raw_tags = card_dict.get("tags", [])
	if raw_tags is Array:
		for tag in raw_tags:
			tags_list.append(str(tag))
	card_data.tags = tags_list
	card_data.faction = str(card_dict.get("faction", ""))
	card_data.element = str(card_dict.get("element", ""))
	card_data.cost = int(card_dict.get("cost", 0))
	card_data.generate = int(card_dict.get("generate", 0))
	var knight = card_dict.get("card_knight", {})
	if not knight is Dictionary:
		knight = {}
	card_data.attack = int(knight.get("attack", card_dict.get("attack", 0)))
	card_data.defense = int(knight.get("defense", card_dict.get("defense", 0)))
	card_data.health = int(knight.get("health", card_dict.get("health", 0)))
	card_data.cosmos = int(knight.get("cosmos", card_dict.get("cosmos", 0)))
	card_data.can_defend = bool(card_dict.get("can_defend", true))
	card_data.defense_reduction = float(card_dict.get("defense_reduction", 0.5))
	var max_copies = card_dict.get("max_copies", MAX_COPIES_PER_CARD)
	card_data.max_copies = int(max_copies) if max_copies != null else MAX_COPIES_PER_CARD
	card_data.unique = bool(card_dict.get("unique", false))
	card_data.image_url = str(card_dict.get("image_url", ""))
	card_data.description = str(card_dict.get("description", ""))
	return card_data


# ============================================================================
# CARTA DE LA COLECCIÓN
# ============================================================================

class CollectionTile extends Control:
	signal add_requested(card: CardData)
	signal remove_requested(card: CardData)
	signal detail_requested(card: CardData)

	const CARD_DISPLAY = preload("res://cards/CardDisplay.tscn")
	const CONTROLS_HEIGHT := 40.0

	var card: CardData
	var _display: Control
	var _count_badge: Label
	var _caption: Label
	var _minus: Button
	var _plus: Button
	var _pressed := false
	var _card_size := Vector2.ZERO

	func setup(data: CardData, card_size: Vector2) -> void:
		card = data
		_card_size = card_size
		custom_minimum_size = card_size + Vector2(0, CONTROLS_HEIGHT + 16)  # + relieve del botón
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tooltip_text = "%s  ·  coste %d" % [data.name, data.cost]

		_display = CARD_DISPLAY.instantiate()
		_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_display)
		_display.set_display_size(card_size)
		_display.setup(data)
		_display.interaction_enabled = false
		_display.dragging_enabled = false
		_display.pivot_offset = card_size / 2.0

		_count_badge = Label.new()
		_count_badge.add_theme_font_size_override("font_size", 18)
		_count_badge.add_theme_color_override("font_color", UIPalette.ON_GOLD)
		_count_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_count_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = UIPalette.GOLD
		badge_style.set_corner_radius_all(14)
		badge_style.border_color = UIPalette.ON_GOLD
		badge_style.set_border_width_all(2)
		_count_badge.add_theme_stylebox_override("normal", badge_style)
		_count_badge.size = Vector2(30, 28)
		_count_badge.position = Vector2(card_size.x - 24, -8)
		_count_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_count_badge.visible = false
		add_child(_count_badge)

		# Controles bajo la carta: [−]  en mazo / máximo  [+]
		var controls := HBoxContainer.new()
		controls.position = Vector2(0, card_size.y + 6)
		controls.size = Vector2(card_size.x, CONTROLS_HEIGHT)
		controls.add_theme_constant_override("separation", 4)
		add_child(controls)

		_minus = Button.new()
		_minus.text = "−"
		_minus.theme_type_variation = &"GhostButton"
		_minus.tooltip_text = "Quitar una copia del mazo"
		_minus.custom_minimum_size = Vector2(38, CONTROLS_HEIGHT)
		_minus.add_theme_font_override("font", ThemeDB.fallback_font)
		_minus.add_theme_font_size_override("font_size", 26)
		_minus.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_minus.pressed.connect(func(): remove_requested.emit(card))
		controls.add_child(_minus)

		_caption = Label.new()
		_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_caption.add_theme_font_size_override("font_size", 17)
		_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		controls.add_child(_caption)

		_plus = Button.new()
		_plus.text = "+"
		_plus.theme_type_variation = &"PlayButton"
		_plus.tooltip_text = "Añadir una copia al mazo"
		_plus.custom_minimum_size = Vector2(44, CONTROLS_HEIGHT)
		# La fuente de títulos tiene un «+» diminuto: símbolos con la fuente normal
		_plus.add_theme_font_override("font", ThemeDB.fallback_font)
		_plus.add_theme_font_size_override("font_size", 28)
		_plus.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_plus.pressed.connect(func():
			_pop()
			add_requested.emit(card)
		)
		controls.add_child(_plus)

		mouse_entered.connect(func(): _hover(true))
		mouse_exited.connect(func(): _hover(false))

	func set_counts(in_deck: int, owned: int, max_copies: int) -> void:
		_count_badge.visible = in_deck > 0
		_count_badge.text = str(in_deck)
		var limit := mini(owned, max_copies)
		var left := limit - in_deck
		_display.modulate = Color.WHITE if left > 0 else Color(0.55, 0.53, 0.65)
		_caption.text = "%d / %d" % [in_deck, limit]
		_caption.add_theme_color_override("font_color",
			UIPalette.GOLD_LIGHT if in_deck > 0 else UIPalette.TEXT_MUTED)
		_minus.disabled = in_deck <= 0
		_plus.disabled = left <= 0
		if limit <= 0:
			_plus.tooltip_text = "No tienes esta carta"
		elif left <= 0:
			_plus.tooltip_text = "Ya están todas tus copias en el mazo" if owned <= max_copies \
				else "Máximo %d %s por mazo" % [max_copies, "copia" if max_copies == 1 else "copias"]
		else:
			_plus.tooltip_text = "Añadir una copia al mazo (quedan %d)" % left
		tooltip_text = "%s  ·  coste %d\nEn el mazo: %d de %d posibles" % [card.name, card.cost, in_deck, limit]

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				accept_event()
				detail_requested.emit(card)
			elif event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					_pressed = true
				elif _pressed:
					_pressed = false
					accept_event()
					_pop()
					add_requested.emit(card)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_BEGIN:
			_pressed = false

	func _get_drag_data(_at_position: Vector2) -> Variant:
		var preview := TextureRect.new()
		preview.texture = CardsManager._image_cache.get(card.id, null)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		preview.size = _card_size * 0.8
		preview.position = -preview.size / 2.0
		preview.modulate.a = 0.85
		var holder := Control.new()
		holder.add_child(preview)
		set_drag_preview(holder)
		return card

	func _hover(entered: bool) -> void:
		create_tween().tween_property(_display, "scale", Vector2(1.05, 1.05) if entered else Vector2.ONE, 0.1)

	func _pop() -> void:
		var tween := create_tween()
		tween.tween_property(_display, "scale", Vector2(0.93, 0.93), 0.05)
		tween.tween_property(_display, "scale", Vector2(1.05, 1.05), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ============================================================================
# FILA DEL MAZO
# ============================================================================

class DeckRow extends PanelContainer:
	signal remove_requested(card: CardData)
	signal detail_requested(card: CardData)
	signal cover_requested(card: CardData)

	var card: CardData
	var _style: StyleBoxFlat

	func setup(data: CardData, quantity: int, is_cover: bool) -> void:
		card = data
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tooltip_text = "Clic: ver detalle"
		var rarity_color := PackArt.rarity_color(data.rarity)

		_style = StyleBoxFlat.new()
		_style.bg_color = UIPalette.alpha(UIPalette.RAISED, 0.55)
		_style.set_corner_radius_all(8)
		_style.border_color = rarity_color
		_style.border_width_left = 4
		_style.content_margin_left = 10
		_style.content_margin_right = 6
		_style.content_margin_top = 4
		_style.content_margin_bottom = 4
		add_theme_stylebox_override("panel", _style)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(row)

		var cost := Label.new()
		cost.text = str(data.cost)
		cost.custom_minimum_size = Vector2(28, 28)
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost.add_theme_font_size_override("font_size", 16)
		cost.add_theme_color_override("font_color", Color.WHITE)
		var gem := StyleBoxFlat.new()
		gem.bg_color = UIPalette.COSMOS.darkened(0.25)
		gem.set_corner_radius_all(14)
		gem.border_color = UIPalette.alpha(Color.WHITE, 0.6)
		gem.set_border_width_all(1)
		cost.add_theme_stylebox_override("normal", gem)
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(cost)

		var name_label := Label.new()
		name_label.text = data.name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_label)

		var qty := Label.new()
		qty.text = "×%d" % quantity
		qty.add_theme_color_override("font_color", UIPalette.GOLD_LIGHT)
		qty.add_theme_font_size_override("font_size", 17)
		qty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(qty)

		var cover := Button.new()
		cover.text = "★" if is_cover else "☆"
		cover.flat = true
		cover.tooltip_text = "Portada del mazo" if is_cover else "Usar como portada del mazo"
		cover.add_theme_color_override("font_color", UIPalette.GOLD if is_cover else UIPalette.TEXT_MUTED)
		cover.add_theme_color_override("font_hover_color", UIPalette.GOLD_LIGHT)
		cover.custom_minimum_size = Vector2(28, 28)
		cover.pressed.connect(func(): cover_requested.emit(card))
		row.add_child(cover)

		var minus := Button.new()
		minus.text = "−"
		minus.theme_type_variation = &"GhostButton"
		minus.tooltip_text = "Quitar una copia"
		minus.custom_minimum_size = Vector2(34, 30)
		minus.add_theme_font_size_override("font_size", 18)
		minus.pressed.connect(func(): remove_requested.emit(card))
		row.add_child(minus)

		mouse_entered.connect(func(): _style.bg_color = UIPalette.alpha(UIPalette.HIGHLIGHT, 0.7))
		mouse_exited.connect(func(): _style.bg_color = UIPalette.alpha(UIPalette.RAISED, 0.55))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			accept_event()
			detail_requested.emit(card)

	func flash() -> void:
		modulate = Color(1.6, 1.5, 1.1)
		create_tween().tween_property(self, "modulate", Color.WHITE, 0.45)


# ============================================================================
# CURVA DE COSTE
# ============================================================================

class CostCurve extends Control:
	signal bar_clicked(cost: int)

	var _values: Array = [0, 0, 0, 0, 0, 0, 0, 0]
	var _average := 0.0
	var _selected := -1

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func set_values(values: Array, average: float) -> void:
		_values = values
		_average = average
		queue_redraw()

	func set_selected(cost: int) -> void:
		_selected = cost
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var slot := size.x / _values.size()
			bar_clicked.emit(clampi(int(event.position.x / slot), 0, _values.size() - 1))
			accept_event()

	func _draw() -> void:
		var font := get_theme_default_font()
		var font_size := 13
		var count := _values.size()
		var label_h := 16.0
		var top := 16.0
		var bar_area := size.y - label_h - top
		var slot := size.x / count
		var bar_w := slot * 0.62
		var max_value := 1
		for v in _values:
			max_value = maxi(max_value, int(v))

		draw_string(font, Vector2(0, 12), "CURVA DE COSTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIPalette.TEXT_MUTED)
		draw_string(font, Vector2(0, 12), "media %.1f" % _average, HORIZONTAL_ALIGNMENT_RIGHT, size.x, 11, UIPalette.GOLD_LIGHT)

		for i in count:
			var v := int(_values[i])
			var h := (bar_area - 14.0) * float(v) / max_value
			var x := slot * i + (slot - bar_w) / 2.0
			var y := top + bar_area - h
			var selected := i == _selected
			draw_rect(Rect2(x, top + 14.0, bar_w, bar_area - 14.0),
				UIPalette.alpha(UIPalette.GOLD if selected else UIPalette.EDGE, 0.25 if selected else 0.12))
			if v > 0:
				draw_rect(Rect2(x, y, bar_w, h), UIPalette.GOLD if selected else UIPalette.COSMOS)
				draw_rect(Rect2(x, y, bar_w, 3), UIPalette.alpha(Color.WHITE, 0.6))
				draw_string(font, Vector2(x, y - 3), str(v), HORIZONTAL_ALIGNMENT_CENTER, bar_w, font_size, UIPalette.TEXT)
			var label := str(i) if i < count - 1 else "%d+" % i
			draw_string(font, Vector2(slot * i, size.y - 2), label, HORIZONTAL_ALIGNMENT_CENTER, slot, font_size, UIPalette.TEXT_MUTED)
