# TestOpponentProvider.gd
# Implementación para TEST: dummy opponent local
# Reutilizable en: TestBoard, Tutorial, Práctica local

class_name TestOpponentProvider
extends OpponentProvider

# ---------------------------------------------------------
# CONSTANTS
# ---------------------------------------------------------
const DUMMY_OPPONENT = {
	"id": "test-opponent-001",
	"name": "Oponente de Test",
	"deck_size": 40
}


# ---------------------------------------------------------
# API PÚBLICA
# ---------------------------------------------------------
func get_opponent() -> Dictionary:
	"""Retorna dummy opponent inmediatamente"""
	return DUMMY_OPPONENT


func prepare() -> void:
	"""Para test, es instantáneo"""
	opponent_provider_ready.emit(DUMMY_OPPONENT)
