# PilesPanel.gd
# Panel de pilas de descarte (Yomotsu + Cositos)
extends Control
class_name PilesPanel

# ============================================================================
# REFERENCIAS A NODOS
# ============================================================================
@onready var yomotsu_label = $VBoxContainer/YomotsuLabel
@onready var cositos_label = $VBoxContainer/CositosLabel

# ============================================================================
# ESTADO
# ============================================================================
var yomotsu_count: int = 0
var cositos_count: int = 0

# ============================================================================
# CICLO DE VIDA
# ============================================================================
func _ready() -> void:
	print("[PilesPanel] Inicializando panel de pilas")
	custom_minimum_size = Vector2(150, 200)


# ============================================================================
# MÉTODOS PÚBLICOS
# ============================================================================
func update_yomotsu(count: int) -> void:
	"""Actualizar contador de Yomotsu"""
	yomotsu_count = count
	if yomotsu_label:
		yomotsu_label.text = "Yomotsu: %d" % count


func update_cositos(count: int) -> void:
	"""Actualizar contador de Cositos"""
	cositos_count = count
	if cositos_label:
		cositos_label.text = "Cositos: %d" % count


func update_both(yomotsu: int, cositos: int) -> void:
	"""Actualizar ambos contadores"""
	update_yomotsu(yomotsu)
	update_cositos(cositos)


func reset() -> void:
	"""Resetear contadores"""
	update_both(0, 0)
