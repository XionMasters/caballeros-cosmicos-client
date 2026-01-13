# PackOpening.gd
# Pantalla de apertura de sobres con animación
extends Control

signal cards_revealed(cards: Array)

@onready var pack_sprite: TextureRect = $CenterContainer/PackSprite
@onready var cards_container: HBoxContainer = $CardsReveal/CardsContainer
@onready var open_button: Button = $OpenButton
@onready var skip_button: Button = $SkipButton

const CARD_DISPLAY_SCENE = preload("res://scenes/components/cards/CardDisplay.tscn")

var current_pack_id: String = ""
var revealed_cards: Array = []
var is_opening: bool = false

func _ready():
	open_button.pressed.connect(_on_open_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	skip_button.hide()

	if PacksManager:
		PacksManager.pack_opened.connect(_on_pack_opened)
		PacksManager.error_occurred.connect(show_error)

func setup_pack(pack_id: String, pack_name: String):
	current_pack_id = pack_id
	# TODO: Cargar imagen del pack
	open_button.text = "Abrir " + pack_name

func _on_open_pressed():
	if is_opening:
		return
	
	is_opening = true
	open_button.hide()
	skip_button.show()
	
	# Animación de apertura del sobre
	animate_pack_opening()

func animate_pack_opening():
	# Efecto de shake
	var tween = create_tween()
	tween.set_loops(5)
	tween.tween_property(pack_sprite, "rotation_degrees", 5, 0.1)
	tween.tween_property(pack_sprite, "rotation_degrees", -5, 0.1)
	
	await tween.finished
	
	# Hacer que el sobre "explote"
	var explode_tween = create_tween()
	explode_tween.parallel().tween_property(pack_sprite, "scale", Vector2(1.5, 1.5), 0.3)
	explode_tween.parallel().tween_property(pack_sprite, "modulate:a", 0.0, 0.3)
	
	await explode_tween.finished
	
	# Solicitar apertura del pack a la API
	PacksManager.open_pack(current_pack_id)

func _on_pack_opened(user_pack_id: String, _pack_name: String, cards: Array, _new_currency: int):
	if user_pack_id != current_pack_id:
		return
	revealed_cards = cards
	reveal_cards_animation()

func reveal_cards_animation():
	# Revelar cartas una por una con animación
	for i in range(revealed_cards.size()):
		await reveal_single_card(revealed_cards[i], i)
		await get_tree().create_timer(0.5).timeout
	
	# Todas las cartas reveladas
	await get_tree().create_timer(1.0).timeout
	cards_revealed.emit(revealed_cards)

func reveal_single_card(card_data: Dictionary, index: int):
	var card_display = CARD_DISPLAY_SCENE.instantiate()
	cards_container.add_child(card_display)

	# Configurar carta
	var card = CardData.new()
	card.id = card_data.get("id", "")
	card.name = card_data.get("name", "")
	card.rarity = card_data.get("rarity", "comun")
	card.type = card_data.get("type", "")
	card.attack = card_data.get("attack", 0)
	card.defense = card_data.get("defense", 0)
	card.health = card_data.get("health", 0)

	card_display.setup(card)
	# Desactivar drag, permitir hover y doble clic
	card_display.interaction_enabled = false
	card_display.disable_hover_animation = false
	card_display.card_double_clicked.connect(_on_card_double_clicked)

	# Animación de entrada: girar como carta volteándose
	card_display.scale = Vector2(0, 1)
	card_display.position.y = -100

	var tween = create_tween()
	tween.parallel().tween_property(card_display, "scale:x", 1.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card_display, "position:y", 0, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	# Efecto especial para raras+
	if card.rarity in ["epica", "legendaria"]:
		add_sparkle_effect(card_display)

	await tween.finished

func _on_card_double_clicked(card_data: CardData):
	# Mostrar popup de detalles de la carta
	if has_node("../CardDetailPopup"):
		var popup = get_node("../CardDetailPopup")
		popup.show_card(card_data)
	else:
		print("[PackOpening] Doble clic en carta:", card_data.name)

func add_sparkle_effect(node: Node):
	# Partículas brillantes para cartas épicas y legendarias
	var particles = CPUParticles2D.new()
	particles.position = Vector2(0, 0)
	particles.amount = 30
	particles.lifetime = 1.5
	particles.explosiveness = 0.8
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 50
	
	var gradient = Gradient.new()
	gradient.add_point(0, Color.GOLD)
	gradient.add_point(1, Color(1, 1, 1, 0))
	
	particles.color_ramp = gradient
	particles.gravity = Vector2(0, 50)
	particles.initial_velocity_min = 100
	particles.initial_velocity_max = 200
	
	node.add_child(particles)
	particles.emitting = true
	
	await get_tree().create_timer(2.0).timeout
	particles.queue_free()

func _on_skip_pressed():
	# Saltar animación y mostrar todas las cartas de inmediato
	get_tree().create_tween().kill()
	
	for card_data in revealed_cards:
		if cards_container.get_child_count() < revealed_cards.size():
			var card_display = CARD_DISPLAY_SCENE.instantiate()
			cards_container.add_child(card_display)
			
			var card = CardData.new()
			card.id = card_data.get("id", "")
			card.name = card_data.get("name", "")
			card.rarity = card_data.get("rarity", "comun")
			card.type = card_data.get("type", "")
			
			card_display.setup(card)
	
	cards_revealed.emit(revealed_cards)

func show_error(text: String):
	var dialog = AcceptDialog.new()
	dialog.title = "Error"
	dialog.dialog_text = text
	add_child(dialog)
	dialog.popup_centered()
