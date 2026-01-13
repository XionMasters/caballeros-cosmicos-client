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

var deck_data: Dictionary = {}

func _ready():
	edit_button.pressed.connect(_on_edit_pressed)
	delete_button.pressed.connect(_on_delete_pressed)

func setup_deck(deck: Dictionary):
	"""Configura el item con los datos del mazo"""
	deck_data = deck
	
	# Nombre del mazo
	var deck_name = deck.get("name", "Sin nombre")
	deck_name_label.text = deck_name
	
	# Información del mazo (cantidad de cartas)
	var cards = deck.get("cards", [])
	var total_cards = 0
	for card in cards:
		var quantity = card.get("DeckCard", {}).get("quantity", 1)
		total_cards += quantity
	
	deck_info_label.text = "%d cartas" % total_cards
	
	# Descripción si existe
	var description = deck.get("description", "")
	if description != "":
		deck_info_label.text += " - " + description
	
	# Indicador de mazo activo
	var is_active = deck.get("is_active", false)
	if active_indicator:
		active_indicator.visible = is_active

func _on_edit_pressed():
	"""Emite señal para editar el mazo"""
	edit_pressed.emit()

func _on_delete_pressed():
	"""Emite señal para eliminar el mazo"""
	delete_pressed.emit()
