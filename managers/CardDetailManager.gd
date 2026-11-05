# CardDetailManager.gd
# Autoload: muestra el detalle de una carta (CardInspector) desde cualquier escena.
#   show_card(card)                 → carta de colección/sobres
#   show_instance(instance)         → carta en juego (estadísticas actuales y estados)
#   show_at_global_position(pos)    → la carta visible bajo ese punto (p. ej. en una repetición)
# En partida se abre con clic derecho o doble clic sobre cualquier carta visible.
extends Node

const INSPECTOR_SCRIPT := preload("res://cards/CardInspector.gd")
const INSPECTOR_LAYER := 100  # por encima del tablero, efectos y controles de repetición

var _layer: CanvasLayer = null
var _inspector: Control = null
var _last_open_id := ""
var _last_open_msec := 0


func show_card(card: CardData, texture: Texture2D = null, _show_add_to_deck: bool = false) -> void:
	"""Compatibilidad con la API anterior (colección, apertura de sobres)."""
	_open(card, null, texture)


func show_instance(instance: CardInstance) -> void:
	if instance == null or instance.hidden or instance.base_data == null:
		return
	_open(instance.base_data, instance, null)


func show_at_global_position(global_pos: Vector2) -> bool:
	"""Abre el detalle de la carta visible bajo `global_pos`. Devuelve si encontró alguna."""
	var scene := get_tree().current_scene
	if scene == null:
		return false
	# (find_children no filtra por class_name de script: se filtra con `is`)
	var nodes := scene.find_children("*", "", true, false)
	# Posiciones del campo (incluido el rival) primero; después las cartas sueltas (mano, etc.)
	for node in nodes:
		if node is CardSlot and node.is_visible_in_tree() and node.card_instance \
				and node.get_global_rect().has_point(global_pos):
			show_instance(node.card_instance)
			return true
	var hit: CardDisplay = null
	for node in nodes:
		if node is CardDisplay and node.is_visible_in_tree() and node.get_global_rect().has_point(global_pos):
			hit = node  # el último del árbol es el que se dibuja encima
	if hit:
		if hit.card_instance:
			show_instance(hit.card_instance)
		elif hit.card_data:
			show_card(hit.card_data)
		return true
	return false


func is_open() -> bool:
	return _inspector != null and is_instance_valid(_inspector) and _inspector.visible


func hide_detail() -> void:
	if is_open():
		_inspector.close()


func _open(card: CardData, instance: CardInstance, texture: Texture2D) -> void:
	if card == null:
		return
	# Un mismo gesto puede llegar por la carta y por su posición: ignorar el duplicado
	var id := instance.instance_id if instance else card.id
	var now := Time.get_ticks_msec()
	if is_open() and id == _last_open_id and now - _last_open_msec < 400:
		return
	_last_open_id = id
	_last_open_msec = now
	_ensure_inspector()
	if _inspector:
		_inspector.show_card(card, instance, texture)


func _ensure_inspector() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	# El inspector vive en la escena actual: al cambiar de escena se crea de nuevo
	if _layer and is_instance_valid(_layer) and _layer.get_parent() == scene:
		return
	_layer = CanvasLayer.new()
	_layer.name = "CardInspectorLayer"
	_layer.layer = INSPECTOR_LAYER
	scene.add_child(_layer)
	_inspector = INSPECTOR_SCRIPT.new()
	_inspector.name = "CardInspector"
	_layer.add_child(_inspector)
