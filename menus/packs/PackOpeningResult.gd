# PackOpeningResult.gd
# Muestra visualmente las cartas obtenidas al abrir un sobre
extends Control

signal closed

@onready var pack_name_label: Label = $Panel/MarginContainer/VBoxContainer/PackNameLabel
@onready var cards_container: HBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/CardsContainer
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/CloseButton
@onready var background: ColorRect = $Background

const CARD_DISPLAY_SCENE = preload("res://cards/CardDisplay.tscn")

var cards_data: Array = []

func _ready():
	close_button.pressed.connect(_on_close_pressed)
	background.gui_input.connect(_on_background_clicked)
	hide()

func show_cards(pack_name: String, cards: Array):
	cards_data = cards
	pack_name_label.text = "âœ¨ " + pack_name + " Abierto âœ¨"
	
	# Limpiar contenedor
	for child in cards_container.get_children():
		child.queue_free()
	
	# Crear displays para cada carta
	for card_json in cards:
		var card_display = CARD_DISPLAY_SCENE.instantiate()
		cards_container.add_child(card_display)
		
		# Crear CardData desde JSON
		var card = CardData.from_json(card_json)
		card_display.setup(card)
		
		# Conectar seÃ±al de clic para mostrar detalle
		card_display.card_clicked.connect(_on_card_clicked)
		
		# Agregar efecto de brillo si es foil
		if card_json.get("is_foil", false):
			add_foil_effect(card_display)
		
		# Cargar imagen usando CardsManager (con cachÃ©)
		# Conectar la seÃ±al directamente al mÃ©todo del card_display
		if card.image_url != "":
			_load_card_image_for_display(card.id, card.image_url, card_display)
	
	show()
	animate_entrance()

func _load_card_image_for_display(card_id: String, image_url: String, display: Control):
	"""Carga la imagen para un display especÃ­fico, evitando capturar referencias en lambdas"""
	# Verificar si ya estÃ¡ en cachÃ©
	if CardsManager._image_cache.has(card_id):
		if is_instance_valid(display):
			display.set_card_image(CardsManager._image_cache[card_id])
		return
	
	# Crear una funciÃ³n con weak reference
	var callback = func(loaded_id: String, texture: ImageTexture):
		if loaded_id == card_id and is_instance_valid(display):
			display.set_card_image(texture)
	
	# Conectar y cargar
	CardsManager.card_image_loaded.connect(callback)
	CardsManager.fetch_card_image(card_id, image_url)
	
	# Desconectar cuando se cierre esta vista
	closed.connect(func(): 
		if CardsManager.card_image_loaded.is_connected(callback):
			CardsManager.card_image_loaded.disconnect(callback)
	, CONNECT_ONE_SHOT)

func add_foil_effect(card_display: Control):
	"""Agrega un efecto visual para cartas foil"""
	var foil_label = Label.new()
	foil_label.text = "âœ¨ FOIL"
	foil_label.add_theme_color_override("font_color", Color.GOLD)
	foil_label.add_theme_font_size_override("font_size", 16)
	foil_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foil_label.position = Vector2(0, -25)
	card_display.add_child(foil_label)
	
	# AnimaciÃ³n de brillo
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(foil_label, "modulate:a", 0.5, 0.8)
	tween.tween_property(foil_label, "modulate:a", 1.0, 0.8)

func animate_entrance():
	"""AnimaciÃ³n de entrada de las cartas"""
	modulate.a = 0
	scale = Vector2(0.8, 0.8)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Animar cartas una por una
	await tween.finished
	animate_cards_reveal()

func animate_cards_reveal():
	"""Anima la apariciÃ³n de cada carta"""
	var delay = 0.0
	for card in cards_container.get_children():
		card.modulate.a = 0
		card.scale = Vector2(0.5, 0.5)
		
		await get_tree().create_timer(delay).timeout
		
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(card, "modulate:a", 1.0, 0.3)
		tween.tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		delay = 0.15

func _on_close_pressed():
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.2)
	await tween.finished
	hide()
	closed.emit()

func _on_background_clicked(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_close_pressed()

func _on_card_clicked(card: CardData):
	"""Cuando se hace clic en una carta, mostrar su detalle usando el manager global"""
	var texture = null
	# Intentar obtener la textura del cachÃ©
	if CardsManager._image_cache.has(card.id):
		texture = CardsManager._image_cache[card.id]
	
	CardDetailManager.show_card(card, texture)
