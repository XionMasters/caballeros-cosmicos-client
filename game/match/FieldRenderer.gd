# FieldRenderer.gd
# Renderiza el campo desde el GameState: caballeros, fila de técnicas/objetos,
# ayudante, ocasión y escenario.
# No tiene estado de juego propio — solo transforma CardInstance[] en nodos visuales.

class_name FieldRenderer
extends RefCounted

const CARD_DISPLAY_SCENE = preload("res://cards/CardDisplay.tscn")

var _player_zone: Node
var _opponent_zone: Node

# Posiciones de soporte (las configura GameMatch con set_support_slots)
var _player_support: Array = []    # 5 CardSlot de la fila de técnicas/objetos propia (índice = posición)
var _opponent_support: Array = []  # ídem del rival
var _single_slots: Dictionary = {} # player_helper, opponent_helper, player_occasion, opponent_occasion, scenario


func _init(player_zone: Node, opponent_zone: Node) -> void:
	_player_zone = player_zone
	_opponent_zone = opponent_zone


# ============================================================================
# API PÚBLICA
# ============================================================================

func set_support_slots(player_support: Array, opponent_support: Array, single_slots: Dictionary) -> void:
	_player_support = player_support
	_opponent_support = opponent_support
	_single_slots = single_slots


func render_field(game_state: GameState) -> void:
	"""Sincronizar todo el campo con el GameState actual."""
	_render_knight_zone(_player_zone, game_state.player_field_knights, false)
	_render_knight_zone(_opponent_zone, game_state.opponent_field_knights, true)

	_render_slot_list(_player_support, game_state.player_field_techniques, false)
	_render_slot_list(_opponent_support, game_state.opponent_field_techniques, true)
	_render_single(_single_slots.get("player_helper"), game_state.player_helper, false)
	_render_single(_single_slots.get("opponent_helper"), game_state.opponent_helper, true)
	_render_single(_single_slots.get("player_occasion"), game_state.player_occasion, false)
	_render_single(_single_slots.get("opponent_occasion"), game_state.opponent_occasion, true)
	# El escenario es compartido: se muestra sin interacción (el detalle sigue con clic derecho)
	_render_single(_single_slots.get("scenario"), game_state.scenario, true)


func clear_support_slots() -> void:
	"""Vaciar técnicas, ayudantes, ocasiones y escenario (al cambiar de perspectiva)."""
	for slot in _support_slots():
		if slot.is_occupied:
			_clear_slot_fast(slot)


func clear_all_slots(zone: Node) -> void:
	"""Vaciar todos los slots de una zona (usado al cambiar perspectiva)."""
	if not zone:
		return
	for slot in zone.get_children():
		if slot is CardSlot and slot.is_occupied:
			_clear_slot_fast(slot)


# ============================================================================
# INTERNOS
# ============================================================================

func _render_knight_zone(zone: Node, field_cards: Array[CardInstance], is_opponent: bool) -> void:
	"""Actualizar los slots de una zona para que reflejen el array de campo."""
	if not zone:
		return

	# Mapa posición → CardInstance
	var cards_by_pos: Dictionary = {}
	for i in range(field_cards.size()):
		if field_cards[i]:
			cards_by_pos[i] = field_cards[i]

	var slots := zone.get_children()
	for i in range(slots.size()):
		var slot = slots[i]
		if not slot is CardSlot:
			continue
		_render_single(slot, cards_by_pos.get(i, null), is_opponent)


func _render_slot_list(slots: Array, cards: Array, is_opponent: bool) -> void:
	"""Fila de posiciones indexada por posición (técnicas/objetos)."""
	for i in range(slots.size()):
		var expected: CardInstance = cards[i] if i < cards.size() else null
		_render_single(slots[i], expected, is_opponent)


func _render_single(slot, expected: CardInstance, is_opponent: bool) -> void:
	"""Deja la posición con la carta esperada (o vacía)."""
	if not (slot is CardSlot) or not is_instance_valid(slot):
		return
	if expected == null:
		if slot.is_occupied:
			_clear_slot_fast(slot)
		return
	# Ya tiene la carta correcta → no redibujar
	if slot.is_occupied and slot.card_instance and slot.card_instance.instance_id == expected.instance_id:
		return
	if slot.is_occupied:
		_clear_slot_fast(slot)
	_place_card_in_slot(slot, expected, is_opponent)


func _support_slots() -> Array:
	var out: Array = []
	for slot in _player_support + _opponent_support + _single_slots.values():
		if slot is CardSlot and is_instance_valid(slot):
			out.append(slot)
	return out


func _all_slots() -> Array:
	var out: Array = []
	for zone in [_player_zone, _opponent_zone]:
		if zone:
			for slot in zone.get_children():
				if slot is CardSlot:
					out.append(slot)
	return out + _support_slots()


func _clear_slot_fast(slot: CardSlot) -> void:
	"""Liberar carta del slot sin animación."""
	if slot.card_display_node and is_instance_valid(slot.card_display_node):
		slot.card_display_node.queue_free()
	slot.card_display_node = null
	slot.card_instance = null
	slot.is_occupied = false
	if slot.resized.is_connected(slot._reposition_card):
		slot.resized.disconnect(slot._reposition_card)
	if slot.watermark_label:
		slot.watermark_label.visible = true


func get_slot_center(is_opponent: bool, slot_index: int) -> Vector2:
	"""Devuelve la posición global central del slot indicado.
	Usado por AttackEvent para resolver coordenadas de pantalla."""
	var zone := _opponent_zone if is_opponent else _player_zone
	if not zone:
		return Vector2.ZERO
	var slots: Array = zone.get_children().filter(func(c: Node) -> bool: return c is CardSlot)
	if slot_index < 0 or slot_index >= slots.size():
		return Vector2.ZERO
	var slot: CardSlot = slots[slot_index]
	return slot.global_position + slot.size * 0.5


func get_zone_center(is_opponent: bool) -> Vector2:
	"""Devuelve el centro de la zona completa (para ataques directos sin carta defensora)."""
	var zone := _opponent_zone if is_opponent else _player_zone
	if not zone or not (zone is Control):
		return Vector2.ZERO
	var ctrl := zone as Control
	return ctrl.global_position + ctrl.size * 0.5


func find_card_position(instance_id: String) -> Vector2:
	"""Devuelve la posición global del slot que contiene la carta con ese instance_id.
	Busca en todo el campo. Retorna Vector2.ZERO si no la encuentra."""
	for slot in _all_slots():
		if slot.card_instance and slot.card_instance.instance_id == instance_id:
			return slot.global_position + slot.size * 0.5
	return Vector2.ZERO


func find_card_node(instance_id: String) -> Control:
	"""Devuelve el nodo CardDisplay del slot que contiene la carta con ese instance_id.
	Retorna null si no se encuentra."""
	for slot in _all_slots():
		if slot.card_instance and slot.card_instance.instance_id == instance_id:
			return slot.card_display_node
	return null


func _place_card_in_slot(slot: CardSlot, card_instance: CardInstance, is_opponent: bool) -> void:
	"""Instanciar un CardDisplay y colocarlo en el slot."""
	if not card_instance or not card_instance.base_data:
		print("[FieldRenderer] ⚠️ _place_card_in_slot: CardInstance sin base_data")
		return
	var card_display: CardDisplay = CARD_DISPLAY_SCENE.instantiate()
	card_display.setup_from_instance(card_instance)
	if is_opponent:
		card_display.interaction_enabled = false
		card_display.disable_hover_animation = true
	slot.place_card(card_display, false)
	# Después de place_card (que llama _ready y pone MOUSE_FILTER_STOP),
	# cambiamos a PASS para que el clic llegue también al CardSlot.
	card_display.mouse_filter = Control.MOUSE_FILTER_PASS
	# Las cartas en campo NO se deben arrastrar (moverlas usa la acción "move" del panel).
	# dragging_enabled=false en campo; solo las cartas en mano admiten drag-and-drop.
	if not is_opponent:
		card_display.dragging_enabled = false
