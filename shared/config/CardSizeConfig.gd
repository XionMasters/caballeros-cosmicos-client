# CardSizeConfig.gd
# Configuración centralizada de tamaños de cartas
# Autoload/Singleton - UNA SOLA FUENTE DE VERDAD para todo el juego
extends Node

# ============================================================================
# TAMAÑOS BASE (puedes ajustar estos valores)
# ============================================================================

## Ancho de la carta en píxeles (base)
var card_width: float = 107.0

## Alto de la carta en píxeles (base)
var card_height: float = 140.0

## Aspect ratio para referencia
var card_aspect_ratio: float  # Se calcula en _ready()

# ============================================================================
# ESCALAS PARA DIFERENTES CONTEXTOS
# ============================================================================

## Escala en mano (normal)
var hand_card_scale: float = 1.0

## Escala en mazo/pila
var deck_card_scale: float = 1.0

## Escala en hover (mano)
var hand_card_hover_scale: float = 1.1

## Escala en detail view (doble clic)
var detail_view_scale: float = 2.0

# ============================================================================
# CACHED SIZES (para evitar recalcular)
# ============================================================================

var _hand_card_size: Vector2
var _deck_card_size: Vector2
var _hover_card_size: Vector2
var _detail_card_size: Vector2

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	"""Calcular aspect ratio y cachear tamaños"""
	card_aspect_ratio = card_width / card_height
	_recalculate_sizes()
	print("✅ CardSizeConfig inicializado: %.0fx%.0f (aspect %.2f)" % [card_width, card_height, card_aspect_ratio])

func _recalculate_sizes() -> void:
	"""Recalcular todos los tamaños cacheados"""
	_hand_card_size = Vector2(card_width * hand_card_scale, card_height * hand_card_scale)
	_deck_card_size = Vector2(card_width * deck_card_scale, card_height * deck_card_scale)
	_hover_card_size = Vector2(card_width * hand_card_hover_scale, card_height * hand_card_hover_scale)
	_detail_card_size = Vector2(card_width * detail_view_scale, card_height * detail_view_scale)

# ============================================================================
# PUBLIC API
# ============================================================================

func get_card_size(scale: float = 1.0) -> Vector2:
	"""Retorna el tamaño de una carta con escala opcional"""
	return Vector2(card_width * scale, card_height * scale)

func get_hand_card_size() -> Vector2:
	"""Tamaño de carta en mano"""
	return _hand_card_size

func get_deck_card_size() -> Vector2:
	"""Tamaño de carta en pila/mazo"""
	return _deck_card_size

func get_hover_card_size() -> Vector2:
	"""Tamaño de carta en hover (mano)"""
	return _hover_card_size

func get_detail_view_size() -> Vector2:
	"""Tamaño de carta en vista de detalle"""
	return _detail_card_size
