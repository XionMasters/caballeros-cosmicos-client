# KnightZone.gd
# Zona especializada para caballeros (5 slots de guerreros)
extends CardZone
class_name KnightZone

# ============================================================================
# SOBRECARGAS ESPECÍFICAS PARA CABALLEROS
# ============================================================================

func _ready() -> void:
	print("[KnightZone] Inicializando zona de caballeros")
	super._ready()


# Override si necesitas lógica específica de caballeros
# Por ahora, CardZone base es suficiente
