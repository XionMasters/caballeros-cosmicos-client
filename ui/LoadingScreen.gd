# LoadingScreen.gd
# Pantalla modal de carga con progreso
extends CanvasLayer

var modal_control: Control = null
var overlay: ColorRect = null
var vbox: VBoxContainer = null
var loading_label: Label = null
var progress_bar: ProgressBar = null
var progress_text: Label = null
var spinner: Label = null

var current_loaded: int = 0
var total_to_load: int = 0
var is_complete: bool = false
var pending_title: String = "Cargando colección..."


func _ready() -> void:
	# Configurar CanvasLayer para que esté encima
	layer = 100
	
	# Crear overlay oscuro de fondo
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.anchor_left = 0.0
	overlay.anchor_top = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	add_child(overlay)
	
	# Crear control modal centrado
	modal_control = Control.new()
	modal_control.anchor_left = 0.5
	modal_control.anchor_top = 0.5
	modal_control.anchor_right = 0.5
	modal_control.anchor_bottom = 0.5
	modal_control.offset_left = -200
	modal_control.offset_top = -120
	modal_control.custom_minimum_size = Vector2(400, 240)
	add_child(modal_control)
	
	# Panel de fondo para el contenido
	var panel = PanelContainer.new()
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.add_theme_stylebox_override("panel", _create_panel_stylebox())
	modal_control.add_child(panel)
	
	# VBoxContainer para contenido
	vbox = VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)
	
	# Spinner
	spinner = Label.new()
	spinner.text = "⟳"
	spinner.add_theme_font_size_override("font_size", 48)
	spinner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(spinner)
	
	# Loading label
	loading_label = Label.new()
	loading_label.text = pending_title
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(loading_label)
	
	# Progress bar
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(350, 20)
	progress_bar.value = 0
	vbox.add_child(progress_bar)
	
	# Progress text
	progress_text = Label.new()
	progress_text.text = "0 / 0 (0%)"
	progress_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_text.add_theme_font_size_override("font_size", 12)
	vbox.add_child(progress_text)
	
	# Conectar a signals del CardsManager
	if has_node("/root/CardsManager"):
		var cards_manager = get_node("/root/CardsManager")
		if cards_manager.has_signal("collection_loading_progress"):
			cards_manager.collection_loading_progress.connect(_on_loading_progress)
			print("[LoadingScreen] ✓ Conectado a collection_loading_progress")
		if cards_manager.has_signal("collection_images_preloaded"):
			cards_manager.collection_images_preloaded.connect(_on_loading_complete)
			print("[LoadingScreen] ✓ Conectado a collection_images_preloaded")
	else:
		print("[LoadingScreen] ✗ CardsManager no encontrado")
	
	# Animación de spinner
	_animate_spinner()


func _create_panel_stylebox() -> StyleBox:
	"""Crear StyleBox para el panel modal"""
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.15, 0.15, 0.15, 1.0)
	stylebox.set_corner_radius_all(10)
	stylebox.set_content_margin_all(20)
	return stylebox


func _animate_spinner() -> void:
	"""Rotar el spinner continuamente"""
	var tween = create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(spinner, "rotation_degrees", 360, 2.0)


func _on_loading_progress(loaded: int, total: int) -> void:
	"""Callback de progreso"""
	current_loaded = loaded
	total_to_load = total
	
	if total_to_load > 0:
		var percent = float(current_loaded) / float(total_to_load) * 100.0
		progress_bar.value = percent
		progress_text.text = "%d / %d (%.0f%%)" % [current_loaded, total_to_load, percent]


func _on_loading_complete() -> void:
	"""Callback cuando termina la carga"""
	is_complete = true
	progress_bar.value = 100.0
	progress_text.text = "✅ ¡Listo!"
	loading_label.text = "Colección cargada"
	spinner.text = "✓"
	
	# Esperar un poco y cerrar
	await get_tree().create_timer(0.8).timeout
	queue_free()


func set_title(title: String) -> void:
	"""Establecer título de la pantalla"""
	pending_title = title
	if loading_label:
		loading_label.text = title
