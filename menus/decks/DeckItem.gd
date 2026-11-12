# DeckItem.gd
# Tarjeta de un mazo en la cuadrícula de Mis mazos: portada grande, nombre,
# estado (listo para jugar o cuántas cartas faltan) y acciones.
extends PanelContainer

signal edit_pressed
signal delete_pressed
signal activate_pressed

# Tamaño de mazo para poder jugar (mismas reglas que el servidor)
const MIN_CARDS := 40
const MAX_CARDS := 60

@onready var deck_name_label: Label = %DeckNameLabel
@onready var deck_info_label: Label = %DeckInfoLabel
@onready var count_bar: ProgressBar = %CountBar
@onready var status_label: Label = %StatusLabel
@onready var activate_button: Button = %ActivateButton
@onready var edit_button: Button = %EditButton
@onready var delete_button: Button = %DeleteButton
@onready var active_indicator: PanelContainer = %ActiveIndicator
@onready var cover: Control = %Cover
@onready var cover_thumbnail: TextureRect = %CoverThumbnail

var deck_data: Dictionary = {}


func _ready():
	edit_button.pressed.connect(func(): edit_pressed.emit())
	delete_button.pressed.connect(func(): delete_pressed.emit())
	activate_button.pressed.connect(func(): activate_pressed.emit())
	# Pulsar la portada abre el editor
	cover.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			edit_pressed.emit()
	)
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))


func _hover(entered: bool) -> void:
	pivot_offset = size / 2.0
	create_tween().tween_property(self, "scale", Vector2(1.03, 1.03) if entered else Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func setup_deck(deck: Dictionary):
	"""Configura el item con los datos del mazo"""
	if not is_node_ready():
		await ready
	deck_data = deck

	var raw_name := str(deck.get("name", "")).strip_edges()
	deck_name_label.text = raw_name if not raw_name.is_empty() else "Sin nombre"

	var description := str(deck.get("description", "") if deck.get("description") != null else "").strip_edges()
	deck_info_label.text = description if description != "" else "Sin descripción"

	var total_cards := count_cards(deck)
	_update_status(total_cards)

	# Mazo activo: resaltado, sin botón de activar y sin poder borrarlo por error
	var is_active: bool = deck.get("is_active", false)
	active_indicator.visible = is_active
	# Mismo alto para todas las tarjetas: en el activo el botón queda deshabilitado
	activate_button.disabled = is_active
	activate_button.text = "EN USO" if is_active else "USAR ESTE MAZO"
	theme_type_variation = &"ItemCardSelected" if is_active else &"ItemCard"
	delete_button.tooltip_text = "Activa otro mazo antes de eliminar este" if is_active else ""
	delete_button.disabled = is_active

	_load_cover_image(deck)


## Carta con imagen de mayor rareza (y coste) del mazo, para usarla de portada
static func _best_card(deck: Dictionary) -> Dictionary:
	var cards = deck.get("cards", [])
	if cards is not Array:
		return {}
	var best: Dictionary = {}
	for card in cards:
		if card is not Dictionary or str(card.get("image_url", "")) == "":
			continue
		if best.is_empty():
			best = card
			continue
		var rank := UIPalette.rarity_rank(str(card.get("rarity", "common")))
		var best_rank := UIPalette.rarity_rank(str(best.get("rarity", "common")))
		if rank > best_rank or (rank == best_rank and int(card.get("cost", 0)) > int(best.get("cost", 0))):
			best = card
	return best


static func count_cards(deck: Dictionary) -> int:
	var cards = deck.get("cards", [])
	if cards is not Array:
		return 0
	var total := 0
	for card in cards:
		var link = card.get("DeckCard", {})
		total += int(link.get("quantity", 1)) if link is Dictionary else 1
	return total


func _update_status(total_cards: int) -> void:
	count_bar.max_value = MIN_CARDS
	count_bar.value = mini(total_cards, MIN_CARDS)
	var fill := StyleBoxFlat.new()
	fill.set_corner_radius_all(6)

	if total_cards < MIN_CARDS:
		status_label.text = "%d / %d cartas · faltan %d" % [total_cards, MIN_CARDS, MIN_CARDS - total_cards]
		status_label.add_theme_color_override("font_color", UIPalette.POWER.lightened(0.2))
		fill.bg_color = UIPalette.POWER
	elif total_cards > MAX_CARDS:
		status_label.text = "%d cartas · sobran %d (máx. %d)" % [total_cards, total_cards - MAX_CARDS, MAX_CARDS]
		status_label.add_theme_color_override("font_color", UIPalette.LIFE.lightened(0.2))
		fill.bg_color = UIPalette.LIFE
	else:
		status_label.text = "%d cartas · listo para jugar" % total_cards
		status_label.add_theme_color_override("font_color", UIPalette.HEAL)
		fill.bg_color = UIPalette.HEAL
	count_bar.add_theme_stylebox_override("fill", fill)


func _load_cover_image(deck: Dictionary) -> void:
	"""Portada: carta elegida como portada; si no, la carta más rara del mazo; si no, el dorso"""
	var url := ""
	var cover_card = deck.get("cover_card")
	var deck_back = deck.get("deck_back")
	if cover_card is Dictionary and str(cover_card.get("image_url", "")) != "":
		url = cover_card.image_url
	else:
		var best := _best_card(deck)
		if not best.is_empty():
			var target_rect: WeakRef = weakref(cover_thumbnail)
			CardsManager.get_cached_image(str(best.get("id", "")), str(best.image_url), func(texture):
				var rect: TextureRect = target_rect.get_ref()
				if rect and texture:
					rect.texture = texture
			)
			return
		if deck_back is Dictionary and str(deck_back.get("image_url", "")) != "":
			url = deck_back.image_url
	if url == "":
		return

	var target: WeakRef = weakref(cover_thumbnail)
	ApiClient.get_image_with_callback(url, func(image: Image, _tag = null):
		var rect: TextureRect = target.get_ref()
		if image and rect:
			rect.texture = ImageTexture.create_from_image(image)
	, "deck_cover_%s" % deck.get("id", ""))
