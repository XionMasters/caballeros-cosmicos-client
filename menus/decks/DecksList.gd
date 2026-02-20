# DecksList.gd
# Vista principal para gestionar los mazos del usuario
extends Control

@onready var back_button = $MarginContainer/VBoxContainer/HBoxContainer/BackButton
@onready var decks_container = $MarginContainer/VBoxContainer/ScrollContainer/DecksContainer
@onready var create_deck_button = $MarginContainer/VBoxContainer/HBoxContainer/CreateDeckButton
@onready var loading_label = $LoadingLabel
@onready var error_label = $ErrorLabel
@onready var create_dialog = $CreateDeckDialog
@onready var deck_name_input = $CreateDeckDialog/VBoxContainer/DeckNameInput
@onready var deck_desc_input = $CreateDeckDialog/VBoxContainer/DeckDescInput
@onready var confirm_create_button = $CreateDeckDialog/VBoxContainer/HBoxContainer/ConfirmButton
@onready var cancel_create_button = $CreateDeckDialog/VBoxContainer/HBoxContainer/CancelButton
@onready var delete_confirmation = $DeleteConfirmationDialog
@onready var confirm_delete_button = $DeleteConfirmationDialog/VBoxContainer/HBoxContainer/ConfirmButton
@onready var cancel_delete_button = $DeleteConfirmationDialog/VBoxContainer/HBoxContainer/CancelButton

var current_deck_to_delete: String = ""

# Plantilla para cada item de mazo
const DECK_ITEM_TEMPLATE = preload("res://menus/decks/DeckItem.tscn")

func _ready():
	# Conectar botón volver
	back_button.pressed.connect(_on_back_pressed)
	
	# Conectar señales del manager
	DecksManager.decks_loaded.connect(_on_decks_loaded)
	DecksManager.deck_created.connect(_on_deck_created)
	DecksManager.deck_deleted.connect(_on_deck_deleted)
	DecksManager.error_occurred.connect(_on_error_occurred)
	
	# Conectar botones
	create_deck_button.pressed.connect(_on_create_deck_button_pressed)
	confirm_create_button.pressed.connect(_on_confirm_create_pressed)
	cancel_create_button.pressed.connect(_on_cancel_create_pressed)
	confirm_delete_button.pressed.connect(_on_confirm_delete_pressed)
	cancel_delete_button.pressed.connect(_on_cancel_delete_pressed)
	
	# Cargar mazos
	load_decks()

func _on_back_pressed():
	SceneTransition.go_to_mainlobby()

func load_decks():
	"""Carga los mazos del usuario"""
	loading_label.visible = true
	error_label.visible = false
	clear_decks()
	DecksManager.fetch_user_decks()

func clear_decks():
	"""Limpia la lista de mazos"""
	for child in decks_container.get_children():
		child.queue_free()

func _on_decks_loaded(decks: Array):
	"""Callback cuando se cargan los mazos"""
	loading_label.visible = false
	
	if decks.is_empty():
		var no_decks_label = Label.new()
		no_decks_label.text = "No tienes mazos aún. ¡Crea tu primer mazo!"
		no_decks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		decks_container.add_child(no_decks_label)
		return
	
	for deck in decks:
		var deck_item = DECK_ITEM_TEMPLATE.instantiate()
		decks_container.add_child(deck_item)
		deck_item.setup_deck(deck)
		deck_item.edit_pressed.connect(_on_edit_deck.bind(deck))
		deck_item.delete_pressed.connect(_on_delete_deck.bind(deck))

func _on_create_deck_button_pressed():
	"""Muestra el diálogo de crear mazo"""
	deck_name_input.text = ""
	deck_desc_input.text = ""
	create_dialog.visible = true
	deck_name_input.grab_focus()

func _on_confirm_create_pressed():
	"""Confirma la creación del mazo"""
	var deck_name = deck_name_input.text.strip_edges()
	var deck_desc = deck_desc_input.text.strip_edges()
	
	if deck_name.is_empty():
		error_label.text = "El nombre del mazo no puede estar vacío"
		error_label.visible = true
		return
	
	create_dialog.visible = false
	loading_label.visible = true
	DecksManager.create_deck(deck_name, deck_desc)

func _on_cancel_create_pressed():
	"""Cancela la creación del mazo"""
	create_dialog.visible = false

func _on_deck_created(_deck: Dictionary):
	"""Callback cuando se crea un mazo"""
	loading_label.visible = false
	load_decks()

func _on_edit_deck(deck: Dictionary):
	"""Abre el editor de mazo"""
	SceneTransition.go_to_deck_builder(deck)

func _on_delete_deck(deck: Dictionary):
	"""Muestra confirmación de eliminación"""
	current_deck_to_delete = deck.get("id", "")
	delete_confirmation.visible = true

func _on_confirm_delete_pressed():
	"""Confirma la eliminación del mazo"""
	if current_deck_to_delete != "":
		delete_confirmation.visible = false
		loading_label.visible = true
		DecksManager.delete_deck(current_deck_to_delete)

func _on_cancel_delete_pressed():
	"""Cancela la eliminación"""
	delete_confirmation.visible = false
	current_deck_to_delete = ""

func _on_deck_deleted(_deck_id: String):
	"""Callback cuando se elimina un mazo"""
	loading_label.visible = false
	current_deck_to_delete = ""
	load_decks()

func _on_error_occurred(message: String):
	"""Callback cuando ocurre un error"""
	loading_label.visible = false
	error_label.text = message
	error_label.visible = true
