# CardDetailView.gd
# Vista detallada de una carta individual
extends Control

signal card_add_requested(card: CardData)
signal card_remove_requested(card: CardData)
signal close_requested

@onready var background: ColorRect = $ColorRect
@onready var card_image: TextureRect = $Panel/MarginContainer/VBoxContainer/CardImage
@onready var card_name: Label = $Panel/MarginContainer/VBoxContainer/CardName
@onready var rarity_label: Label = $Panel/MarginContainer/VBoxContainer/RarityLabel
@onready var type_label: Label = $Panel/MarginContainer/VBoxContainer/TypeLabel
@onready var stats_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/StatsContainer
@onready var description_label: Label = $Panel/MarginContainer/VBoxContainer/DescriptionLabel
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/CloseButton
@onready var add_to_deck_button: Button = $Panel/MarginContainer/VBoxContainer/AddToDeckButton
@onready var remove_from_deck_button: Button = $Panel/MarginContainer/VBoxContainer/RemoveFromDeckButton

var current_card: CardData

func _ready():
	close_button.pressed.connect(_on_close_pressed)
	add_to_deck_button.pressed.connect(_on_add_to_deck_pressed)
	remove_from_deck_button.pressed.connect(_on_remove_from_deck_pressed)
	
	# Permitir cerrar haciendo clic en el fondo
	background.gui_input.connect(_on_background_input)
	
	hide()

func show_card(card: CardData, texture: ImageTexture = null, show_add_to_deck: bool = false, show_remove_from_deck: bool = false):
	current_card = card
	
	card_name.text = card.name
	rarity_label.text = card.rarity
	rarity_label.add_theme_color_override("font_color", CardData.get_rarity_color(card.rarity))
	type_label.text = "Tipo: " + card.type.capitalize()
	description_label.text = card.description
	
	# Mostrar/ocultar botones según contexto
	add_to_deck_button.visible = show_add_to_deck
	remove_from_deck_button.visible = show_remove_from_deck
	
	# Mostrar estadísticas según el tipo de carta
	update_stats_display(card)
	
	if texture:
		card_image.texture = texture
	
	show()
	
	# Animación de entrada
	var tween = create_tween()
	modulate.a = 0
	scale = Vector2(0.8, 0.8)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func update_stats_display(card: CardData):
	"""Actualiza las estadísticas mostradas según el tipo de carta"""
	var health_label = stats_container.get_node("HealthLabel")
	var attack_label = stats_container.get_node("AttackLabel")
	var defense_label = stats_container.get_node("DefenseLabel")
	var cost_label = stats_container.get_node("CostLabel")
	var constellation_label = stats_container.get_node("ConstellationLabel")
	
	# Tipos que tienen estadísticas de combate
	var combat_types = ["knight", "guerrero", "ayudante"]
	
	if card.type in combat_types:
		# Mostrar todas las estadísticas de combate
		health_label.text = "❤️ Salud: %d" % card.health
		health_label.show()
		attack_label.text = "⚔️ Ataque: %d" % card.attack
		attack_label.show()
		defense_label.text = "🛡️ Defensa: %d" % card.defense
		defense_label.show()
		cost_label.text = "💫 Cosmos: %d" % card.cost
		cost_label.show()
		
		# Mostrar elemento si existe (solo para caballeros)
		if card.type == "knight" and card.element:
			constellation_label.text = "⭐ " + card.element
			constellation_label.show()
		else:
			constellation_label.hide()
	
	elif card.type == "tecnica" or card.type == "hechizo":
		# Técnicas solo muestran costo
		health_label.hide()
		attack_label.hide()
		defense_label.hide()
		cost_label.text = "💫 Cosmos: %d" % card.cost
		cost_label.show()
		constellation_label.hide()
	
	elif card.type == "escenario":
		# Escenarios no tienen estadísticas de combate
		health_label.hide()
		attack_label.hide()
		defense_label.hide()
		cost_label.hide()
		constellation_label.hide()
	
	elif card.type == "objeto" or card.type == "artefacto":
		# Objetos solo muestran costo si lo tienen
		health_label.hide()
		attack_label.hide()
		defense_label.hide()
		if card.cost > 0:
			cost_label.text = "💫 Cosmos: %d" % card.cost
			cost_label.show()
		else:
			cost_label.hide()
		constellation_label.hide()
	
	else:
		# Por defecto, mostrar solo costo
		health_label.hide()
		attack_label.hide()
		defense_label.hide()
		cost_label.text = "💫 Cosmos: %d" % card.cost
		cost_label.show()
		constellation_label.hide()

func _on_close_pressed():
	var tween = create_tween()
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	tween.parallel().tween_property(self, "scale", Vector2(0.8, 0.8), 0.2)
	await tween.finished
	hide()
	close_requested.emit()

func _on_add_to_deck_pressed():
	# Emitir señal para que el contenedor maneje la adición al deck
	if current_card:
		card_add_requested.emit(current_card)

func _on_remove_from_deck_pressed():
	# Emitir señal para que el contenedor maneje la remoción del deck
	if current_card:
		card_remove_requested.emit(current_card)

func _on_background_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_close_pressed()
