# DeckItem.gd
# Componente individual para mostrar un mazo en la lista
extends PanelContainer

signal edit_pressed
signal delete_pressed

@onready var deck_name_label = $MarginContainer/HBoxContainer/VBoxContainer/DeckNameLabel
@onready var deck_info_label = $MarginContainer/HBoxContainer/VBoxContainer/DeckInfoLabel
@onready var edit_button = $MarginContainer/HBoxContainer/ButtonsContainer/EditButton
@onready var delete_button = $MarginContainer/HBoxContainer/ButtonsContainer/DeleteButton
@onready var active_indicator = $MarginContainer/HBoxContainer/ActiveIndicator
@onready var cover_thumbnail = $MarginContainer/HBoxContainer/CoverThumbnail

var deck_data: Dictionary = {}

func _ready():
	edit_button.pressed.connect(_on_edit_pressed)
	delete_button.pressed.connect(_on_delete_pressed)

func setup_deck(deck: Dictionary):
	"""Configura el item con los datos del mazo"""
	deck_data = deck
	
	# Nombre del mazo
	var raw_name = str(deck.get("name", "")).strip_edges()
	var deck_name = raw_name if not raw_name.is_empty() else "Sin nombre"
	deck_name_label.text = deck_name
	
	# Información del mazo (cantidad de cartas)
	var cards = deck.get("cards", [])
	if cards is not Array:
		cards = []
	var total_cards = 0
	for card in cards:
		var quantity = card.get("DeckCard", {}).get("quantity", 1)
		total_cards += quantity
	
	deck_info_label.text = "%d cartas" % total_cards
	
	# Descripción si existe
	var description = str(deck.get("description", "")).strip_edges()
	if description != "":
		deck_info_label.text += " - " + description
	
	# Indicador de mazo activo
	var is_active = deck.get("is_active", false)
	if active_indicator:
		active_indicator.visible = is_active
	
	# Portada: carta de portada si existe, sino el dorso del mazo
	_load_cover_image(deck)

func _load_cover_image(deck: Dictionary) -> void:
	"""Carga la imagen de portada: carta de portada o dorso del mazo como fallback"""
	if cover_thumbnail == null:
		return
	
	# Prioridad 1: carta elegida como portada
	var cover_card = deck.get("cover_card", null)
	if cover_card is Dictionary and cover_card.get("image_url", "") != "":
		_fetch_thumbnail(cover_card.get("image_url", ""), "cover_card_%s" % deck.get("id", ""))
		return
	
	# Prioridad 2: imagen del dorso del mazo
	var deck_back = deck.get("deck_back", null)
	if deck_back is Dictionary and deck_back.get("image_url", "") != "":
		_fetch_thumbnail(deck_back.get("image_url", ""), "deck_back_%s" % deck.get("id", ""))
		return

func _fetch_thumbnail(image_url: String, tag: String) -> void:
	var callback = func(image: Image, _tag = null):
		if image and is_instance_valid(cover_thumbnail):
			cover_thumbnail.texture = ImageTexture.create_from_image(image)

	ApiClient.get_image_with_callback(
		image_url,
		callback,
		tag
	)

func _on_edit_pressed():
	"""Emite señal para editar el mazo"""
	edit_pressed.emit()

func _on_delete_pressed():
	"""Emite señal para eliminar el mazo"""
	delete_pressed.emit()
