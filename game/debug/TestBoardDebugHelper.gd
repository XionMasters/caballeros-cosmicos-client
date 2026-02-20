# TestBoard Interactivity Debug Helper
extends Node
class_name TestBoardDebugHelper

# ============================================================================
# DEBUGGING TOOLS para verificar interactividad
# ============================================================================

"""
Script de DEBUG para verificar que las cartas en TestBoard son interactuables

Uso:
1. Agregar este script como nodo hijo de TestBoard
2. Ejecutar TestBoard
3. Ver logs en consola para debugging

Verifica:
✅ CardDisplay creadas correctamente
✅ CardInstance meta guardada
✅ Eventos conectados
✅ MatchPlayController funcionando
✅ Drag/Drop eventos disparan
"""

var test_board: Control = null
var total_cards_rendered: int = 0
var cards_with_events: int = 0


func _ready() -> void:
	test_board = get_parent()
	
	# Esperar a que TestBoard esté listo
	await get_tree().process_frame
	
	# Dar tiempo a MatchPlayController para conectar
	await get_tree().create_timer(1.0).timeout
	
	_run_diagnostics()


# ============================================================================
# DIAGNOSTICS
# ============================================================================

func _run_diagnostics() -> void:
	"""Ejecutar diagnósticos de interactividad"""
	print("\n" + "=*70")
	print("🔍 TESTBOARD INTERACTIVITY DIAGNOSTICS")
	print("=*70" + "\n")
	
	_check_game_state()
	_check_board_renderer()
	_check_card_displays()
	_check_match_play_controller()
	_check_event_connections()
	
	print("\n" + "=*70")
	print("✅ DIAGNOSTICS COMPLETE")
	print("=*70" + "\n")


func _check_game_state() -> void:
	"""Verificar que GameState existe"""
	print("[GameState]")
	if test_board.game_state:
		print("  ✅ GameState creado")
		print("     - Player: %d" % test_board.game_state.player_number)
		print("     - Hand: %d cartas" % test_board.game_state.player_hand.size())
		print("     - Turn: %d" % test_board.game_state.current_turn)
	else:
		print("  ❌ GameState no existe")


func _check_board_renderer() -> void:
	"""Verificar que BoardRenderer existe"""
	print("\n[BoardRenderer]")
	if test_board.board_renderer:
		print("  ✅ BoardRenderer creado")
	else:
		print("  ❌ BoardRenderer no existe")


func _check_card_displays() -> void:
	"""Contar CardDisplay creadas y verificar meta"""
	print("\n[CardDisplay]")
	
	var all_cards = []
	var cards_without_instance = 0
	
	# Recolectar cartas de todas las zonas
	if test_board.player_hand:
		all_cards += test_board.player_hand.get_cards()
	
	for slot in test_board.player_knight_slots:
		if slot and slot.has_method("get_card"):
			var card = slot.get_card()
			if card:
				all_cards.append(card)
	
	for slot in test_board.player_tech_slots:
		if slot and slot.has_method("get_card"):
			var card = slot.get_card()
			if card:
				all_cards.append(card)
	
	if test_board.player_helper_slot and test_board.player_helper_slot.has_method("get_card"):
		var card = test_board.player_helper_slot.get_card()
		if card:
			all_cards.append(card)
	
	total_cards_rendered = all_cards.size()
	
	print("  Total CardDisplay: %d" % total_cards_rendered)
	
	if total_cards_rendered == 0:
		print("  ❌ NO CARDS RENDERED!")
		return
	
	# Verificar CardInstance meta
	for card in all_cards:
		if card is CardDisplay:
			if card.has_meta("card_instance"):
				print("  ✅ %s: meta OK" % card.card_data.name)
			else:
				print("  ⚠️  %s: NO INSTANCE META!" % card.card_data.name)
				cards_without_instance += 1
	
	if cards_without_instance > 0:
		print("\n  ⚠️  %d cartas sin instance meta (problema potencial)" % cards_without_instance)


func _check_match_play_controller() -> void:
	"""Verificar que MatchPlayController existe"""
	print("\n[MatchPlayController]")
	
	if test_board.match_play_controller:
		print("  ✅ MatchPlayController creado")
		print("     - Board Renderer: %s" % ("OK" if test_board.match_play_controller.board_renderer else "❌"))
		print("     - Game State: %s" % ("OK" if test_board.match_play_controller.game_state else "❌"))
	else:
		print("  ❌ MatchPlayController NO existe - PROBLEMA CRÍTICO")


func _check_event_connections() -> void:
	"""Verificar que eventos están conectados"""
	print("\n[Event Connections]")
	
	if not test_board.match_play_controller:
		print("  ❌ Salteado (no hay MatchPlayController)")
		return
	
	var card_displays = []
	
	if test_board.player_hand:
		card_displays += test_board.player_hand.get_cards()
	
	if card_displays.size() == 0:
		print("  ❌ No hay cartas en mano para verificar")
		return
	
	var sample_card = card_displays[0]
	
	if sample_card is CardDisplay:
		var has_drag_started = sample_card.is_connected("drag_started", Callable(test_board.match_play_controller, "_on_card_drag_started"))
		var has_drag_ended = sample_card.is_connected("drag_ended", Callable(test_board.match_play_controller, "_on_card_drag_ended"))
		var has_clicked = sample_card.is_connected("card_clicked", Callable(test_board.match_play_controller, "_on_card_clicked"))
		
		print("  Verificando conexiones en: %s" % sample_card.card_data.name)
		print("    - drag_started: %s" % ("✅" if has_drag_started else "❌"))
		print("    - drag_ended: %s" % ("✅" if has_drag_ended else "❌"))
		print("    - card_clicked: %s" % ("✅" if has_clicked else "❌"))
		
		if not (has_drag_started and has_drag_ended and has_clicked):
			print("\n  ⚠️  EVENTOS NO CONECTADOS - ¡ESTO ES UN PROBLEMA!")
			print("     Las cartas no serán interactuables!")


# ============================================================================
# MANUAL TESTING
# ============================================================================

func _input(event: InputEvent) -> void:
	"""Escuchar teclas para testing manual"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_D:
				# Presionar 'D' para ver diagnostics
				if event.key_label == KEY_D:
					_run_diagnostics()
			
			KEY_T:
				# Presionar 'T' para simular card drag
				if event.key_label == KEY_T:
					_simulate_card_drag()
			
			KEY_P:
				# Presionar 'P' para imprimir estado
				if event.key_label == KEY_P:
					_print_current_state()


func _simulate_card_drag() -> void:
	"""Simular arrastre de carta (para debugging)"""
	print("\n[Manual Simulation]")
	print("Simulando arrastre de carta...")
	
	if test_board.player_hand:
		var cards = test_board.player_hand.get_cards()
		if cards.size() > 0:
			var first_card = cards[0]
			if first_card is CardDisplay:
				print("Emitiendo drag_started para: %s" % first_card.card_data.name)
				first_card.drag_started.emit(first_card.card_data)
				
				await get_tree().create_timer(0.5).timeout
				
				print("Emitiendo drag_ended para: %s" % first_card.card_data.name)
				first_card.drag_ended.emit(first_card.card_data)
		else:
			print("❌ No hay cartas en mano")
	else:
		print("❌ player_hand no existe")


func _print_current_state() -> void:
	"""Imprimir estado actual de la partida"""
	print("\n[Current Game State]")
	
	if test_board.game_state:
		var gs = test_board.game_state
		print("  Turn: %d" % gs.current_turn)
		print("  Player: %d (Active: %d)" % [gs.player_number, gs.active_player_number])
		print("  Phase: %s" % gs.current_phase)
		print("  Hand: %d cartas" % gs.player_hand.size())
		print("  Can interact: %s" % ("✅ YES" if gs.active_player_number == gs.player_number else "❌ NO"))
	else:
		print("  ❌ No GameState")


# ============================================================================
# KEYBOARD SHORTCUTS
# ============================================================================

func print_help() -> void:
	"""Imprimir atajos de teclado"""
	print("""
	
	🎮 TESTBOARD DEBUG SHORTCUTS
	
	D - Run full diagnostics
	T - Simulate card drag
	P - Print current game state
	
	""")
