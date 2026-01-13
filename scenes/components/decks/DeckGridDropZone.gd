# DeckGridDropZone.gd
# Script para el GridContainer del mazo que acepta drops de cartas
extends GridContainer

signal card_dropped(card: CardData)

func _can_drop_data(_at_position: Vector2, data) -> bool:
	# Aceptar solo si es CardData
	return data is CardData

func _drop_data(_at_position: Vector2, data):
	# Emitir señal con la carta dropeada
	if data is CardData:
		card_dropped.emit(data)
