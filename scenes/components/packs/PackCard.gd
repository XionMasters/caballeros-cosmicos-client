# PackCard.gd
# Tarjeta visual para un sobre en la tienda
extends PanelContainer

signal pack_selected(pack_data: Dictionary)

@onready var pack_name: Label = $VBoxContainer/PackName
@onready var pack_image: TextureRect = $VBoxContainer/PackImage
@onready var pack_price: Label = $VBoxContainer/PriceContainer/Price
@onready var card_count: Label = $VBoxContainer/CardCount
@onready var buy_button: Button = $VBoxContainer/BuyButton

var pack_data: Dictionary = {}

func _ready():
	buy_button.pressed.connect(_on_buy_pressed)

func setup(data: Dictionary):
	pack_data = data
	
	if data.has("name"):
		pack_name.text = data.name
	
	if data.has("price"):
		pack_price.text = str(data.price) + " monedas"
	
	if data.has("card_count"):
		card_count.text = str(data.card_count) + " cartas"
	
	# TODO: Cargar imagen del sobre si existe
	# Por ahora usamos un ColorRect como placeholder

func _on_buy_pressed():
	pack_selected.emit(pack_data)
