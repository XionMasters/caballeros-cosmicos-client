# DeckItem.gd
# Componente individual para mostrar un mazo en la lista
extends PanelContainer

signal edit_pressed
signal delete_pressed
signal activate_pressed

# Tamaño de mazo para poder jugar (mismas reglas que el servidor)
const MIN_CARDS := 40
const MAX_CARDS := 60

@onready var deck_name_label: Label = $HBoxContainer/VBoxContainer/TitleRow/DeckNameLabel
@onready var deck_info_label: Label = $HBoxContainer/VBoxContainer/DeckInfoLabel
@onready var count_bar: ProgressBar = $HBoxContainer/VBoxContainer/StatusRow/CountBar
@onready var status_label: Label = $HBoxContainer/VBoxContainer/StatusRow/StatusLabel
@onready var activate_button: Button = $HBoxContainer/ButtonsContainer/ActivateButton
@onready var edit_button: Button = $HBoxContainer/ButtonsContainer/Row/EditButton
@onready var delete_button: Button = $HBoxContainer/ButtonsContainer/Row/DeleteButton
@onready var active_indicator: PanelContainer = $HBoxContainer/VBoxContainer/TitleRow/ActiveIndicator
@onready var cover_thumbnail: TextureRect = $HBoxContainer/CoverThumbnail

var deck_data: Dictionary = {}


func _ready():
	edit_button.pressed.connect(func(): edit_pressed.emit())
	delete_button.pressed.connect(func(): delete_pressed.emit())
	activate_button.pressed.connect(func(): activate_pressed.emit())


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
	activate_button.visible = not is_active
	theme_type_variation = &"ItemCardSelected" if is_active else &"ItemCard"
	delete_button.tooltip_text = "Activa otro mazo antes de eliminar este" if is_active else ""
	delete_button.disabled = is_active

	_load_cover_image(deck)


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
		status_label.text = "%d / %d cartas · faltan %d para jugar" % [total_cards, MIN_CARDS, MIN_CARDS - total_cards]
		status_label.add_theme_color_override("font_color", Color(1, 0.75, 0.45))
		fill.bg_color = Color(0.95, 0.6, 0.25)
	elif total_cards > MAX_CARDS:
		status_label.text = "%d cartas · sobran %d (máximo %d)" % [total_cards, total_cards - MAX_CARDS, MAX_CARDS]
		status_label.add_theme_color_override("font_color", Color(1, 0.55, 0.55))
		fill.bg_color = Color(0.95, 0.4, 0.4)
	else:
		status_label.text = "%d cartas · listo para jugar" % total_cards
		status_label.add_theme_color_override("font_color", Color(0.6, 1, 0.65))
		fill.bg_color = Color(0.45, 0.85, 0.5)
	count_bar.add_theme_stylebox_override("fill", fill)


func _load_cover_image(deck: Dictionary) -> void:
	"""Portada: carta elegida como portada; si no, el dorso del mazo"""
	var url := ""
	var cover_card = deck.get("cover_card")
	var deck_back = deck.get("deck_back")
	if cover_card is Dictionary and str(cover_card.get("image_url", "")) != "":
		url = cover_card.image_url
	elif deck_back is Dictionary and str(deck_back.get("image_url", "")) != "":
		url = deck_back.image_url
	if url == "":
		return

	var target: WeakRef = weakref(cover_thumbnail)
	ApiClient.get_image_with_callback(url, func(image: Image, _tag = null):
		var rect: TextureRect = target.get_ref()
		if image and rect:
			rect.texture = ImageTexture.create_from_image(image)
	, "deck_cover_%s" % deck.get("id", ""))
