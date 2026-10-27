# CardsCollection.gd
# Colección del jugador: sus cartas con cantidades, o el catálogo completo con
# las que le faltan atenuadas. Búsqueda, filtros por rareza y tipo, y progreso.
extends Control

const CARD_DISPLAY_SCENE = preload("res://cards/CardDisplay.tscn")
const TYPE_OPTIONS := ["", "knight", "technique", "item", "helper", "stage", "event"]
const RARITY_ORDER := {"legendary": 0, "divine": 0, "epic": 1, "rare": 2, "common": 3}

@onready var back_button: Button = %BackButton
@onready var cards_grid: HFlowContainer = %CardsGrid
@onready var loading_label: Label = %LoadingLabel
@onready var progress_label: Label = %ProgressLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var search_input: LineEdit = %SearchInput
@onready var type_filter: OptionButton = %TypeFilter
@onready var rarities: HBoxContainer = %Rarities
@onready var show_all_toggle: CheckButton = %ShowAllToggle
@onready var toast: ToastNotice = %Toast

# card_id -> { quantity, is_foil }
var _owned: Dictionary = {}
var _owned_loaded := false
var _rarity_filter := "all"
var _search_timer: Timer


func _ready():
	back_button.pressed.connect(func(): SceneTransition.go_to_mainlobby())

	type_filter.add_item("Todos los tipos")
	for t in TYPE_OPTIONS.slice(1):
		type_filter.add_item(CardData.get_type_label(t))
	type_filter.item_selected.connect(func(_i): _refresh())

	for button in rarities.get_children():
		if button is Button:
			button.pressed.connect(func():
				_rarity_filter = button.name
				_refresh()
			)

	show_all_toggle.toggled.connect(func(_on): _refresh())

	# Buscar al dejar de escribir, no en cada tecla
	_search_timer = Timer.new()
	_search_timer.one_shot = true
	_search_timer.wait_time = 0.25
	_search_timer.timeout.connect(_refresh)
	add_child(_search_timer)
	search_input.text_changed.connect(func(_t): _search_timer.start())

	CardDatabase.cards_loaded.connect(func(_count): _refresh())
	CardDatabase.cards_failed.connect(func(message): _show_error(message))

	_ensure_catalog()
	_load_owned_cards()


func _ensure_catalog() -> void:
	if CardDatabase.is_loaded or CardDatabase.is_loading:
		return
	var lang := "es"
	if LocalizationManager and LocalizationManager.has_method("get_language_code"):
		lang = LocalizationManager.get_language_code()
	CardDatabase.fetch_all_cards(lang)


func _load_owned_cards() -> void:
	ApiClient.get_request_with_callback("/user-cards", "collection_user_cards",
		func(success: bool, data: Variant, error: String):
			if not success:
				_show_error("No se pudo cargar tu colección: %s" % error)
				return
			var rows = data.get("data", []) if data is Dictionary else data
			_owned.clear()
			if rows is Array:
				for row in rows:
					if row is Dictionary and int(row.get("quantity", 0)) > 0:
						_owned[str(row.get("id", ""))] = {
							"quantity": int(row.get("quantity", 0)),
							"is_foil": bool(row.get("is_foil", false)),
						}
			_owned_loaded = true
			_refresh()
	)


# ============================================================================
# FILTRADO Y PINTADO
# ============================================================================

func _refresh() -> void:
	if not CardDatabase.is_loaded or not _owned_loaded:
		loading_label.show()
		loading_label.text = "Cargando colección…"
		return

	var catalog: Array[CardData] = CardDatabase.get_all_cards()
	_update_progress(catalog)

	var show_all := show_all_toggle.button_pressed
	var wanted_type: String = TYPE_OPTIONS[type_filter.selected] if type_filter.selected >= 0 else ""
	var query := search_input.text.strip_edges().to_lower()

	var visible_cards: Array[CardData] = []
	for card in catalog:
		var owned := _owned.has(card.id)
		if not show_all and not owned:
			continue
		if _rarity_filter != "all" and card.rarity != _rarity_filter:
			continue
		if wanted_type != "" and card.type != wanted_type:
			continue
		if query != "" and card.name.to_lower().find(query) == -1:
			continue
		visible_cards.append(card)

	# Primero las que tienes; luego por rareza (de más a menos rara) y nombre
	visible_cards.sort_custom(func(a: CardData, b: CardData):
		var oa := _owned.has(a.id)
		var ob := _owned.has(b.id)
		if oa != ob:
			return oa
		var ra: int = RARITY_ORDER.get(a.rarity, 9)
		var rb: int = RARITY_ORDER.get(b.rarity, 9)
		if ra != rb:
			return ra < rb
		return a.name < b.name
	)

	for child in cards_grid.get_children():
		child.queue_free()

	if visible_cards.is_empty():
		loading_label.show()
		if _owned.is_empty() and not show_all:
			loading_label.text = "Todavía no tienes cartas. Consíguelas abriendo sobres en la Tienda."
		else:
			loading_label.text = "Ninguna carta coincide con los filtros."
		return

	loading_label.hide()
	for card in visible_cards:
		cards_grid.add_child(_create_tile(card))


func _create_tile(card: CardData) -> Control:
	var owned: Dictionary = _owned.get(card.id, {})
	var tile := VBoxContainer.new()
	tile.add_theme_constant_override("separation", 4)

	var display = CARD_DISPLAY_SCENE.instantiate()
	tile.add_child(display)
	display.setup(card)
	display.card_clicked.connect(_on_card_clicked)

	var badge := Label.new()
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 14)
	if owned.is_empty():
		display.modulate = Color(0.35, 0.33, 0.45)
		badge.text = "No la tienes"
		badge.add_theme_color_override("font_color", Color(0.7, 0.66, 0.8, 0.8))
	else:
		badge.text = "× %d%s" % [owned.quantity, "  ✦ Foil" if owned.is_foil else ""]
		badge.add_theme_color_override("font_color", Color(1, 0.86, 0.52))
	tile.add_child(badge)
	return tile


func _update_progress(catalog: Array[CardData]) -> void:
	var owned_in_catalog := 0
	for card in catalog:
		if _owned.has(card.id):
			owned_in_catalog += 1
	var total := maxi(catalog.size(), 1)
	progress_bar.max_value = total
	progress_bar.value = owned_in_catalog
	progress_label.text = "%d / %d cartas distintas (%d%%)" % [owned_in_catalog, catalog.size(), roundi(100.0 * owned_in_catalog / total)]


func _on_card_clicked(card: CardData):
	CardDetailManager.show_card(card, null)


func _show_error(message: String) -> void:
	loading_label.show()
	loading_label.text = message
	toast.show_message(message, true)
