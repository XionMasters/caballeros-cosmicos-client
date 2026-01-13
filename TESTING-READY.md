# 🚀 TESTBOARD - LISTO PARA TESTING

## ✅ Estado Final

**TODO está implementado y ajustado**

| Componente | Estado | Notas |
|-----------|--------|-------|
| **Cliente (Godot)** | ✅ LISTO | TestBoard refactorizado, ajustes aplicados |
| **Servidor (Node.js)** | ✅ LISTO | Endpoints y handlers implementados |
| **Base de Datos** | ✅ LISTO | Models Match y CardInPlay listos |
| **Arquitectura** | ✅ LIMPIA | Separación de concerns aplicada |
| **Testing** | ✅ LISTO | Documentación completa |

---

## 📋 Checklist Final

### Cliente (Godot) ✅

- [x] TestBoard.gd - Refactorizado a Server-Authoritative (9 pasos)
- [x] GameState.gd - Getters implementados
- [x] MatchManager.gd - Limpiado y optimizado:
  - [x] current_match: Solo metadata
  - [x] _on_match_updated(): Único camino de actualización
  - [x] signal phase_changed: Desacoplado de UI
  - [x] Variables drag: Movidas a GameBoard
- [x] TestBoard.gd - Variables drag agregadas
- [x] DecksManager - get_active_deck() listo
- [x] CardsManager - preload_deck_images() listo
- [x] WebSocketManager - request_test_match() listo

### Servidor (Node.js) ✅

- [x] POST /api/match/test endpoint
- [x] startTestMatch() controller
- [x] handleRequestTestMatch() WebSocket handler
- [x] handleDeclareAttack() WebSocket handler
- [x] Shuffle & draw implementation
- [x] GameState serialization
- [x] Error handling & validation
- [x] match_found y match_update broadcasts

### Documentación ✅

- [x] TESTBOARD-SERVER-AUTHORITATIVE.md
- [x] TESTBOARD-REFACTOR-SUMMARY.md
- [x] TESTBOARD-DEBUGGING-GUIDE.md
- [x] TESTBOARD-SERVER-IMPLEMENTATION.md
- [x] TESTBOARD-COMPLETE-SYSTEM.md
- [x] ADJUSTMENTS-PRE-TESTING.md

---

## 🎮 Cómo Testear

### Paso 1: Setup
```bash
# Servidor
cd d:\Disco E\Proyectos\Server-SS
npm run dev  # o tu comando de desarrollo

# Cliente
# Abrir Godot project en d:\Disco E\Nacho\Projects\ccg
```

### Paso 2: Verificar Requisitos
- [ ] Servidor corriendo en puerto 3000
- [ ] BD PostgreSQL conectada
- [ ] Usuario creado
- [ ] Mazo con 40+ cartas creado
- [ ] Mazo marcado como is_active=true
- [ ] WebSocket disponible

### Paso 3: Testing

1. **Abrir TestBoard**
   ```gdscript
   get_tree().change_scene_to_file("res://scenes/game/TestBoard.tscn")
   ```

2. **Click Botón TEST**
   - Esperado: Loading label visible
   - Consola: `[TestBoard] 🎭 launch_test_match`

3. **Esperar 5-10s**
   - Servidor: Obtiene deck, baraja, roba
   - Esperado: Tablero se renderiza

4. **Verificar UI**
   - [x] Mano: 7 cartas
   - [x] Oponente: 7 dorsos
   - [x] Deck P1: 33 (40-7)
   - [x] Deck P2: 33
   - [x] Vida: 12 ambos
   - [x] Cosmos: 0 ambos
   - [x] Turno: 1
   - [x] Player: "Jugador 1"

5. **Click End Turn**
   - Esperado: 1-3s espera
   - Verificar:
     - Turno → 2
     - Player → "Jugador 2"
     - P2 robó carta (mano 8, deck 32)

6. **Continuar Varios Turnos**
   - Verificar alternancia correcta
   - Verificar contadores actualizados

---

## 🔍 Debug Tips

### Consola del Cliente (Godot)

Buscar logs de:
```
[TestBoard] 🎭 launch_test_match    # Inicio
[TestBoard] 1️⃣ Obteniendo mazo...   # Paso 1
[TestBoard] 2️⃣ Validando mazo...    # Paso 2
[TestBoard] 3️⃣ Precargando...       # Paso 3
[TestBoard] 4️⃣ Pidiendo servidor... # Paso 4
[TestBoard] 8️⃣ Partida iniciada     # Paso 8
[TestBoard] ✅ Tablero listo        # Paso 9
```

### Consola del Servidor (Node.js)

Buscar logs de:
```
🎭 TEST Match creada         # Endpoint ejecutado
📋 Mazo expandido            # Cartas expandidas
🔀 Mazos barajeados          # Shuffle completado
✅ CardInPlay creados        # Cartas en BD
📡 match_found enviada       # WebSocket enviado
```

### Errores Comunes

**❌ "No tienes un mazo activo"**
- [ ] Verificar usuario tiene deck
- [ ] Verificar deck está marcado is_active=true
- [ ] Solución: Crear/marcar deck en CollectionScreen

**❌ "Tu mazo no cumple reglas"**
- [ ] Verificar mazo tiene 40+ cartas
- [ ] Verificar no excede 100 cartas
- [ ] Solución: Agregar/remover cartas

**❌ WebSocket timeout (30s+ sin respuesta)**
- [ ] Verificar servidor está corriendo
- [ ] Verificar puerto 3000 disponible
- [ ] Verificar WebSocket inicializado
- [ ] Revisar logs del servidor

**❌ "Match no encontrado"**
- [ ] Verificar endpoint responde correctamente
- [ ] Verificar match se guardó en BD
- [ ] Revisar logs servidor

---

## 📊 Flujo Esperado

```
CLIENTE (Godot)              SERVIDOR (Node.js)          BD (PostgreSQL)
    │                              │                           │
    ├─→ launch_test_match()        │                           │
    │   fetch_active_deck()        │                           │
    │   [HTTP] ←───────────────────┤                           │
    │                              SELECT deck                 │
    │                              ←───────────────────────────┤
    │   validate & preload          │                           │
    │                              │                           │
    │   request_test_match()        │                           │
    │   [WebSocket] ←───────────────┤                           │
    │                    handleRequestTestMatch()              │
    │                    - Get deck                            │
    │                    - Shuffle                             │
    │                    - Create Match ─────────────────────→ │
    │                    - Create CardInPlay ───────────────→ │
    │                    - Serialize GameState                 │
    │   [match_found] ←──────────────┤                           │
    │   MatchManager gets GameState  │                           │
    │   TestBoard._on_match_started()│                           │
    │   render_all_zones()           │                           │
    │   ✅ UI visible                │                           │
    │                              │                           │
    │   end_turn() ──────────────→  │                           │
    │   [WebSocket]        handleEndTurn()                      │
    │                       - Change turn                       │
    │                       - Draw card ─────────────────────→ │
    │   [match_update] ←──────────────┤                           │
    │   Render updated state         │                           │
    │                              │                           │
```

---

## 🎯 Resultados Esperados

### Test Exitoso
- ✅ Tablero renderiza correctamente
- ✅ Mano tiene 7 cartas
- ✅ Turnos alternan correctamente
- ✅ Cartas se roban cada turno
- ✅ Contadores actualizados
- ✅ No hay crashes o errores

### Test Fallido (Ejemplos)
- ❌ Tablero no se renderiza
  - → Revisar GameState.from_server_data()
- ❌ Mano vacía
  - → Revisar servidor robó cartas
- ❌ Turnos no cambian
  - → Revisar WebSocket match_update
- ❌ Crash en cliente
  - → Revisar error en consola Godot
- ❌ Timeout WebSocket
  - → Revisar servidor está corriendo

---

## 📚 Documentación de Referencia

| Doc | Contenido |
|-----|-----------|
| [TESTBOARD-SERVER-AUTHORITATIVE.md](./TESTBOARD-SERVER-AUTHORITATIVE.md) | Arquitectura completa 9 pasos |
| [TESTBOARD-REFACTOR-SUMMARY.md](./TESTBOARD-REFACTOR-SUMMARY.md) | Cambios realizados |
| [TESTBOARD-DEBUGGING-GUIDE.md](./TESTBOARD-DEBUGGING-GUIDE.md) | Tips de debugging |
| [ADJUSTMENTS-PRE-TESTING.md](./ADJUSTMENTS-PRE-TESTING.md) | Ajustes de arquitectura |
| [../Server-SS/docs/TESTBOARD-COMPLETE-SYSTEM.md](../Server-SS/docs/TESTBOARD-COMPLETE-SYSTEM.md) | Visión e2e |

---

## ⏱️ Estimación de Tiempo

| Actividad | Tiempo |
|-----------|--------|
| Setup servidor | 5 min |
| Setup cliente | 2 min |
| Primer test | 10 min |
| Debugging (si necesario) | 15-30 min |
| **Total** | **30-50 min** |

---

## ✨ Conclusión

**TODO ESTÁ LISTO**

✅ Cliente: Refactorizado, limpio, Server-Authoritative
✅ Servidor: Endpoints y handlers implementados
✅ BD: Models listos
✅ Arquitectura: Separación de concerns aplicada
✅ Documentación: Completa y detallada

**Siguiente paso**: Abre Godot, navega a TestBoard, y haz click en TEST.

---

**Última Actualización**: Diciembre 22, 2025  
**Estado**: ✅ LISTO PARA TESTING  
**Versión**: 1.0 - Complete

