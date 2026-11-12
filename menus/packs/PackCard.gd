# PackCard.gd
# Tarjeta de un sobre en la tienda: el sobre grande sobre un halo del color de su
# categoría, nombre, chips (cartas y cuántos sobres faltan para la épica asegurada) y
# botón de compra con el precio. Los sobres "Próximamente" (coming_soon) quedan bloqueados.
extends PanelContainer

signal pack_selected(pack_data: Dictionary)
signal probabilities_requested(pack_data: Dictionary)

# Imagen genérica que el servidor asigna a los sobres sin arte propio
const SERVER_DEFAULT_IMAGE := "/assets/examples/seiya.png"

## Color del halo según la categoría visual del sobre (PackArt.tier_for)
const TIER_GLOW := {
	"basic": Color("#7A66FF"),
	"bronze": Color("#E08A45"),
	"silver": Color("#BFD4F2"),
	"gold": Color("#FFC83D"),
	"mega": Color("#FF4FD8"),
}

@onready var pack_name: Label = $VBoxContainer/PackName
@onready var pack_image: TextureRect = $VBoxContainer/Stage/PackImage
@onready var halo: TextureRect = %Halo
@onready var pack_description: Label = $VBoxContainer/PackDescription
@onready var card_count: Label = $VBoxContainer/Chips/CardCountChip/CardCount
@onready var guaranteed_chip: PanelContainer = $VBoxContainer/Chips/GuaranteedChip
@onready var guaranteed_rarity: Label = $VBoxContainer/Chips/GuaranteedChip/GuaranteedRarity
@onready var probabilities_button: Button = $VBoxContainer/ProbabilitiesButton
@onready var buy_button: Button = $VBoxContainer/BuyButton

var pack_data: Dictionary = {}
var _halo_tween: Tween


func _ready():
	buy_button.pressed.connect(_on_buy_pressed)
	probabilities_button.pressed.connect(_on_probabilities_pressed)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))


func setup(data: Dictionary):
	if not is_node_ready():
		await ready

	pack_data = data
	pack_name.text = str(data.get("name", "Sobre")).to_upper()
	pack_description.text = data.get("description", "")
	buy_button.text = PackArt.format_coins(int(data.get("price", 0)))
	card_count.text = "%d CARTAS" % int(data.get("cards_per_pack", data.get("card_count", 0)))

	# Garantía: cada 10 sobres seguidos sin épica o superior, el siguiente trae una
	var progress: Dictionary = data.get("progress", {}) if data.get("progress") is Dictionary else {}
	guaranteed_chip.visible = not is_coming_soon() and not progress.is_empty()
	if guaranteed_chip.visible:
		var remaining := int(progress.get("packs_until_guarantee", 0))
		guaranteed_rarity.text = "ÉPICA ASEGURADA" if remaining <= 1 else "ÉPICA EN %d SOBRES" % remaining
		guaranteed_rarity.add_theme_color_override("font_color", PackArt.rarity_color("epic"))

	if is_coming_soon():
		buy_button.text = "PRÓXIMAMENTE"
		buy_button.disabled = true
		buy_button.tooltip_text = "Este sobre estará disponible próximamente"
		pack_image.modulate = Color(0.55, 0.55, 0.6, 1.0)

	var glow: Color = TIER_GLOW.get(PackArt.tier_for(data), TIER_GLOW.basic)
	halo.modulate = Color(glow, 0.8)
	_start_halo()

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

	if is_coming_soon():
		return  # bloqueado hasta que salga, haya o no monedas
	# El precio sigue a la vista; si no alcanza, el botón queda apagado
	buy_button.disabled = not can_afford
	buy_button.tooltip_text = "" if can_afford else "Monedas insuficientes"


func is_coming_soon() -> bool:
	return pack_data.get("coming_soon", false) == true


## El halo late despacio, como un sobre que espera ser abierto
func _start_halo() -> void:
	if _halo_tween:
		_halo_tween.kill()
	halo.pivot_offset = halo.size / 2.0
	_halo_tween = create_tween().set_loops()
	_halo_tween.tween_property(halo, "scale", Vector2(1.08, 1.08), 1.8).set_trans(Tween.TRANS_SINE)
	_halo_tween.tween_property(halo, "scale", Vector2.ONE, 1.8).set_trans(Tween.TRANS_SINE)


func _on_hover(inside: bool) -> void:
	# El sobre se eleva y gira un poco al pasar el ratón
	pack_image.pivot_offset = pack_image.size / 2.0
	var tween := create_tween().set_parallel()
	tween.tween_property(pack_image, "scale", Vector2(1.08, 1.08) if inside else Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(pack_image, "rotation", deg_to_rad(-3.0) if inside else 0.0, 0.18)


func _on_buy_pressed():
	pack_selected.emit(pack_data)


func _on_probabilities_pressed():
	probabilities_requested.emit(pack_data)
