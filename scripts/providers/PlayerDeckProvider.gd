# PlayerDeckProvider.gd
# Interface para obtener el deck del jugador
# Permite soportar: test, online, offline, IA

class_name PlayerDeckProvider
extends Node

# ---------------------------------------------------------
# INTERFACE: Subclases deben implementar
# ---------------------------------------------------------

## Obtener el deck del jugador actual
## Returns: Dictionary con estructura {id, name, cards: Array}
func get_player_deck() -> Dictionary:
	push_error("PlayerDeckProvider.get_player_deck() debe ser implementado")
	return {}


## Fetch inicial del deck (ej: sincronizar con servidor)
## Emite: deck_provider_ready cuando esté listo
signal deck_provider_ready(deck: Dictionary)

func prepare() -> void:
	"""Hook opcional: preparación previa (sincronización, carga, etc)"""
	deck_provider_ready.emit(get_player_deck())
