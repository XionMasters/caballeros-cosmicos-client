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
	effects: MatchEffectsManager,
	player_number: int = 1
) -> void:
	_ctx = AnimationContext.new(
		player_hand,
		opponent_hand,
		field,
		status,
		effects,
		self,
		player_number
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

	# 0. Actualizar perspectiva del jugador en el contexto
	if _ctx:
		_ctx.player_number_hint = gs.player_number

	# 1. Diff usando el snapshot capturado ANTES de apply_update (evita el problema
	#    de referencias mutables compartidas entre prev y next state).
	#    Si _force_initial=true, pasamos {} para forzar InitialDraw.
	var prev_snap: Dictionary = {} if _force_initial else gs.previous_snapshot
	# Pre-chequeo: ¿el servidor mandó engine_events con daño/muerte?
	var has_engine_damage: bool = gs.engine_events.any(
		func(ev): return ev.get("type","") in ["DAMAGE_DEALT","DAMAGE_LETHAL","KNIGHT_DIED","ALLY_DIED"]
	)
	var diff_events: Array = StateDiffer.compute(prev_snap, gs, has_engine_damage)
	print("[AnimationOrchestrator] %d diff evento(s) detectados" % diff_events.size())

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

	# 2. ENGINE EVENTS — fuente autoritativa del servidor.
	#    Traducimos los eventos tipados a AnimationEvents concretos.
	var engine_anim_events: Array = []
	if not gs.engine_events.is_empty():
		engine_anim_events = EngineEventTranslator.translate(gs.engine_events, gs.player_number)
		print("[AnimationOrchestrator] %d engine_events → %d anim events" % [
			gs.engine_events.size(), engine_anim_events.size()
		])

	# Tipos de events cubiertos por engine_events — el StateDiffer NO debe duplicarlos.
	var has_damage	:= engine_anim_events.any(func(e): return e is DamageEvent)
	var has_death	:= engine_anim_events.any(func(e): return e is KnightDiedEvent)
	var has_summon	:= engine_anim_events.any(func(e): return e is KnightSummonedEvent)

	# Si hay eventos de combate del motor, los ataques del StateDiffer son redundantes.
	var filtered_diff: Array
	if has_damage or has_death:
		filtered_diff = diff_events.filter(func(e): return not (e is AttackEvent))
	else:
		filtered_diff = diff_events

	# 3. Separar por tipo para controlar el orden visual
	var attacks: Array = filtered_diff.filter(func(e): return e is AttackEvent)
	var draws:   Array = filtered_diff.filter(func(e): return e is DrawCardsEvent or e is DrawOpponentCardsEvent)
	var others:  Array = filtered_diff.filter(func(e): return not (e is AttackEvent or e is DrawCardsEvent or e is DrawOpponentCardsEvent))

	# Orden: engine events (daño + muerte) → invocación → robo → ataques diff → resto

	# 3a. Engine events: daño propio + muerte (antes de que el campo se limpie)
	var pre_summon: Array = engine_anim_events.filter(
		func(e): return not (e is KnightSummonedEvent)
	)
	var summon_events: Array = engine_anim_events.filter(
		func(e): return e is KnightSummonedEvent
	)
	for e in pre_summon:
		_queue.add(e)

	# 3b. Ataques del diff (solo si no los cubió engine_events)
	for e in attacks:
		_queue.add(e)

	# 3c. Draws
	if draws.size() > 1:
		_queue.add_parallel(draws)
	elif draws.size() == 1:
		_queue.add(draws[0])

	# 3d. Otros eventos del diff
	for e in others:
		_queue.add(e)

	# 4. Field sync — siempre ANTES de las invocaciones para que el slot esté listo
	_queue.add(RenderFieldEvent.new(gs))

	# 5. Invocaciones (Ikki/Shun) DESPUÉS del field sync
	for e in summon_events:
		_queue.add(e)


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
