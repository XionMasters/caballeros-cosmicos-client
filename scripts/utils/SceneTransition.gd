# SceneTransition.gd
# Singleton para manejar transiciones entre escenas y pasar datos
extends Node

var pending_deck_data: Dictionary = {}

func go_to_deck_builder(deck: Dictionary):
	"""Ir al editor de mazos con un deck específico"""
	pending_deck_data = deck
	get_tree().change_scene_to_file("res://scenes/menus/DeckBuilder.tscn")

func get_pending_deck() -> Dictionary:
	"""Obtener el deck pendiente y limpiar"""
	var deck = pending_deck_data.duplicate()
	pending_deck_data.clear()
	return deck

func has_pending_deck() -> bool:
	"""Verificar si hay un deck pendiente"""
	return not pending_deck_data.is_empty()
