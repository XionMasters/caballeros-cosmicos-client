# PackCard.gd
# Tarjeta visual para un sobre en la tienda
extends PanelContainer

signal pack_selected(pack_data: Dictionary)
signal probabilities_requested(pack_data: Dictionary)

@onready var pack_name: Label = $VBoxContainer/PackName
@onready var pack_image: TextureRect = $VBoxContainer/PackImage
@onready var pack_description: Label = $VBoxContainer/PackDescription
@onready var pack_price: Label = $VBoxContainer/PriceContainer/Price
@onready var card_count: Label = $VBoxContainer/CardCount
@onready var guaranteed_rarity: Label = $VBoxContainer/GuaranteedRarity
@onready var probabilities_button: Button = $VBoxContainer/ProbabilitiesButton
@onready var buy_button: Button = $VBoxContainer/BuyButton

var pack_data: Dictionary = {}

func _ready():
	buy_button.pressed.connect(_on_buy_pressed)
	probabilities_button.pressed.connect(_on_probabilities_pressed)

func setup(data: Dictionary):
	if not is_node_ready():
		await ready

	pack_data = data
	
	if data.has("name"):
		pack_name.text = data.get("name", "Sobre")
	
	pack_description.text = data.get("description", "")
	
	if data.has("price"):
		pack_price.text = str(data.get("price", 0)) + " monedas"
	
	if data.has("cards_per_pack"):
		card_count.text = str(data.get("cards_per_pack", 0)) + " cartas"
	elif data.has("card_count"):
		card_count.text = str(data.get("card_count", 0)) + " cartas"
	
	var guaranteed := str(data.get("guaranteed_rarity", ""))
	if guaranteed.is_empty():
		guaranteed_rarity.hide()
	else:
		guaranteed_rarity.show()
		guaranteed_rarity.text = "✨ Garantiza: " + guaranteed.capitalize()
		guaranteed_rarity.add_theme_color_override("font_color", _get_rarity_color(guaranteed))
	
	if data.get("image_url", "") != "":
		ApiClient.get_image_with_callback(
			data.get("image_url", ""),
			func(image: Image, _tag = null):
				if image and is_instance_valid(pack_image):
					pack_image.texture = ImageTexture.create_from_image(image),
			"pack_card_image"
		)

func set_can_afford(can_afford: bool) -> void:
	if not is_node_ready():
		await ready

	if buy_button == null:
		return

	buy_button.disabled = not can_afford
	buy_button.text = "Comprar" if can_afford else "Sin monedas"

func _on_buy_pressed():
	pack_selected.emit(pack_data)

func _on_probabilities_pressed():
	probabilities_requested.emit(pack_data)

func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"common", "comun":
			return Color(0.75, 0.75, 0.75)
		"rare", "rara":
			return Color(0.29, 0.56, 0.89)
		"epic", "epica":
			return Color(0.61, 0.35, 0.71)
		"legendary", "legendaria":
			return Color(1.0, 0.84, 0.0)
		_:
			return Color.WHITE
