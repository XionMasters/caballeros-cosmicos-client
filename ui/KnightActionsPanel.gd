# KnightActionsPanel.gd
# Panel de acciones disponibles para caballeros en el campo.
# Solo muestra lo que el servidor permite (valid_actions): el cliente nunca calcula reglas.
extends Control

signal action_selected(action: String, target_slot: Node)
## Acciones con opción concreta: "technique" (option = técnica de valid_actions.techniques)
## y "ability" (option = habilidad de valid_actions.active_abilities)
signal option_selected(action: String, target_slot: Node, option: Dictionary)

var actions_container: VBoxContainer = null
var title_label: Label = null
var close_button: Button = null

# Acciones simples: clave → (flag de valid_actions que la habilita, texto, descripción)
const KNIGHT_ACTIONS = {
	"attack": {"flag": "can_attack", "name": "Ataque básico (BA)", "icon": "⚔️", "desc": "Ataque básico sin técnica"},
	"charge": {"flag": "can_charge", "name": "Cargar Cosmo", "icon": "💫", "desc": "Recupera CP"},
	"evade": {"flag": "can_evade", "name": "Modo Evasión", "icon": "🌀", "desc": "50% de evadir ataques BA"},
	"block": {"flag": "can_defend", "name": "Modo Defensa", "icon": "🛡️", "desc": "Reduce el daño de los BA a la mitad"},
	"move": {"flag": "can_move", "name": "Mover", "icon": "🔄", "desc": "Mover a un espacio vacío adyacente"},
	"sacrifice": {"flag": "can_sacrifice", "name": "Sacrificar", "icon": "💀", "desc": "Elimina al caballero (-1 LP)"},
}

var selected_knight_slot: Node = null

func _ready():
	# Crear estructura si no existe
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not has_node("MarginContainer/VBoxContainer"):
		var margin = MarginContainer.new()
		margin.name = "MarginContainer"
		add_child(margin)
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 10)

		var vbox = VBoxContainer.new()
		vbox.name = "VBoxContainer"
		margin.add_child(vbox)

		title_label = Label.new()
		title_label.name = "Title"
		title_label.add_theme_font_size_override("font_size", 18)
		vbox.add_child(title_label)

		close_button = Button.new()
		close_button.name = "CloseButton"
		close_button.text = "Cerrar"
		vbox.add_child(close_button)

		actions_container = vbox
	else:
		actions_container = $MarginContainer/VBoxContainer
		if has_node("MarginContainer/VBoxContainer/Title"):
			title_label = $MarginContainer/VBoxContainer/Title
		if has_node("MarginContainer/VBoxContainer/CloseButton"):
			close_button = $MarginContainer/VBoxContainer/CloseButton

	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	hide()

func show_actions_for_knight(knight_slot: Node):
	"""Mostrar las acciones que valid_actions permite a este caballero"""
	selected_knight_slot = knight_slot

	# Limpiar acciones previas
	for child in actions_container.get_children():
		if child != title_label and child != close_button:
			child.queue_free()

	var card_inst: CardInstance = knight_slot.card_instance if knight_slot else null
	var va: Dictionary = card_inst.valid_actions if card_inst else {}
	title_label.text = "Acciones de Caballero"

	if va.is_empty():
		_add_info("No es tu turno")
	elif va.get("has_acted", false) and not va.get("can_use_ability", false):
		_add_info("Este caballero ya actuó este turno")
	else:
		var added := 0
		for action_key in KNIGHT_ACTIONS.keys():
			var action_data = KNIGHT_ACTIONS[action_key]
			if not va.get(action_data.flag, false):
				continue
			if action_key == "attack" and va.get("attack_targets", null) == null:
				continue
			_add_button("%s %s" % [action_data.icon, action_data.name], action_data.desc,
				_on_action_button_pressed.bind(action_key))
			added += 1

		# Una opción por técnica utilizable
		for technique in va.get("techniques", []):
			if technique is Dictionary:
				_add_button("✨ %s (%d CP)" % [technique.get("name", "Técnica"), int(technique.get("ta_cost", 0))],
					"Técnica: golpea a todos los rivales" if technique.get("target_all", false) else "Técnica (TA)",
					_on_option_pressed.bind("technique", technique))
				added += 1

		# Una opción por habilidad activa disponible
		for ability in va.get("active_abilities", []):
			if ability is Dictionary:
				_add_button("🔮 %s (%d CP)" % [_ability_label(card_inst, ability), int(ability.get("cosmos_cost", 0))],
					"Habilidad activa", _on_option_pressed.bind("ability", ability))
				added += 1

		if added == 0:
			_add_info("Sin acciones disponibles")

	# Mantener "Cerrar" al final
	if close_button:
		actions_container.move_child(close_button, actions_container.get_child_count() - 1)

	# Posicionar cerca del caballero seleccionado
	position = knight_slot.global_position + Vector2(100, -200)
	show()

func _add_button(text: String, tooltip: String, callback: Callable) -> void:
	var button = Button.new()
	button.custom_minimum_size.y = 40
	button.text = text
	button.tooltip_text = tooltip
	button.pressed.connect(callback)
	actions_container.add_child(button)

func _add_info(text: String) -> void:
	var label = Label.new()
	label.text = text
	actions_container.add_child(label)

func _ability_label(card_inst: CardInstance, ability: Dictionary) -> String:
	"""Nombre legible de la habilidad: busca el nombre en la carta por su ability_key."""
	var key := str(ability.get("ability_name", ""))
	if card_inst and card_inst.base_data:
		for raw in card_inst.base_data.abilities:
			if raw is Dictionary and (raw.get("ability_key", "") == key):
				return str(raw.get("name", key))
	return key.replace("_", " ").capitalize()

func _on_action_button_pressed(action: String):
	"""Ejecutar acción seleccionada"""
	print("🎮 Acción seleccionada: ", action)
	action_selected.emit(action, selected_knight_slot)
	hide()

func _on_option_pressed(action: String, option: Dictionary):
	print("🎮 Opción seleccionada: %s %s" % [action, option])
	option_selected.emit(action, selected_knight_slot, option)
	hide()

func _on_close_pressed():
	hide()
