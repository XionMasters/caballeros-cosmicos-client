# KnightZone.gd (CORREGIDO)
# Zona especializada para caballeros (5 slots de guerreros)
extends CardZone
class_name KnightZone

# ============================================================================
# CICLO DE VIDA
# ============================================================================
func _ready() -> void:
	print("[KnightZone] Inicializando zona de caballeros")
	super._ready()
