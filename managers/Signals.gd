# Signals.gd - central signal bus for card interactions
extends Node
class_name Signals

signal card_state_changed(card_instance, old_state: String, new_state: String)
signal card_moved_to_zone(card_instance, from_zone: String, to_zone: String)
signal card_played(card_instance, player_id: String)

func emit_card_state_changed(card_instance, old_state: String, new_state: String) -> void:
	card_state_changed.emit(card_instance, old_state, new_state)


func emit_card_moved_to_zone(card_instance, from_zone: String, to_zone: String) -> void:
	card_moved_to_zone.emit(card_instance, from_zone, to_zone)


func emit_card_played(card_instance, player_id: String) -> void:
	card_played.emit(card_instance, player_id)
