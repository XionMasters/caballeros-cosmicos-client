# CardZone.gd
# Base genérica para zonas de 5 cartas (caballeros, técnicas)
extends Control
class_name CardZone

# ============================================================================
# REFERENCIAS A SLOTS
# ============================================================================
var slots: Array[CardSlot] = []
var slot_nodes: Array[Node] = []

# ============================================================================
# PARÁMETROS CONFIGURABLES
# ============================================================================
@export var max_cards: int = 5
@export var slot_spacing: float = 10.0
@export var is_opponent_zone: bool = false

# ============================================================================
# SEÑALES
# ============================================================================
signal card_placed(slot: CardSlot, card: CardInstance)
signal card_removed(slot: CardSlot)

# ============================================================================
# CICLO DE VIDA
# ============================================================================
func _ready() -> void:
	print("[CardZone] Inicializando con %d slots" % max_cards)
	_collect_slots()


func _collect_slots() -> void:
	"""Recopilar referencias a los nodos CardSlot hijos"""
	slots.clear()
	slot_nodes.clear()
	
	for child in get_children():
		if child is CardSlot:
			slots.append(child)
			slot_nodes.append(child)
			
			# Conectar señales del slot
			if not child.card_placed.is_connected(_on_slot_card_placed):
				child.card_placed.connect(_on_slot_card_placed.bind(child))
			if not child.card_removed.is_connected(_on_slot_card_removed):
				child.card_removed.connect(_on_slot_card_removed.bind(child))
	
	print("[CardZone] ✅ Recopilados %d slots" % slots.size())


# ============================================================================
# MÉTODOS PÚBLICOS
# ============================================================================
func clear_zone() -> void:
	"""Limpiar todos los slots"""
	for slot in slots:
		slot.clear()


func get_filled_slots() -> Array[CardSlot]:
	"""Retornar solo slots con cartas"""
	var filled = []
	for slot in slots:
		if slot.has_card():
			filled.append(slot)
	return filled


func get_empty_slots() -> Array[CardSlot]:
	"""Retornar solo slots vacíos"""
	var empty = []
	for slot in slots:
		if not slot.has_card():
			empty.append(slot)
	return empty


func place_card_in_slot(card_instance: CardInstance, slot_index: int) -> bool:
	"""Colocar carta en un slot específico"""
	if slot_index < 0 or slot_index >= slots.size():
		push_error("[CardZone] Índice de slot inválido: %d" % slot_index)
		return false
	
	var slot = slots[slot_index]
	if slot.has_card():
		push_error("[CardZone] Slot %d ya tiene una carta" % slot_index)
		return false
	
	return slot.place_card(card_instance)


func remove_card_from_slot(slot_index: int) -> CardInstance:
	"""Remover carta de un slot"""
	if slot_index < 0 or slot_index >= slots.size():
		return null
	
	return slots[slot_index].remove_card()


# ============================================================================
# SEÑALES INTERNAS
# ============================================================================
func _on_slot_card_placed(slot: CardSlot) -> void:
	"""Se disparó cuando una carta se colocó en un slot"""
	card_placed.emit(slot, slot.card_instance)


func _on_slot_card_removed(slot: CardSlot) -> void:
	"""Se disparó cuando una carta se removió de un slot"""
	card_removed.emit(slot)


# ============================================================================
# MÉTODOS PARA RENDERIZACIÓN (Override en subclases si es necesario)
# ============================================================================
func render_from_game_state(zone_cards: Array, zone_name: String) -> void:
	"""Renderizar cartas desde GameState para una zona específica
	
	zone_cards: Array de CardInstance
	zone_name: "field_knight", "field_technique", etc
	"""
	clear_zone()
	
	for i in range(min(zone_cards.size(), slots.size())):
		var card_instance = zone_cards[i]
		var slot = slots[i]
		slot.place_card(card_instance)
