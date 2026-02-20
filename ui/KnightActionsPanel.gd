# KnightActionsPanel.gd
# Panel de acciones disponibles para caballeros en el campo
extends Control

signal action_selected(action: String, target_slot: Node)

var actions_container: VBoxContainer = null
var title_label: Label = null
var close_button: Button = null

# Acciones disponibles según documentación
const KNIGHT_ACTIONS = {
	"attack": {"name": "Batalhar (BA)", "icon": "⚔️", "desc": "Ataque básico sin técnica"},
	"technique": {"name": "Técnica (TA)", "icon": "✨", "desc": "Usar técnica activada"},
	"charge": {"name": "Carregar Cosmo", "icon": "💫", "desc": "Recupera 3 CP"},
	"sacrifice": {"name": "Sacrificar", "icon": "💀", "desc": "Elimina caballero (-1 LP)"},
	"evade": {"name": "Modo Evasão", "icon": "🌀", "desc": "50% evadir ataques BA"},
	"move": {"name": "Movimentar", "icon": "🔄", "desc": "Mover a espacio vacío"},
	"block": {"name": "Modo Defesa", "icon": "🛡️", "desc": "Reduce daño a la mitad"},
	"pray": {"name": "Oração Divina", "icon": "🙏", "desc": "Habilidad especial"}
}

var selected_knight_slot: Node = null

func _ready():
	# Crear estructura si no existe
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	"""Mostrar acciones disponibles para un caballero"""
	selected_knight_slot = knight_slot
	
	# Limpiar acciones previas
	for child in actions_container.get_children():
		if child != title_label and child != close_button:
			child.queue_free()
	
	title_label.text = "Acciones de Caballero"
	
	# Crear botón para cada acción
	for action_key in KNIGHT_ACTIONS.keys():
		var action_data = KNIGHT_ACTIONS[action_key]
		var button = Button.new()
		button.custom_minimum_size.y = 40
		button.text = "%s %s" % [action_data.icon, action_data.name]
		button.tooltip_text = action_data.desc
		button.pressed.connect(_on_action_button_pressed.bind(action_key))
		
		actions_container.add_child(button)
	
	# Posicionar cerca del caballero seleccionado
	position = knight_slot.global_position + Vector2(100, -200)
	show()

func _on_action_button_pressed(action: String):
	"""Ejecutar acción seleccionada"""
	print("🎮 Acción seleccionada: ", action)
	
	match action:
		"attack":
			_start_attack_mode()
		"technique":
			_start_technique_mode()
		"charge":
			_execute_charge()
		"sacrifice":
			_execute_sacrifice()
		"evade":
			_execute_evade()
		"move":
			_start_move_mode()
		"block":
			_execute_block()
		"pray":
			_execute_pray()
	
	hide()

func _start_attack_mode():
	"""Modo selección de objetivo para ataque"""
	print("⚔️ Selecciona objetivo de ataque")
	action_selected.emit("attack", selected_knight_slot)

func _start_technique_mode():
	"""Modo selección de técnica"""
	print("✨ Selecciona técnica a usar")
	action_selected.emit("technique", selected_knight_slot)

func _execute_charge():
	"""Ejecutar carga de cosmos"""
	action_selected.emit("charge", selected_knight_slot)

func _execute_sacrifice():
	"""Ejecutar sacrificio de caballero"""
	action_selected.emit("sacrifice", selected_knight_slot)

func _execute_evade():
	"""Activar modo evasión"""
	action_selected.emit("evade", selected_knight_slot)

func _start_move_mode():
	"""Modo selección de destino para mover"""
	print("🔄 Selecciona espacio vacío para mover")
	action_selected.emit("move", selected_knight_slot)

func _execute_block():
	"""Activar modo bloqueo"""
	action_selected.emit("block", selected_knight_slot)

func _execute_pray():
	"""Ejecutar oración divina"""
	action_selected.emit("pray", selected_knight_slot)

func _on_close_pressed():
	hide()
