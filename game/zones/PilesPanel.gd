# PilesPanel.gd
# Pilas de descarte (Yomotsu + Cositos): dos fichas con el número grande.
# El número salta cuando cambia, para que se note que una carta llegó a la pila.
extends PanelContainer
class_name PilesPanel

# ============================================================================
# REFERENCIAS A NODOS
# ============================================================================
@onready var yomotsu_label: Label = $Row/YomotsuChip/Box/YomotsuLabel
@onready var cositos_label: Label = $Row/CositosChip/Box/CositosLabel

# ============================================================================
# ESTADO
# ============================================================================
var yomotsu_count: int = 0
var cositos_count: int = 0


# ============================================================================
# MÉTODOS PÚBLICOS
# ============================================================================
func update_yomotsu(count: int) -> void:
	"""Actualizar contador de Yomotsu"""
	var changed := count != yomotsu_count
	yomotsu_count = count
	_set_count(yomotsu_label, count, changed)


func update_cositos(count: int) -> void:
	"""Actualizar contador de Cositos"""
	var changed := count != cositos_count
	cositos_count = count
	_set_count(cositos_label, count, changed)


func update_both(yomotsu: int, cositos: int) -> void:
	"""Actualizar ambos contadores"""
	update_yomotsu(yomotsu)
	update_cositos(cositos)


func reset() -> void:
	"""Resetear contadores"""
	update_both(0, 0)


func _set_count(label: Label, count: int, animate: bool) -> void:
	if not label:
		return
	label.text = str(count)
	if animate:
		label.pivot_offset = label.size / 2.0
		var pop := create_tween()
		pop.tween_property(label, "scale", Vector2(1.4, 1.4), 0.1)
		pop.tween_property(label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
