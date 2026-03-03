# KnightActionController.gd
# Gestiona toda la interacción con los caballeros en campo:
#   - Setup de señales en slots (card_dropped, slot_clicked)
#   - Modo selección de objetivo (highlight + cursor)
#   - Dispatch de acciones (attack, move, charge, etc.) al servidor

class_name KnightActionController
extends RefCounted

var _player_zone: Node
var _opponent_zone: Node
var _parent_node: Node   # Para añadir KnightActionsPanel al árbol de escena

var _knight_actions_panel: Control = null

# Estado de selección
var _pending_attacker_id: String = ""
var _pending_move_id: String = ""
var _is_selecting_attack: bool = false
var _is_selecting_move: bool = false
var _highlighted_slots: Array = []


func _init(player_zone: Node, opponent_zone: Node, parent_node: Node) -> void:
	_player_zone = player_zone
	_opponent_zone = opponent_zone
	_parent_node = parent_node


# ============================================================================
# API PÚBLICA
# ============================================================================

func setup() -> void:
	"""Instanciar KnightActionsPanel y conectar todas las señales de slots."""
	# Panel de acciones
	_knight_actions_panel = Control.new()
	_knight_actions_panel.set_script(load("res://ui/KnightActionsPanel.gd"))
	_parent_node.add_child(_knight_actions_panel)
	_knight_actions_panel.action_selected.connect(_on_knight_action_selected)

	# Zona propia: card_dropped + slot_clicked
	if _player_zone:
		for slot in _player_zone.get_children():
			if slot.has_signal("card_dropped") and not slot.card_dropped.is_connected(_on_card_dropped):
				slot.card_dropped.connect(_on_card_dropped)
			if slot.has_signal("slot_clicked") and not slot.slot_clicked.is_connected(_on_player_slot_clicked):
				slot.slot_clicked.connect(_on_player_slot_clicked)

	# Zona rival: solo slot_clicked (objetivos de ataque)
	if _opponent_zone:
		for slot in _opponent_zone.get_children():
			if slot.has_signal("slot_clicked") and not slot.slot_clicked.is_connected(_on_opponent_slot_clicked):
				slot.slot_clicked.connect(_on_opponent_slot_clicked)

	print("[KnightActionController] ✅ Setup completo")


func is_selecting() -> bool:
	"""Devuelve true si hay un modo de selección de objetivo activo."""
	return _is_selecting_attack or _is_selecting_move


func cancel_selection() -> void:
	"""Cancela cualquier modo de selección activo y limpia el estado pendiente."""
	_stop_selection()
	_is_selecting_attack = false
	_is_selecting_move = false
	_pending_attacker_id = ""
	_pending_move_id = ""
	print("[KnightActionController] ❌ Selección cancelada")


# ============================================================================
# MODO SELECCIÓN (highlights + cursor)
# ============================================================================

func _start_selection(targets: Array, color: Color) -> void:
	_stop_selection()
	for slot in targets:
		if slot is CardSlot:
			_highlighted_slots.append(slot)
			slot.set_target_highlight(true, color)
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_CROSS)


func _stop_selection() -> void:
	for slot in _highlighted_slots:
		if is_instance_valid(slot):
			slot.set_target_highlight(false)
	_highlighted_slots.clear()
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)


# ============================================================================
# HELPERS DE SLOT (traducir IDs/índices del servidor → nodos)
# ============================================================================

func _slots_from_ids(zone: Node, ids: Array) -> Array:
	"""Devuelve los CardSlots de una zona cuya card_instance.instance_id está en ids."""
	if not zone:
		return []
	var result: Array = []
	for slot in zone.get_children():
		if not slot is CardSlot:
			continue
		if slot.card_instance and ids.has(slot.card_instance.instance_id):
			result.append(slot)
	return result


func _slots_from_indices(zone: Node, indices: Array) -> Array:
	"""Devuelve los CardSlots de una zona cuyo get_index() está en indices."""
	if not zone:
		return []
	var children := zone.get_children()
	var result: Array = []
	for idx in indices:
		var i := int(idx)
		if i >= 0 and i < children.size():
			var slot = children[i]
			if slot is CardSlot:
				result.append(slot)
	return result


# ============================================================================
# CALLBACKS DE SLOTS
# ============================================================================

func _on_player_slot_clicked(slot: Node) -> void:
	if _is_selecting_move:
		if slot.card_instance == null:
			var pos: int = slot.get_index()
			_stop_selection()
			_is_selecting_move = false
			MatchSessionService.send_move_knight(_pending_move_id, pos)
			_pending_move_id = ""
		else:
			print("[KnightActionController] ⚠️ Slot ocupado, elige uno vacío")
		return

	if _is_selecting_attack:
		print("[KnightActionController] ⚠️ No puedes atacar a un aliado")
		cancel_selection()
		return

	# Sin modo especial: mostrar panel de acciones
	if slot.card_instance == null:
		return
	_knight_actions_panel.show_actions_for_knight(slot)


func _on_opponent_slot_clicked(slot: Node) -> void:
	if _is_selecting_attack:
		var defender_id: String = slot.card_instance.instance_id if slot.card_instance else ""
		var attacker_id := _pending_attacker_id
		_stop_selection()
		_is_selecting_attack = false
		_pending_attacker_id = ""
		print("[KnightActionController] ⚔️ %s → %s" % [
			attacker_id, defender_id if defender_id else "(daño directo)"
		])
		MatchSessionService.send_attack(attacker_id, defender_id)


func _on_knight_action_selected(action: String, source_slot: Node) -> void:
	var card_inst: CardInstance = source_slot.card_instance if source_slot else null
	if not card_inst:
		print("[KnightActionController] ❌ Sin carta para: %s" % action)
		return
	var iid := card_inst.instance_id

	match action:
		"attack":
			var va := card_inst.valid_actions
			var raw_targets = va.get("attack_targets", null)
			if raw_targets == null:
				print("[KnightActionController] ⚠️ Ataque no disponible (valid_actions lo bloquea)")
				return
			var target_ids := raw_targets as Array
			if target_ids.is_empty():
				# Ataque directo — no hay knights rivales en campo
				print("[KnightActionController] ⚔️ Ataque directo")
				MatchSessionService.send_attack(iid, "")
				return
			# Resaltar slots rivales cuyo instance_id está en target_ids
			var target_slots := _slots_from_ids(_opponent_zone, target_ids)
			if target_slots.is_empty():
				print("[KnightActionController] ⚠️ No se encontraron slots para los targets, ataque directo")
				MatchSessionService.send_attack(iid, "")
				return
			_pending_attacker_id = iid
			_is_selecting_attack = true
			_start_selection(target_slots, Color(1.0, 0.2, 0.2))
			print("[KnightActionController] ⚔️ Selecciona objetivo rival")

		"charge":
			print("[KnightActionController] 💫 Cargando cosmos")
			MatchSessionService.send_charge_cosmos()

		"sacrifice":
			print("[KnightActionController] 💀 Sacrificando %s" % iid)
			MatchSessionService.send_sacrifice_knight(iid)

		"evade":
			print("[KnightActionController] 🌀 Modo evasión: %s" % iid)
			MatchSessionService.send_change_defensive_mode(iid, "evasion")

		"block":
			print("[KnightActionController] 🛡️ Modo defensa: %s" % iid)
			MatchSessionService.send_change_defensive_mode(iid, "defense")

		"move":
			var va := card_inst.valid_actions
			var raw_indices = va.get("move_targets", [])
			var move_indices := raw_indices as Array
			if move_indices.is_empty():
				print("[KnightActionController] ⚠️ Sin slots válidos para mover (valid_actions)")
				return
			var target_slots := _slots_from_indices(_player_zone, move_indices)
			if target_slots.is_empty():
				print("[KnightActionController] ⚠️ No se encontraron slots destino")
				return
			_pending_move_id = iid
			_is_selecting_move = true
			_start_selection(target_slots, Color(0.2, 0.6, 1.0))
			print("[KnightActionController] 🔄 Selecciona slot destino")

		"technique", "pray":
			print("[KnightActionController] ℹ️ '%s' aún no implementado" % action)


func _on_card_dropped(payload: Dictionary) -> void:
	"""Una carta fue arrastrada y soltada en un slot → enviar play_card al servidor."""
	var card_instance: CardInstance = payload.get("card_instance")
	if not card_instance:
		print("[KnightActionController] ❌ card_dropped sin card_instance")
		return
	var target_slot = payload.get("target_slot")
	var slot_type: int = payload.get("slot_type", CardSlot.SlotType.KNIGHT)
	var zone := _slot_type_to_zone(slot_type)
	if zone.is_empty():
		print("[KnightActionController] ❌ zona desconocida: %s" % slot_type)
		return
	var pos := 0
	if target_slot and is_instance_valid(target_slot):
		pos = target_slot.get_index()
	print("[KnightActionController] 🃏 %s → %s[%d]" % [card_instance.instance_id, zone, pos])
	MatchSessionService.play_card(card_instance.instance_id, zone, pos)


func _slot_type_to_zone(slot_type: int) -> String:
	match slot_type:
		CardSlot.SlotType.KNIGHT:      return "field_knight"
		CardSlot.SlotType.TECH_OBJECT: return "field_technique"
		CardSlot.SlotType.HELPER:      return "field_helper"
		CardSlot.SlotType.SCENARIO:    return "field_scenario"
		CardSlot.SlotType.OCCASION:    return "field_occasion"
	return ""
