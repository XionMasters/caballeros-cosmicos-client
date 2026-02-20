# CardCollection.gd
extends Control
class_name CardCollection

## -------------------------------------------------------------------
## CardCollection (Clase base abstracta)
##
## - Administra una colección de NODOS VISUALES de cartas.
## - SOLO maneja UI y estructura visual.
## - NO maneja CardData ni información lógica del juego.
## - NO define cómo ordenar las cartas (eso lo hacen los hijos).
##
## Uso típico:
##     HandLayout       -> muestra cartas visibles en abanico.
##     DeckLayout       -> muestra cartas ocultas (CardBack) en stack.
##     DiscardLayout    -> muestra la carta superior.
##
## Responsibilities:
##  ✔ agregar/quitar nodos de carta
##  ✔ emitir señales
##  ✔ llamar a _update_layout() cuando algo cambia
##  ✘ no posiciona cartas
##  ✘ no conoce el "estado de juego"
## -------------------------------------------------------------------

signal card_added(card_node)
signal card_removed(card_node)
signal layout_changed()

## Lista interna de nodos que representan cartas.
## Estos nodos pueden ser CardDisplay, CardBack, etc.
var _cards: Array[Node] = []


# --------------------------------------------------------------------
# MÉTODOS PÚBLICOS
# --------------------------------------------------------------------

func add_card(card_node: Node) -> void:
	"""
	Agrega un nodo de carta a la colección visual.
	"""

	# ⚠️ DEFENSIVE: Si el nodo ya tiene parent, reparentearlo primero
	# Usar reparent() que es más seguro que remove_child + add_child
	if card_node.get_parent() != null:
		card_node.reparent(self)
	else:
		# Nuevo nodo, simplemente agregarlo
		add_child(card_node)

	# Ahora sí, check si ya está en _cards
	if card_node in _cards:
		return

	_cards.append(card_node)

	emit_signal("card_added", card_node)
	_update_layout()  # los hijos ordenan


func remove_card(card_node: Node) -> void:
	"""
	Quita una carta de la colección visual.
	"""
	if card_node not in _cards:
		return

	_cards.erase(card_node)
	remove_child(card_node)

	emit_signal("card_removed", card_node)
	_update_layout()


func clear_cards() -> void:
	"""
	Elimina todas las cartas mostradas.
	"""
	for card in _cards:
		remove_child(card)
	_cards.clear()

	_update_layout()


func get_cards() -> Array:
	"""
	Retorna la lista visual de cartas.
	NO contiene información lógica.
	"""
	return _cards


# --------------------------------------------------------------------
# MÉTODOS PROTEGIDOS (override para layouts)
# --------------------------------------------------------------------

func _update_layout() -> void:
	"""
	Template method.
	Es llamado cada vez que cambian las cartas.
	Las subclases deben sobreescribirlo para definir cómo se acomodan.
	"""
	emit_signal("layout_changed")
