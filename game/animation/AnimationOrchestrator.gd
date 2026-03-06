# AnimationOrchestrator.gd
# Coordinador central de la capa de animaciones.
#
# Visual Lockstep Queue:
#   Cuando llegan dos GameStates rapidos del servidor, el segundo espera a que
#   terminen las animaciones del primero antes de arrancar. Garantiza que
#   la UI nunca se desincroniza del servidor.

class_name AnimationOrchestrator
extends Node

# ============================================================================
# SENALES
# ============================================================================
## Emitida cuando termina la ejecucion completa de la cola.
## Lockstep: render_state espera esta senal si ya hay animaciones en curso.
signal playback_finished

# ============================================================================
# REFERENCIAS
# ============================================================================
var _ctx: AnimationContext
var _queue: AnimationQueue

## True cuando el próximo render debe ser InitialDraw (inicio o cambio de perspectiva)
var _force_initial: bool = true

## True si actualmente hay una animacion ejecutandose
var _is_playing: bool = false

# ============================================================================
# SETUP
# ============================================================================

func setup(
	player_hand: PlayerHandController,
	opponent_hand: OpponentHandController,
	field: FieldRenderer,
	status: StatusPanelController,
	effects: MatchEffectsManager
) -> void:
	_ctx = AnimationContext.new(
		player_hand,
		opponent_hand,
		field,
		status,
		effects,
		self
	)
	_queue = AnimationQueue.new()
	print("[AnimationOrchestrator] Listo")


func reset_state() -> void:
	_force_initial = true
	print("[AnimationOrchestrator] Estado anterior reseteado")


# ============================================================================
# PUNTO DE ENTRADA PRINCIPAL
# ============================================================================

func render_state(gs: GameState, match_data: Dictionary) -> void:
	if not _ctx:
		push_error("[AnimationOrchestrator] Llamar setup() antes de render_state()")
		return

	# LOCKSTEP: si ya hay animaciones corriendo, esperar antes de continuar
	if _is_playing:
		print("[AnimationOrchestrator] Esperando animaciones previas (lockstep)...")
		await playback_finished

	# 1. Diff usando el snapshot capturado ANTES de apply_update (evita el problema
	#    de referencias mutables compartidas entre prev y next state).
	#    Si _force_initial=true, pasamos {} para forzar InitialDraw.
	var prev_snap: Dictionary = {} if _force_initial else gs.previous_snapshot
	var diff_events: Array = StateDiffer.compute(prev_snap, gs)
	print("[AnimationOrchestrator] %d evento(s) detectados" % diff_events.size())

	# 2. Construir cola (el Orchestrator decide el agrupado y el orden)
	_build_queue(diff_events, gs, match_data)

	# 3. Ejecutar y marcar que ya no necesitamos initial draw
	_force_initial = false
	await _flush_queue()


# ============================================================================
# CONSTRUCCION DE LA COLA
# ============================================================================

func _build_queue(diff_events: Array, gs: GameState, cm: Dictionary) -> void:
	_queue.clear()

	# 1. Status siempre primero (sincrono, no bloquea)
	_queue.add(UpdateStatusEvent.new(gs, cm))

	# 2. Separar por tipo para controlar el orden visual
	var attacks: Array = diff_events.filter(func(e): return e is AttackEvent)
	var draws: Array   = diff_events.filter(func(e): return e is DrawCardsEvent or e is DrawOpponentCardsEvent)
	var others: Array  = diff_events.filter(func(e): return not (e is AttackEvent or e is DrawCardsEvent or e is DrawOpponentCardsEvent))

	# Orden: Ataques → Robo de cartas → Resto
	# (primero se ve el golpe, luego llegan las nuevas cartas a la mano)
	for e in attacks:
		_queue.add(e)

	# Draws: paralelo si hay jugador Y oponente a la vez, secuencial si solo uno
	if draws.size() > 1:
		_queue.add_parallel(draws)
	elif draws.size() == 1:
		_queue.add(draws[0])

	# Otros eventos en orden
	for e in others:
		_queue.add(e)

	# 3. Field siempre al final (despues de que las cartas llegaron a la mano)
	_queue.add(RenderFieldEvent.new(gs))


# ============================================================================
# EJECUCION INTERNA
# ============================================================================

func _flush_queue() -> void:
	_is_playing = true
	await _queue.run(_ctx)
	_is_playing = false
	playback_finished.emit()


# ============================================================================
# API DE ALTO NIVEL PARA ANIMACIONES DE COMBATE
# ============================================================================

func play_attack(attacker_is_opponent: bool, attacker_slot: int, defender_is_opponent: bool, defender_slot: int, damage: int, last_action: Dictionary = {}) -> void:
	var event := AttackEvent.new(attacker_is_opponent, attacker_slot, defender_is_opponent, defender_slot, damage, last_action)

	if _is_playing:
		# Agregar al final de la cola actual - se ejecutara en el proximo flush
		_queue.add(event)
	else:
		# No hay nada corriendo: ejecutar inmediatamente via run_single
		_is_playing = true
		await _queue.run_single(event, _ctx)
		_is_playing = false
		playback_finished.emit()
