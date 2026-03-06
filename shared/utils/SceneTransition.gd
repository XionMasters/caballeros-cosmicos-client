# SceneTransition.gd
# Singleton para manejar transiciones entre escenas y pasar datos
extends Node

# ============================================================================
# ALMACENAMIENTO TEMPORAL DE DATOS
# ============================================================================
var pending_deck_data: Dictionary = {}
var pending_data: Dictionary = {}  # Datos genéricos para cualquier escena

# ============================================================================
# RUTAS DE ESCENAS (Mapeo centralizado)
# ============================================================================
var scene_paths = {
	"mainlobby": "res://menus/lobby/MainLobby.tscn",
	"mycards": "res://menus/cards/CardsCollection.tscn",
	"profile": "res://menus/profile/ProfileScene.tscn",
	"matchsearch": "res://menus/matchsearch/MatchSearch.tscn",
	"shop": "res://menus/shop/PacksShop.tscn",
	"decks": "res://menus/decks/DecksList.tscn",

	"deck_builder": "res://menus/deckbuilder/DeckBuilder.tscn",
	"game": "res://game/board/GameBoard.tscn",
	"gamematch": "res://game/match/GameMatch.tscn",
	"login": "res://menus/login/LoginScreen.tscn",
	"battle_summary": "res://menus/battle_summary/BattleSummary.tscn",
}

# ============================================================================
# TRANSICIONES ESPECÍFICAS (Con datos)
# ============================================================================
func go_to_mainlobby():
	_change_scene("mainlobby")

func go_to_mycards():
	_change_scene("mycards")

func go_to_profile():
	_change_scene("profile")

func go_to_shop():
	_change_scene("shop")

func go_to_decks():
	_change_scene("decks")

func go_to_deck_builder(deck: Dictionary):
	"""Ir al editor de mazos con un deck específico"""
	pending_deck_data = deck
	_change_scene("deck_builder")

func go_to_gamematch():
	"""Volver al tablero de juego"""
	_change_scene("gamematch")

func go_to_login():
	"""Ir a la pantalla de login"""
	_change_scene("login")

func go_to_battle_summary():
	"""Ir a la pantalla de resumen de partida"""
	_change_scene("battle_summary")

# ============================================================================
# TRANSICIONES GENÉRICAS (Sin datos)
# ============================================================================
func change_scene(scene_name: String):
	"""Cambiar a una escena por nombre (desde scene_paths)"""
	if not scene_paths.has(scene_name):
		push_error("[SceneTransition] Escena '%s' no encontrada en mapeo" % scene_name)
		return
	_change_scene(scene_name)

func change_scene_to_path(scene_path: String):
	"""Cambiar a una escena usando ruta directa"""
	_change_scene_to_file(scene_path)

# ============================================================================
# MANEJO DE DATOS GENÉRICOS
# ============================================================================
func set_pending_data(data: Dictionary):
	"""Guardar datos temporales para la siguiente escena"""
	pending_data = data

func get_pending_data() -> Dictionary:
	"""Obtener datos temporales y limpiar"""
	var data = pending_data.duplicate()
	pending_data.clear()
	return data

func has_pending_data() -> bool:
	"""Verificar si hay datos temporales"""
	return not pending_data.is_empty()

# ============================================================================
# MANEJO DE DECK ESPECÍFICO (Legacy)
# ============================================================================
func get_pending_deck() -> Dictionary:
	"""Obtener el deck pendiente y limpiar"""
	var deck = pending_deck_data.duplicate()
	pending_deck_data.clear()
	return deck

func has_pending_deck() -> bool:
	"""Verificar si hay un deck pendiente"""
	return not pending_deck_data.is_empty()

# ============================================================================
# IMPLEMENTACIÓN INTERNA
# ============================================================================
func _change_scene(scene_name: String):
	"""Cambiar de escena usando nombre mapeado"""
	if not scene_paths.has(scene_name):
		push_error("[SceneTransition] Escena '%s' no existe en mapeo" % scene_name)
		return
	_change_scene_to_file(scene_paths[scene_name])

func _change_scene_to_file(scene_path: String):
	"""Ejecutar cambio de escena (punto central)"""
	print("[SceneTransition] 🔄 Cambiando a: %s" % scene_path)
	var error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("[SceneTransition] Error al cambiar escena: %s" % scene_path)
