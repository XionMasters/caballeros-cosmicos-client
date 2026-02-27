# CardZone.gd (CORREGIDO)
# Base genérica para zonas de 5 cartas (caballeros, técnicas)
extends HBoxContainer
class_name CardZone

# ============================================================================
# REFERENCIAS A SLOTS
# ============================================================================
var slots: Array[CardSlot] = []

# ============================================================================
# PARÁMETROS CONFIGURABLES
# ============================================================================
@export var max_cards: int = 5

# ============================================================================
# SEÑALES
# ============================================================================
signal card_placed(slot: CardSlot, card_display: Control)

# ============================================================================
# CICLO DE VIDA
# ============================================================================
func _ready() -> void:
	print("[CardZone] Inicializando zona")
	_collect_slots()
	resized.connect(_recalculate_separation)
	call_deferred("_recalculate_separation")


func _recalculate_separation() -> void:
	"""Calcula el espacio entre slots según el ancho disponible"""
	var num_slots := max_cards
	var card_w := CardSizeConfig.card_width
	var available := size.x
	var total_cards := num_slots * card_w
	var gaps := num_slots - 1
	var sep := 8.0  # mínimo
	if gaps > 0 and available > total_cards:
		sep = (available - total_cards) / gaps
	add_theme_constant_override("separation", int(sep))


func _collect_slots() -> void:
	"""Recopilar referencias a los nodos CardSlot hijos"""
	slots.clear()
	
	# Buscar todos los CardSlot en los HBoxContainer > [Slot1..5]
	for child in get_all_children(self):
		if child is CardSlot:
			slots.append(child as CardSlot)
			
			# Conectar señales del slot si existen
			if child.has_signal("card_placed"):
				if not child.card_placed.is_connected(_on_slot_card_placed):
					child.card_placed.connect(_on_slot_card_placed.bind(child))
	
	print("[CardZone] ✅ Recopilados %d slots" % slots.size())


func get_all_children(node: Node) -> Array[Node]:
	"""Buscar todos los nodos hijos recursivamente"""
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(get_all_children(child))
	return result


# ============================================================================
# MÉTODOS PÚBLICOS
# ============================================================================
func get_filled_slots() -> Array[CardSlot]:
	"""Retornar solo slots con cartas"""
	var filled: Array[CardSlot] = []
	for slot in slots:
		if slot.is_occupied:
			filled.append(slot)
	return filled


func get_empty_slots() -> Array[CardSlot]:
	"""Retornar solo slots vacíos"""
	var empty: Array[CardSlot] = []
	for slot in slots:
		if not slot.is_occupied:
			empty.append(slot)
	return empty


# ============================================================================
# SEÑALES INTERNAS
# ============================================================================
func _on_slot_card_placed(slot: CardSlot, card_display: Control) -> void:
	"""Se disparó cuando una carta se colocó en un slot"""
	card_placed.emit(slot, card_display)
