# SingleCardSlot.gd
# Slot para zonas de una sola carta (ocasión, ayudante, escenario)
extends Control
class_name SingleCardSlot

# ============================================================================
# REFERENCIAS
# ============================================================================
@onready var card_display: Control = null  # CardDisplay o CardBack
var card_instance: CardInstance = null

# ============================================================================
# PARÁMETROS
# ============================================================================
@export var slot_type: String = "helper"  # "helper", "occasion", "scenario"

# ============================================================================
# SEÑALES
# ============================================================================
signal card_placed(card: CardInstance)
signal card_removed

# ============================================================================
# CICLO DE VIDA
# ============================================================================
func _ready() -> void:
	print("[SingleCardSlot] Inicializando slot %s" % slot_type)
	custom_minimum_size = Vector2(140, 200)  # Tamaño fijo para una carta


# ============================================================================
# MÉTODOS PÚBLICOS
# ============================================================================
func place_card(new_card: CardInstance) -> bool:
	"""Colocar carta en este slot (máximo 1)"""
	if card_instance != null:
		push_error("[SingleCardSlot] El slot %s ya tiene una carta" % slot_type)
		return false
	
	card_instance = new_card
	
	# Renderizar carta visual (si tienes un template)
	_render_card_visual()
	card_placed.emit(new_card)
	return true


func remove_card() -> CardInstance:
	"""Remover y retornar la carta"""
	if card_instance == null:
		return null
	
	var temp = card_instance
	card_instance = null
	
	# Limpiar visual
	if card_display:
		card_display.queue_free()
		card_display = null
	
	card_removed.emit()
	return temp


func has_card() -> bool:
	"""¿Hay una carta en este slot?"""
	return card_instance != null


func clear() -> void:
	"""Limpiar el slot"""
	remove_card()


# ============================================================================
# RENDERIZACIÓN INTERNA
# ============================================================================
func _render_card_visual() -> void:
	"""Renderizar la visual de la carta (override si es necesario)"""
	# Placeholder: aquí irá la lógica de crear CardDisplay
	print("[SingleCardSlot] 📍 Carta colocada en %s" % slot_type)
