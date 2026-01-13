# DeckDisplay.gd
extends CardCollection
class_name DeckDisplay

# Usar configuración centralizada de tamaños (inicialización en _ready)
var deck_card_size: Vector2 = Vector2.ZERO

@export var max_visible_cards: int = 3      # Cartas que se muestran superpuestas
@export var card_back_scene: PackedScene    # Escena de CardBack
@export var stack_offset: float = 6.0       # Offset vertical por carta
@export var show_counter: bool = true

var _card_count: int = 0
var _counter_label: Label


func _ready() -> void:
	##super._ready()
	# Inicializar tamaño de cartas desde CardSizeConfig (autoload)
	deck_card_size = CardSizeConfig.get_deck_card_size()
	_ensure_counter()
	arrange_cards()


func _ensure_counter() -> void:
	if show_counter:
		if not has_node("Counter"):
			_counter_label = Label.new()
			_counter_label.name = "Counter"
			_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_counter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_counter_label.label_settings = LabelSettings.new()
			_counter_label.label_settings.font_size = 24
			add_child(_counter_label)
		else:
			_counter_label = $Counter
	else:
		if has_node("Counter"):
			$Counter.queue_free()
		_counter_label = null


# ============================================================
#   API PRINCIPAL
# ============================================================

func set_count(n: int) -> void:
	_card_count = max(n, 0)
	_rebuild_visual()
	arrange_cards()


func reset_deck(n: int) -> void:
	_card_count = max(n, 0)
	_rebuild_visual()
	arrange_cards()


func push_card_back() -> void:
	_card_count += 1
	_rebuild_visual()
	arrange_cards()


func pop_card_back() -> void:
	if _card_count > 0:
		_card_count -= 1
		_rebuild_visual()
		arrange_cards()


# ============================================================
#   RECONSTRUCCIÓN VISUAL
# ============================================================

func _rebuild_visual() -> void:
	# Borra todos los nodos hijos visibles (no el Counter)
	for child in get_children():
		if child != _counter_label:
			child.queue_free()

	# Crear las cartas visibles
	var cards_visible: int = min(_card_count, max_visible_cards)

	for i in range(cards_visible):
		var back = card_back_scene.instantiate()
		back.position = Vector2(0, -i * stack_offset)
		back.z_index = i
		add_child(back)

	# Contador visual
	if _counter_label:
		_counter_label.text = str(_card_count)
		_counter_label.position = Vector2(0, 30)


# ============================================================
#   CARDCOLLECTION OVERRIDES
# ============================================================

func _update_layout() -> void:
	"""Override del método template de CardCollection"""
	arrange_cards()
	super._update_layout()  # Emitir señal

func arrange_cards() -> void:
	# Centrado dentro del layout
	# Nada complejo porque es un stack
	for child in get_children():
		if child == _counter_label:
			continue
		if child is Control:
			child.position.x = (size.x - child.size.x) * 0.5


# No queremos permitir añadir nodos arbitrarios desde fuera.
func add_card(_card: Node) -> void:
	push_warning("DeckLayout no usa add_card(). Usa set_count(), push_card_back(), etc.")


func remove_card(_card: Node) -> void:
	push_warning("DeckLayout no usa remove_card(). Usa pop_card_back().")
