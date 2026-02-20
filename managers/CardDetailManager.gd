# CardDetailManager.gd
# Manager singleton para mostrar detalles de cartas desde cualquier escena
extends Node

var detail_view_scene = preload("res://cards/CardDetailView.tscn")
var current_detail_view: Control = null

func _ready():
	# Esperar a que CardsManager esté listo para acceder a su caché
	pass

func show_card(card: CardData, texture: ImageTexture = null, show_add_to_deck: bool = false):
	"""Muestra el detalle de una carta
	
	Args:
		card: Datos de la carta a mostrar
		texture: Textura opcional (si está en caché)
		show_add_to_deck: Si debe mostrar el botón "Agregar al Deck"
	"""
	# Crear la vista si no existe
	if not current_detail_view:
		current_detail_view = detail_view_scene.instantiate()
		current_detail_view.z_index = 1000  # Siempre encima de todo
	
	# Si no está en el árbol, agregarla a la escena actual
	if not current_detail_view.is_inside_tree():
		var root = get_tree().current_scene
		if root:
			root.add_child(current_detail_view)
	
	# Intentar obtener la textura del caché si no se proporcionó
	if texture == null and card.image_url != "":
		# Verificar si está en el caché de CardsManager
		var cache = CardsManager._image_cache
		if cache.has(card.id):
			texture = cache[card.id]
	
	# Mostrar la carta (con o sin textura)
	current_detail_view.show_card(card, texture, show_add_to_deck)

func hide_detail():
	"""Oculta la vista de detalle"""
	if current_detail_view and current_detail_view.is_inside_tree():
		current_detail_view.hide()
