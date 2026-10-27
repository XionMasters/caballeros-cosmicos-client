# PackCard.gd
# Tarjeta visual para un sobre en la tienda
extends PanelContainer

signal pack_selected(pack_data: Dictionary)
signal probabilities_requested(pack_data: Dictionary)

# Imagen genérica que el servidor asigna a los sobres sin arte propio
const SERVER_DEFAULT_IMAGE := "/assets/examples/seiya.png"

@onready var pack_name: Label = $VBoxContainer/PackName
@onready var pack_image: TextureRect = $VBoxContainer/PackImage
@onready var pack_description: Label = $VBoxContainer/PackDescription
@onready var pack_price: Label = $VBoxContainer/PriceContainer/Price
@onready var card_count: Label = $VBoxContainer/Chips/CardCountChip/CardCount
@onready var guaranteed_chip: PanelContainer = $VBoxContainer/Chips/GuaranteedChip
@onready var guaranteed_rarity: Label = $VBoxContainer/Chips/GuaranteedChip/GuaranteedRarity
@onready var probabilities_button: Button = $VBoxContainer/ProbabilitiesButton
@onready var buy_button: Button = $VBoxContainer/BuyButton

var pack_data: Dictionary = {}


func _ready():
	buy_button.pressed.connect(_on_buy_pressed)
	probabilities_button.pressed.connect(_on_probabilities_pressed)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))


func setup(data: Dictionary):
	if not is_node_ready():
		await ready

	pack_data = data
	pack_name.text = data.get("name", "Sobre")
	pack_description.text = data.get("description", "")
	pack_price.text = PackArt.format_coins(int(data.get("price", 0)))
	card_count.text = "%d cartas" % int(data.get("cards_per_pack", data.get("card_count", 0)))

	var guaranteed := str(data.get("guaranteed_rarity", "") if data.get("guaranteed_rarity") != null else "")
	guaranteed_chip.visible = not guaranteed.is_empty()
	if guaranteed_chip.visible:
		guaranteed_rarity.text = "Garantiza: %s" % PackArt.rarity_label(guaranteed)
		guaranteed_rarity.add_theme_color_override("font_color", PackArt.rarity_color(guaranteed))

	# Arte propio del servidor si lo tiene; si no, el de su categoría
	var image_url := str(data.get("image_url", ""))
	pack_image.texture = PackArt.texture_for(data)
	if image_url != "" and image_url != SERVER_DEFAULT_IMAGE:
		var target: WeakRef = weakref(pack_image)
		ApiClient.get_image_with_callback(image_url, func(image: Image, _tag = null):
			var rect: TextureRect = target.get_ref()
			if image and rect:
				rect.texture = ImageTexture.create_from_image(image)
		, "pack_card_image_%s" % image_url.hash())


func set_can_afford(can_afford: bool) -> void:
	if not is_node_ready():
		await ready

	buy_button.disabled = not can_afford
	buy_button.text = "Comprar" if can_afford else "Monedas insuficientes"


func _on_hover(inside: bool) -> void:
	# El sobre se eleva un poco al pasar el ratón
	pack_image.pivot_offset = pack_image.size / 2.0
	var tween := create_tween().set_parallel()
	tween.tween_property(pack_image, "scale", Vector2(1.06, 1.06) if inside else Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK)
	tween.tween_property(pack_image, "rotation", deg_to_rad(-2.0) if inside else 0.0, 0.15)


func _on_buy_pressed():
	pack_selected.emit(pack_data)


func _on_probabilities_pressed():
	probabilities_requested.emit(pack_data)
