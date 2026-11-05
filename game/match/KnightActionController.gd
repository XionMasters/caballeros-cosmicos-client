# KnightActionController.gd
# Gestiona toda la interacción con los caballeros en campo:
#   - Setup de señales en slots (card_dropped, slot_clicked)
#   - Modo selección de objetivo (highlight + cursor)
#   - Dispatch de acciones (attack, technique, ability, move, charge, etc.) al servidor
#   - Selecciones pendientes que pide el servidor (pending_selection → resolve_selection)
#
# El cliente nunca calcula reglas: los objetivos válidos salen de valid_actions
# y de pending_selection, que calcula el servidor.

class_name KnightActionController
extends RefCounted

var _player_zone: Node
var _opponent_zone: Node
var _parent_node: Node   # Para añadir KnightActionsPanel al árbol de escena

var _knight_actions_panel: Control = null
var _choice_panel: PanelContainer = null   # Lista de cartas para selecciones fuera del campo

# Modo de selección activo: "" (ninguno), "attack", "technique", "ability_target",
# "move", "server_card" (pending_selection de carta) o "server_slot" (pending_selection de posición)
var _mode: String = ""
var _pending_source_id: String = ""      # Caballero que ejecuta la acción
var _pending_option: Dictionary = {}     # Técnica o habilidad elegida
var _valid_target_ids: Array = []        # instance_ids seleccionables (modos de carta)
var _valid_slot_owner: String = ""       # "player" | "opponent" (modo server_slot)
var _valid_slots: Array = []             # índices seleccionables (modos move / server_slot)
var _answered_selection_id: String = ""  # Evita responder dos veces la misma selección
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
	_knight_actions_panel.option_selected.connect(_on_knight_option_selected)

	# Zona propia: card_dropped + slot_clicked
	if _player_zone:
		for slot in _player_zone.get_children():
			if slot.has_signal("card_dropped") and not slot.card_dropped.is_connected(_on_card_dropped):
				slot.card_dropped.connect(_on_card_dropped)
			if slot.has_signal("slot_clicked") and not slot.slot_clicked.is_connected(_on_player_slot_clicked):
				slot.slot_clicked.connect(_on_player_slot_clicked)

	# Zona rival: slot_clicked (objetivos)
	if _opponent_zone:
		for slot in _opponent_zone.get_children():
			if slot.has_signal("slot_clicked") and not slot.slot_clicked.is_connected(_on_opponent_slot_clicked):
				slot.slot_clicked.connect(_on_opponent_slot_clicked)

	print("[KnightActionController] ✅ Setup completo")


func connect_play_slots(slots: Array) -> void:
	"""Posiciones propias fuera de la fila de caballeros (técnicas/objetos, ayudante, ocasión,
	escenario): al soltar una carta en ellas se envía play_card igual que con los caballeros."""
	for slot in slots:
		if slot is CardSlot and slot.has_signal("card_dropped") and not slot.card_dropped.is_connected(_on_card_dropped):
			slot.card_dropped.connect(_on_card_dropped)


func is_selecting() -> bool:
	"""Devuelve true si hay un modo de selección de objetivo activo."""
	return _mode != ""


func cancel_selection() -> void:
	"""Cancela la selección local. Las selecciones del servidor son obligatorias y no se cancelan."""
	if _mode.begins_with("server_"):
		print("[KnightActionController] ⚠️ El servidor espera una elección: no se puede cancelar")
		return
	_reset_mode()
	print("[KnightActionController] ❌ Selección cancelada")


func on_action_rejected(gs: GameState) -> void:
	"""El servidor rechazó la última acción: si era la respuesta a una selección, se puede volver a elegir."""
	_answered_selection_id = ""
	refresh_pending_selection(gs)


func refresh_pending_selection(gs: GameState) -> void:
	"""Llamar tras cada actualización de estado: entra en modo selección si el servidor
	espera que el jugador local elija algo (pending_selection), o lo abandona si ya no."""
	if not gs or not gs.has_my_pending_selection():
		if _mode.begins_with("server_"):
			_reset_mode()
		_answered_selection_id = ""
		return

	var sel: Dictionary = gs.pending_selection
	var sel_id := str(sel.get("id", ""))
	if sel_id == _answered_selection_id:
		return  # Ya respondida, esperando el update del servidor

	_reset_mode()
	if str(sel.get("zone", "")) == "field_slot":
		_start_server_slot_selection(gs, sel)
	else:
		_start_server_card_selection(gs, sel)


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


func _reset_mode() -> void:
	_stop_selection()
	_close_choice_panel()
	_mode = ""
	_pending_source_id = ""
	_pending_option = {}
	_valid_target_ids = []
	_valid_slot_owner = ""
	_valid_slots = []


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


func _to_int_array(values: Array) -> Array:
	"""Los números del JSON llegan como float (4.0): [4.0].has(4) es false, así que se normalizan."""
	var result: Array = []
	for v in values:
		result.append(int(v))
	return result


func _all_field_knight_ids() -> Array:
	var ids: Array = []
	for zone in [_player_zone, _opponent_zone]:
		if not zone:
			continue
		for slot in zone.get_children():
			if slot is CardSlot and slot.card_instance:
				ids.append(slot.card_instance.instance_id)
	return ids


# ============================================================================
# CALLBACKS DE SLOTS
# ============================================================================

func _on_player_slot_clicked(slot: Node) -> void:
	match _mode:
		"move":
			if slot.card_instance == null and _valid_slots.has(slot.get_index()):
				var source := _pending_source_id
				_reset_mode()
				MatchSessionService.send_move_knight(source, slot.get_index())
			else:
				print("[KnightActionController] ⚠️ Elige un espacio vacío resaltado")
			return
		"server_slot":
			_try_answer_slot(slot, "player")
			return
		"ability_target", "server_card":
			_try_answer_card(slot)
			return
		"attack", "technique":
			print("[KnightActionController] ⚠️ No puedes atacar a un aliado")
			cancel_selection()
			return

	# Sin modo especial: mostrar panel de acciones
	if slot.card_instance == null:
		return
	_knight_actions_panel.show_actions_for_knight(slot)


func _on_opponent_slot_clicked(slot: Node) -> void:
	match _mode:
		"attack", "technique", "ability_target", "server_card":
			_try_answer_card(slot)
		"server_slot":
			_try_answer_slot(slot, "opponent")


func _try_answer_card(slot: Node) -> void:
	"""Click sobre un slot en un modo de selección de carta."""
	var target_id: String = slot.card_instance.instance_id if slot.card_instance else ""
	if target_id == "" or not _valid_target_ids.has(target_id):
		print("[KnightActionController] ⚠️ Objetivo no válido, elige uno resaltado")
		return
	_send_with_target(target_id)


func _send_with_target(target_id: String) -> void:
	"""Envía la acción del modo activo con el objetivo elegido."""
	var mode := _mode
	var source := _pending_source_id
	var option := _pending_option
	_reset_mode()
	match mode:
		"attack":
			print("[KnightActionController] ⚔️ %s → %s" % [source, target_id])
			MatchSessionService.send_attack(source, target_id)
		"technique":
			print("[KnightActionController] ✨ %s usa %s → %s" % [source, option.get("name", ""), target_id])
			MatchSessionService.send_technique_attack(source, str(option.get("technique_id", "")), target_id)
		"ability_target":
			print("[KnightActionController] 🔮 %s usa %s → %s" % [source, option.get("ability_name", ""), target_id])
			MatchSessionService.send_use_ability(source, str(option.get("ability_name", "")), target_id)
		"server_card":
			_answer_selection(target_id, -1)


func _try_answer_slot(slot: Node, owner: String) -> void:
	"""Click sobre un slot en una selección de posición del servidor."""
	if owner != _valid_slot_owner or not _valid_slots.has(slot.get_index()):
		print("[KnightActionController] ⚠️ Elige una de las posiciones resaltadas")
		return
	var index: int = slot.get_index()
	_reset_mode()
	_answer_selection("", index)


func _answer_selection(chosen_card_id: String, chosen_slot: int) -> void:
	var gs := MatchSessionService.game_state
	if gs:
		_answered_selection_id = str(gs.pending_selection.get("id", ""))
	print("[KnightActionController] ✅ Selección respondida: carta=%s posición=%d" % [chosen_card_id, chosen_slot])
	MatchSessionService.send_resolve_selection(chosen_card_id, chosen_slot)


# ============================================================================
# ACCIONES DEL PANEL
# ============================================================================

func _on_knight_action_selected(action: String, source_slot: Node) -> void:
	var card_inst: CardInstance = source_slot.card_instance if source_slot else null
	if not card_inst:
		print("[KnightActionController] ❌ Sin carta para: %s" % action)
		return
	var iid := card_inst.instance_id
	var va := card_inst.valid_actions

	match action:
		"attack":
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
			_begin_card_mode("attack", iid, {}, target_ids, UIPalette.LIFE)

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
			var move_indices := _to_int_array(va.get("move_targets", []) as Array)
			var target_slots := _slots_from_indices(_player_zone, move_indices)
			if target_slots.is_empty():
				print("[KnightActionController] ⚠️ Sin slots válidos para mover (valid_actions)")
				return
			_reset_mode()
			_mode = "move"
			_pending_source_id = iid
			_valid_slots = move_indices
			_start_selection(target_slots, UIPalette.COSMOS)
			print("[KnightActionController] 🔄 Selecciona slot destino")


func _on_knight_option_selected(action: String, source_slot: Node, option: Dictionary) -> void:
	var card_inst: CardInstance = source_slot.card_instance if source_slot else null
	if not card_inst:
		return
	var iid := card_inst.instance_id

	match action:
		"technique":
			var technique_id := str(option.get("technique_id", ""))
			var targets := card_inst.valid_actions.get("technique_targets", []) as Array
			# Golpea a todos o no hay caballeros rivales (daño directo): no se pide objetivo
			if option.get("target_all", false) or targets.is_empty():
				print("[KnightActionController] ✨ %s usa %s" % [iid, option.get("name", "")])
				MatchSessionService.send_technique_attack(iid, technique_id, "")
				return
			_begin_card_mode("technique", iid, option, targets, UIPalette.POWER)

		"ability":
			var ability_name := str(option.get("ability_name", ""))
			if not option.get("requires_target", false):
				print("[KnightActionController] 🔮 %s usa %s" % [iid, ability_name])
				MatchSessionService.send_use_ability(iid, ability_name)
				return
			# El objetivo lo valida el servidor: se ofrece cualquier caballero en campo
			_begin_card_mode("ability_target", iid, option, _all_field_knight_ids(), UIPalette.ABILITY)


func _begin_card_mode(mode: String, source_id: String, option: Dictionary, target_ids: Array, color: Color) -> void:
	_reset_mode()
	var target_slots := _slots_from_ids(_opponent_zone, target_ids) + _slots_from_ids(_player_zone, target_ids)
	if target_slots.is_empty():
		print("[KnightActionController] ⚠️ No se encontraron slots para los objetivos")
		return
	_mode = mode
	_pending_source_id = source_id
	_pending_option = option
	_valid_target_ids = target_ids
	_start_selection(target_slots, color)
	print("[KnightActionController] 🎯 Selecciona objetivo (%s)" % mode)


# ============================================================================
# SELECCIONES DEL SERVIDOR (pending_selection)
# ============================================================================

func _start_server_slot_selection(gs: GameState, sel: Dictionary) -> void:
	"""zone "field_slot": elegir una posición del campo de slot_owner."""
	var owner_number := int(sel.get("slot_owner", gs.player_number))
	var owner := "player" if owner_number == gs.player_number else "opponent"
	var zone := _player_zone if owner == "player" else _opponent_zone
	var slots := _to_int_array(sel.get("visible_slots", []) as Array)
	_mode = "server_slot"
	_valid_slot_owner = owner
	_valid_slots = slots
	_start_selection(_slots_from_indices(zone, slots), UIPalette.TARGET)
	print("[KnightActionController] 📍 Elige una posición (%s)" % owner)


func _start_server_card_selection(gs: GameState, sel: Dictionary) -> void:
	"""Selección de carta: en el campo se resaltan los slots; fuera del campo
	(mano, mazo, yomotsu) se muestra una lista para elegir."""
	var ids := sel.get("visible_card_ids", []) as Array
	_mode = "server_card"
	_valid_target_ids = ids
	var field_slots := _slots_from_ids(_opponent_zone, ids) + _slots_from_ids(_player_zone, ids)
	if not field_slots.is_empty() and field_slots.size() == ids.size():
		_start_selection(field_slots, UIPalette.TARGET)
		print("[KnightActionController] 🎯 Elige una carta del campo")
		return
	_open_choice_panel(gs, ids)


func _open_choice_panel(gs: GameState, ids: Array) -> void:
	_close_choice_panel()
	_choice_panel = PanelContainer.new()
	_choice_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var vbox := VBoxContainer.new()
	_choice_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Elige una carta"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	if ids.is_empty():
		var empty := Label.new()
		empty.text = "No hay cartas para elegir"
		vbox.add_child(empty)

	for raw_id in ids:
		var card_id := str(raw_id)
		var button := Button.new()
		button.custom_minimum_size.y = 36
		button.text = _card_label(gs, card_id)
		button.pressed.connect(_on_choice_pressed.bind(card_id))
		vbox.add_child(button)

	_parent_node.add_child(_choice_panel)
	_choice_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	print("[KnightActionController] 📋 Elige una carta de la lista (%d opciones)" % ids.size())


func _close_choice_panel() -> void:
	if _choice_panel and is_instance_valid(_choice_panel):
		_choice_panel.queue_free()
	_choice_panel = null


func _on_choice_pressed(card_id: String) -> void:
	_reset_mode()
	_answer_selection(card_id, -1)


func _card_label(gs: GameState, card_id: String) -> String:
	var card: CardInstance = gs.get_card_by_instance_id(card_id) if gs else null
	if not card and gs and gs.cards_by_id.has(card_id):
		card = gs.cards_by_id[card_id]
	if card and card.base_data and card.base_data.name != "":
		return card.base_data.name
	return "Carta %s" % card_id.substr(0, 8)


# ============================================================================
# JUGAR CARTAS
# ============================================================================

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
