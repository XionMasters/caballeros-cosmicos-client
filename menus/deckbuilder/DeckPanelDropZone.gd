# DeckPanelDropZone.gd
# Script para permitir drag-and-drop en todo el panel del deck
extends PanelContainer

signal card_dropped(card: CardData)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is CardData

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is CardData:
		card_dropped.emit(data as CardData)
