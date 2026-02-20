# Zona especializada para caballeros (5 slots de guerreros)
extends RowZone
class_name KnightZone

# ============================================================================
# CONFIGURACIÓN
# ============================================================================
@export var max_knights := 5

# ============================================================================
# CICLO DE VIDA
# ============================================================================
func _ready() -> void:
	print("[KnightZone] Inicializando zona de caballeros")
	max_cards = max_knights
	super._ready()

func can_place_card(card_data: Dictionary) -> bool:
	return card_data.type == "KNIGHT"

#func can_place_card(card: CardInstance) -> bool:
#	return card.is_knight()

func _on_slot_card_placed(slot: CardSlot, card_display: Control) -> void:
	super._on_slot_card_placed(slot, card_display)

	print("⚔️ Caballero colocado en slot", slot.slot_index)

	# Ejemplo futuro:
	# server.declare_knight(card_display.card_id, slot.slot_index)
