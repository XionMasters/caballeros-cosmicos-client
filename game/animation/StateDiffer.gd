# StateDiffer.gd
# Compara un estado anterior y uno nuevo de GameState y devuelve los eventos
# visuales que representen SOLO lo que cambió.
#
# Responsabilidad única: detectar diferencias. NO decide el orden final ni el
# paralelismo — eso es trabajo del AnimationOrchestrator.
#
# Reglas:
#   - NO incluye UpdateStatusEvent ni RenderFieldEvent (siempre los agrega el Orchestrator)
#   - NO recibe match_data (ese dato es del Orchestrator)
#   - prev == null  → primer render (reparto inicial)
#   - prev != null  → render incremental (sólo cambios)

class_name StateDiffer
extends RefCounted


# ============================================================================
# PUNTO DE ENTRADA
# ============================================================================
# NOTA IMPORTANTE — por qué se usa prev_snapshot en lugar de prev: GameState:
#
# GameState.apply_update() muta el estado EN PLACE antes de emitir
# match_state_updated. Para cuando render_state() corre, tanto _prev como el
# nuevo gs apuntan a los MISMOS CardInstance (misma referencia), por lo que
# cualquier comparación de HP daría 0. El snapshot se captura al INICIO de
# apply_update(), antes de cualquier mutación, y es un Dictionary simple
# con valores primitivos — sin referencias compartidas.
#
# prev_snapshot vacío ({}) → primer render (InitialDraw).
## Devuelve los eventos "interesantes" (draws, ataques, etc.) en orden cronológico.
## El Orchestrator añade siempre UpdateStatusEvent y RenderFieldEvent por su cuenta.
static func compute(prev_snapshot: Dictionary, gs: GameState) -> Array:
	if gs == null:
		push_warning("[StateDiffer] gs es null")
		return []
	if prev_snapshot.is_empty():
		return _initial_events(gs)
	return _incremental_events(prev_snapshot, gs)


# ============================================================================
# PRIMER RENDER (snapshot vacío)
# ============================================================================

static func _initial_events(gs: GameState) -> Array:
	"""Reparto inicial: siempre jugador + oponente."""
	var draw_player := DrawCardsEvent.new(gs)
	var draw_opponent := DrawOpponentCardsEvent.new(gs)
	draw_player.label = "InitialDraw:Player"
	draw_opponent.label = "InitialDraw:Opponent"
	return [draw_player, draw_opponent]


# ============================================================================
# RENDER INCREMENTAL (snapshot no vacío)
# ============================================================================

static func _incremental_events(prev: Dictionary, gs: GameState) -> Array:
	"""Detectar cambios entre el snapshot anterior y el estado actual."""
	var events: Array = []

	# 1. Acción del servidor (fuente de verdad para animaciones)
	#    Si last_action está vacío, fallback a detección por diff de HP.
	var action_events := _events_from_last_action(gs)
	if action_events.is_empty():
		action_events = _detect_attacks(prev, gs)
	events.append_array(action_events)

	# 2. Comparar conteos de mano con los del snapshot
	var prev_pl_hand: int  = prev.get("player_hand_count", 0)
	var prev_op_hand: int  = prev.get("opponent_hand_count", 0)

	# Jugador robó cartas
	if gs.player_hand.size() > prev_pl_hand:
		events.append(DrawCardsEvent.new(gs))

	# Oponente robó o jugó cartas
	if gs.opponent_hand_count != prev_op_hand:
		events.append(DrawOpponentCardsEvent.new(gs))

	# Jugador jugó carta (mano decreció) — actualizar igual para borrar visualmente
	if gs.player_hand.size() < prev_pl_hand:
		if not events.any(func(e): return e is DrawCardsEvent):
			events.append(DrawCardsEvent.new(gs))

	# Sin cambios en mano: sync de todas formas para no desincronizar
	if not events.any(func(e): return e is DrawCardsEvent or e is DrawOpponentCardsEvent):
		var s_pl := DrawCardsEvent.new(gs)
		var s_op := DrawOpponentCardsEvent.new(gs)
		s_pl.label = "SyncHand:Player"
		s_op.label = "SyncHand:Opponent"
		events.append(s_pl)
		events.append(s_op)

	return events


static func _detect_attacks(prev: Dictionary, gs: GameState) -> Array:
	"""Detectar ataques comparando HP desde el snapshot anterior.
	Defensor = quien perdió HP. Atacante = quien se agotó en el lado contrario."""
	var events: Array = []
	var pl_health:  Dictionary = prev.get("player_knight_health",    {})
	var op_health:  Dictionary = prev.get("opponent_knight_health",  {})
	var op_exhaust: Dictionary = prev.get("opponent_knight_exhausted", {})
	var pl_exhaust: Dictionary = prev.get("player_knight_exhausted",  {})

	# Caballeros del JUGADOR que recibieron daño (atacante = oponente)
	for i in range(gs.player_field_knights.size()):
		var ci: CardInstance = gs.player_field_knights[i]
		if not ci:
			continue
		var prev_hp: int = pl_health.get(ci.instance_id, ci.current_health)
		if ci.current_health < prev_hp:
			var dmg: int = prev_hp - ci.current_health
			var atk_slot: int = _find_newly_exhausted_from_map(op_exhaust, gs.opponent_field_knights)
			events.append(AttackEvent.new(true, atk_slot, false, i, dmg))

	# Caballeros del OPONENTE que recibieron daño (atacante = jugador)
	for i in range(gs.opponent_field_knights.size()):
		var ci: CardInstance = gs.opponent_field_knights[i]
		if not ci:
			continue
		var prev_hp: int = op_health.get(ci.instance_id, ci.current_health)
		if ci.current_health < prev_hp:
			var dmg: int = prev_hp - ci.current_health
			var atk_slot: int = _find_newly_exhausted_from_map(pl_exhaust, gs.player_field_knights)
			events.append(AttackEvent.new(false, atk_slot, true, i, dmg))

	return events


static func _find_newly_exhausted_from_map(prev_exhausted: Dictionary, next_knights: Array) -> int:
	"""Devuelve el slot del primer caballero que pasó de no-agotado a agotado.
	Fallback: 0."""
	for i in range(next_knights.size()):
		var ci: CardInstance = next_knights[i]
		if not ci:
			continue
		var was_exhausted: bool = prev_exhausted.get(ci.instance_id, false)
		if not was_exhausted and ci.is_exhausted:
			return i
	return 0


# ============================================================================
# EVENTOS DESDE last_action (fuente de verdad del servidor)
# ============================================================================

static func _events_from_last_action(gs: GameState) -> Array:
	"""Crear eventos de animación directamente desde last_action del servidor.
	Es la fuente authoritative: el servidor sabe exactamente qué acción ocurrió."""
	var la: Dictionary = gs.last_action
	if la.is_empty():
		return []
	var action_type: String = la.get("type", "")
	match action_type:
		"attack", "technique":
			return _attack_events_from_la(la, gs)
		_:
			return []


static func _attack_events_from_la(la: Dictionary, gs: GameState) -> Array:
	"""Resolver attacker_id + defender_id → slots en pantalla.
	Enriquece last_action con el tipo de carta del atacante para que
	AnimationRegistry pueda elegir el color/duración correcto.
	Si defender_id es null/vacío es un ataque directo al jugador — no hay slot defensor."""
	var attacker_id: String = str(la.get("attacker_id") if la.get("attacker_id") != null else "")
	var defender_id: String = str(la.get("defender_id") if la.get("defender_id") != null else "")

	if attacker_id.is_empty():
		return []

	var atk_loc: Dictionary = gs.find_card_location(attacker_id)
	if not atk_loc.get("found", false):
		return []

	var atk_is_opp: bool = (atk_loc["owner"] != gs.player_number)
	var dmg: int = la.get("damage", 0)

	# Enriquecer last_action con el tipo de carta del atacante para AnimationRegistry
	var enriched_la := la.duplicate()
	var atk_ci: CardInstance = atk_loc.get("card", null)
	if atk_ci and atk_ci.base_data:
		enriched_la["attacker_card_type"] = atk_ci.base_data.type

	# Ataque directo (sin carta defensora) — usar slot del atacante como destino visual
	if defender_id.is_empty():
		var def_is_opp_direct: bool = not atk_is_opp  # el "defensor" es el jugador contrario
		return [AttackEvent.new(atk_is_opp, atk_loc["index"], def_is_opp_direct, -1, dmg, enriched_la)]

	# Ataque a carta defensora
	var def_loc: Dictionary = gs.find_card_location(defender_id)
	if not def_loc.get("found", false):
		return []
	var def_is_opp: bool = (def_loc["owner"] != gs.player_number)
	return [AttackEvent.new(atk_is_opp, atk_loc["index"], def_is_opp, def_loc["index"], dmg, enriched_la)]

static func _field_changed(prev: GameState, next: GameState) -> bool:
	"""Detectar si alguna carta entró, salió o cambió de modo en el campo."""
	if _knight_arrays_differ(prev.player_field_knights, next.player_field_knights):
		return true
	if _knight_arrays_differ(prev.opponent_field_knights, next.opponent_field_knights):
		return true
	return false


static func _knight_arrays_differ(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return true
	for i in range(a.size()):
		var ci_a: CardInstance = a[i]
		var ci_b: CardInstance = b[i]
		if ci_a == null and ci_b == null:
			continue
		if ci_a == null or ci_b == null:
			return true
		if ci_a.instance_id != ci_b.instance_id:
			return true
		if ci_a.mode != ci_b.mode:
			return true
		if ci_a.is_exhausted != ci_b.is_exhausted:
			return true
	return false
