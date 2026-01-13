# OpponentProvider.gd
# Interface para obtener el oponente
# Permite soportar: test dummy, matchmaking, IA

class_name OpponentProvider
extends Node

# ---------------------------------------------------------
# INTERFACE: Subclases deben implementar
# ---------------------------------------------------------

## Obtener datos del oponente para la partida
## Returns: Dictionary con estructura {id, name, deck_size}
func get_opponent() -> Dictionary:
	push_error("OpponentProvider.get_opponent() debe ser implementado")
	return {}


## Si el oponente necesita preparación previa (conexión, matchmaking, etc)
signal opponent_provider_ready(opponent: Dictionary)

func prepare() -> void:
	"""Hook opcional: preparación previa (matchmaking, conexión, etc)"""
	opponent_provider_ready.emit(get_opponent())
