# AnimationQueue.gd
# Ejecuta una lista de AnimationEvents, uno a uno (secuencial) o en grupos
# (paralelo). La clave del sistema: el estado del juego ya fue aplicado,
# esta cola sólo decide CUÁNDO y CÓMO mostrar cada cambio.
#
# API:
#   queue.add(event)                  ← evento secuencial
#   queue.add_parallel([e1, e2])      ← e1 y e2 se animan al mismo tiempo
#   await queue.run(ctx)              ← ejecutar todo y vaciar la cola
#   await queue.run_single(e, ctx)    ← ejecutar un evento sin encolarlo
#
# Flujo de ejecución:
#   [ SEQUENTIAL ]                → await event.play(ctx)
#   [ PARALLEL [e1, e2, e3] ]     → coroutines en paralelo, await a cada una
#   [ SEQUENTIAL ]                → await event.play(ctx)
#
# Nota sobre paralelismo:
#   En GDScript 4, llamar a una func async SIN await la inicia de inmediato
#   hasta su primer await. Guardando la coroutine y haciendo await después,
#   todas corren solapadas (verdadero paralelismo de coroutines).

class_name AnimationQueue
extends RefCounted

# ============================================================================
# ESTADO INTERNO
# ============================================================================
## Cada entrada es: AnimationEvent (secuencial) | Array[AnimationEvent] (paralelo)
var _entries: Array = []

## Señal interna para sincronizar el grupo paralelo activo
signal _group_finished
var _pending: int = 0

# ============================================================================
# API PÚBLICA
# ============================================================================

func add(event: AnimationEvent) -> void:
	"""Encolar un evento para ejecutarse en serie con los anteriores."""
	_entries.append(event)


func add_parallel(events: Array) -> void:
	"""Encolar un grupo de eventos que se ejecutan a la vez.
	Si viene un solo evento, se trata como secuencial normal.
	"""
	if events.is_empty():
		return
	if events.size() == 1:
		_entries.append(events[0])
	else:
		_entries.append(events)  # Array = grupo paralelo


func clear() -> void:
	_entries.clear()


# ============================================================================
# EJECUCIÓN
# ============================================================================

func run(ctx: AnimationContext) -> void:
	"""Ejecutar todos los eventos encolados y vaciar la cola.
	Toma un snapshot al inicio para que eventos añadidos durante
	la ejecución se procesen en la próxima llamada a run()."""
	var snapshot := _entries.duplicate()
	_entries.clear()
	for entry in snapshot:
		if entry is Array:
			await _run_parallel_group(entry, ctx)
		elif entry is AnimationEvent:
			print("[AnimationQueue] ▶ %s" % entry.label)
			await entry.play(ctx)


func run_single(event: AnimationEvent, ctx: AnimationContext) -> void:
	"""Ejecutar un evento puntual sin toccar la cola.
	Útil para ataques y efectos disparados por interacción del jugador."""
	print("[AnimationQueue] ▶ (single) %s" % event.label)
	await event.play(ctx)


func _run_parallel_group(events: Array, ctx: AnimationContext) -> void:
	"""Lanzar todos los eventos del grupo a la vez y esperar a que terminen.
	Usa señal + contador: cada coroutine se inicia sin await (fire-and-forget)
	y decrementa el contador al terminar. Cuando llega a 0 emite _group_finished."""
	var labels := ", ".join(events.map(func(e: AnimationEvent) -> String: return e.label))
	print("[AnimationQueue] ⚡ Paralelo [%s]" % labels)

	_pending = events.size()
	for event in events:
		_start_one(event, ctx)
	await _group_finished


func _start_one(event: AnimationEvent, ctx: AnimationContext) -> void:
	"""Inicia una coroutine individual del grupo paralelo (llamada sin await).
	Al terminar, decrementa el contador y avisa si era la última.

	IMPORTANTE: el 'await process_frame' garantiza que _group_finished se emite
	DESPUÉS de que _run_parallel_group haya llegado a 'await _group_finished'.
	Sin él, si event.play() es síncrono, la señal se emite antes de que nadie
	la esté escuchando → deadlock permanente (el bug de SyncHand)."""
	await event.play(ctx)
	await ctx.parent_node.get_tree().process_frame
	_pending -= 1
	if _pending <= 0:
		_group_finished.emit()
