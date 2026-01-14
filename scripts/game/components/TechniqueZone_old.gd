# TechniqueZone.gd
# Zona especializada para técnicas (5 slots de técnicas)
extends CardZone
class_name TechniqueZone

# ============================================================================
# SOBRECARGAS ESPECÍFICAS PARA TÉCNICAS
# ============================================================================

func _ready() -> void:
	print("[TechniqueZone] Inicializando zona de técnicas")
	super._ready()


# Override si necesitas lógica específica de técnicas
# Por ahora, CardZone base es suficiente
