# DecksList.gd
# Vista principal para gestionar los mazos del usuario: elegir el mazo activo,
# ver si cada mazo está listo para jugar, crear, editar y eliminar.
extends Control

@onready var back_button: Button = %BackButton
@onready var decks_container: VBoxContainer = %DecksContainer
@onready var create_deck_button: Button = %CreateDeckButton
@onready var loading_label: Label = %LoadingLabel
@onready var subtitle_label: Label = %Subtitle
@onready var create_overlay: ColorRect = %CreateOverlay
@onready var deck_name_input: LineEdit = %DeckNameInput
@onready var deck_desc_input: LineEdit = %DeckDescInput
@onready var create_error: Label = %CreateError
@onready var confirm_create_button: Button = %ConfirmButton
@onready var cancel_create_button: Button = %CancelButton
@onready var delete_confirmation: ConfirmationDialog = %DeleteConfirmationDialog
@onready var toast: ToastNotice = %Toast

var current_deck_to_delete: String = ""
# Tras crear un mazo se abre directamente en el editor
var _open_created_deck := false

const DECK_ITEM_TEMPLATE = preload("res://menus/decks/DeckItem.tscn")


func _ready():
	back_button.pressed.connect(_on_back_pressed)

	DecksManager.decks_loaded.connect(_on_decks_loaded)
	DecksManager.deck_created.connect(_on_deck_created)
	DecksManager.deck_updated.connect(_on_deck_updated)
	DecksManager.deck_deleted.connect(_on_deck_deleted)
	DecksManager.error_occurred.connect(_on_error_occurred)

	create_deck_button.pressed.connect(_on_create_deck_button_pressed)
	confirm_create_button.pressed.connect(_on_confirm_create_pressed)
	cancel_create_button.pressed.connect(func(): create_overlay.visible = false)
	deck_name_input.text_submitted.connect(func(_t): _on_confirm_create_pressed())
	deck_desc_input.text_submitted.connect(func(_t): _on_confirm_create_pressed())
	delete_confirmation.confirmed.connect(_on_confirm_delete_pressed)

	load_decks()


func _unhandled_input(event: InputEvent) -> void:
	if create_overlay.visible and event.is_action_pressed("ui_cancel"):
		create_overlay.visible = false
		get_viewport().set_input_as_handled()


func _on_back_pressed():
	SceneTransition.go_to_mainlobby()


# ============================================================================
# LISTA
# ============================================================================

func load_decks():
	loading_label.visible = true
	loading_label.text = "Cargando mazos…"
	DecksManager.fetch_user_decks(true)


func _on_decks_loaded(decks: Array):
	loading_label.visible = false
	for child in decks_container.get_children():
		child.queue_free()

	if decks.is_empty():
		var empty := Label.new()
		empty.text = "Todavía no tienes mazos. Pulsa «+ Nuevo mazo» para crear el primero."
		empty.theme_type_variation = &"Subtitle"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		decks_container.add_child(empty)
		subtitle_label.text = "Necesitas un mazo activo de 40 a 60 cartas para jugar"
		return

	# El mazo activo primero
	var sorted := decks.duplicate()
	sorted.sort_custom(func(a, b): return a.get("is_active", false) and not b.get("is_active", false))

	var active_name := ""
	for deck in sorted:
		var deck_item = DECK_ITEM_TEMPLATE.instantiate()
		decks_container.add_child(deck_item)
		deck_item.setup_deck(deck)
		deck_item.edit_pressed.connect(_on_edit_deck.bind(deck))
		deck_item.delete_pressed.connect(_on_delete_deck.bind(deck))
		deck_item.activate_pressed.connect(_on_activate_deck.bind(deck))
		if deck.get("is_active", false):
			active_name = str(deck.get("name", ""))

	subtitle_label.text = "Mazo activo: «%s»" % active_name if active_name != "" \
		else "No tienes mazo activo: elige uno para poder jugar"


# ============================================================================
# ACCIONES
# ============================================================================

func _on_activate_deck(deck: Dictionary):
	var total: int = preload("res://menus/decks/DeckItem.gd").count_cards(deck)
	if total < 40 or total > 60:
		toast.show_message("«%s» tiene %d cartas: necesita entre 40 y 60 para jugar. Se activa igualmente." % [deck.get("name", ""), total], true)
	loading_label.visible = true
	loading_label.text = "Activando mazo…"
	DecksManager.set_active_deck(str(deck.get("id", "")))


func _on_deck_updated(deck: Dictionary):
	if deck.get("is_active", false):
		toast.show_message("«%s» es ahora tu mazo activo" % deck.get("name", ""))
	load_decks()


func _on_create_deck_button_pressed():
	deck_name_input.text = ""
	deck_desc_input.text = ""
	create_error.visible = false
	create_overlay.visible = true
	deck_name_input.grab_focus()


func _on_confirm_create_pressed():
	var deck_name := deck_name_input.text.strip_edges()
	if deck_name.is_empty():
		create_error.visible = true
		deck_name_input.grab_focus()
		return

	create_overlay.visible = false
	loading_label.visible = true
	loading_label.text = "Creando mazo…"
	_open_created_deck = true
	DecksManager.create_deck(deck_name, deck_desc_input.text.strip_edges())


func _on_deck_created(deck: Dictionary):
	loading_label.visible = false
	if _open_created_deck and deck.has("id"):
		_open_created_deck = false
		# Un mazo nuevo está vacío: lo útil es empezar a llenarlo
		SceneTransition.go_to_deck_builder(deck)
		return
	load_decks()


func _on_edit_deck(deck: Dictionary):
	SceneTransition.go_to_deck_builder(deck)


func _on_delete_deck(deck: Dictionary):
	current_deck_to_delete = str(deck.get("id", ""))
	delete_confirmation.dialog_text = "¿Eliminar el mazo «%s»? Esta acción no se puede deshacer.\nTus cartas siguen en tu colección." % deck.get("name", "")
	delete_confirmation.popup_centered()


func _on_confirm_delete_pressed():
	if current_deck_to_delete == "":
		return
	loading_label.visible = true
	loading_label.text = "Eliminando mazo…"
	DecksManager.delete_deck(current_deck_to_delete)


func _on_deck_deleted(_deck_id: String):
	current_deck_to_delete = ""
	toast.show_message("Mazo eliminado")
	load_decks()


func _on_error_occurred(message: String):
	loading_label.visible = false
	_open_created_deck = false
	toast.show_message(message, true)
