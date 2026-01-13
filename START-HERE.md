# 🎮 Caballeros Cósmicos - Arquitectura Server-Authoritative

## 📋 Estado Actual

La arquitectura del cliente ha sido **completamente refactorizada** para ser **Server-Authoritative**.

- ✅ Cliente forwardea intenciones al servidor
- ✅ Servidor es la única fuente de verdad
- ✅ GameState solo se modifica desde servidor (via MatchManager)
- ✅ HTTPRequest SOLO en APIClient
- ✅ No hay cálculos locales de reglas/daño

---

## 📚 Documentación Crítica

### Para Entender la Arquitectura

1. **[CLAUDE.md](docs/CLAUDE.md)** ← **LEER PRIMERO**
   - Documento maestro de referencia
   - Arquitectura completa
   - Módulos explicados
   - Reglas de oro

2. **[BEFORE-AFTER-VISUAL-SUMMARY.md](docs/BEFORE-AFTER-VISUAL-SUMMARY.md)**
   - Diagrama visual de cambios
   - Qué se eliminó/refactorizo
   - Comparación antes/después

3. **[CODE-PATTERNS-EXPLAINED.md](docs/CODE-PATTERNS-EXPLAINED.md)**
   - Cómo se refleja en código
   - Patrones correctos/incorrectos
   - Ejemplos reales del proyecto

4. **[ARCHITECTURE-CORRECTIONS-SESSION-SUMMARY.md](docs/ARCHITECTURE-CORRECTIONS-SESSION-SUMMARY.md)**
   - Resumen de cambios realizados
   - Archivos eliminados
   - Archivos refactorizados

5. **[TESTBOARD-SERVER-AUTHORITATIVE.md](docs/TESTBOARD-SERVER-AUTHORITATIVE.md)** ← **NUEVA**
   - Arquitectura completa de TestBoard
   - Flujo 9 pasos explicado
   - GameState como mirror del servidor
   - Patrones de comunicación cliente-servidor

---

## ⚙️ Cambios Realizados

### ✅ Refactorizado

- `scripts/game/CardPlayManager.gd` - Ahora valida UX mínimo, forwardea a MatchManager
- `scripts/rules/GameController.gd` - Ahora Intention Validator, no modifica GameState

### ❌ Eliminado del Cliente

- `scripts/rules/GameRules.gd` - Pertenece al servidor
- `scripts/rules/BattleCalculator.gd` - Pertenece al servidor
- `scripts/managers/HandManager.gd` - Pertenece al servidor
- `scripts/managers/FieldManager.gd` - Pertenece al servidor

### ✅ Creado en Documentación

- `docs/CLAUDE.md` - Documento maestro
- `docs/ARCHITECTURE-CORRECTIONS-SESSION-SUMMARY.md` - Resumen de cambios
- `docs/BEFORE-AFTER-VISUAL-SUMMARY.md` - Comparación visual
- `docs/CODE-PATTERNS-EXPLAINED.md` - Patrones de código

---

## 🔄 Flujo Correcto Ahora

```
┌──────────────────┐
│  Usuario         │
└────────┬─────────┘
         │
         ├─1─▶ GameBoard (UI)
         │
         ├─2─▶ GameController (valida UX mínimo)
         │
         ├─3─▶ MatchManager (forwardea)
         │
         ├─4─▶ APIClient (HTTP)
         │
         ▼
┌──────────────────────────┐
│  SERVIDOR                │
├─ Valida TODO            │
├─ Calcula                │
├─ Aplica                 │
└─────────┬────────────────┘
         │
         ├─5─▶ WebSocket response
         │
         ├─6─▶ WebSocketManager
         │
         ├─7─▶ MatchManager (actualiza GameState)
         │
         ├─8─▶ GameState.state_changed.emit()
         │
         ▼
    ┌──────────────────┐
    │  GameBoard       │ Se re-renderiza
    │  (re-renderiza)  │ automáticamente
    └──────────────────┘
```

---

## ✅ Checklist de Validación

Antes de trabajar en nuevas features:

- [ ] ¿Leíste [CLAUDE.md](docs/CLAUDE.md)?
- [ ] ¿Entiendes que Server decide TODO?
- [ ] ¿Sabes que HTTPRequest solo va en APIClient?
- [ ] ¿Sabes que GameState solo se modifica desde MatchManager?
- [ ] ¿Sabes que GameController FORWARDEA, no modifica?

---

## 🚀 Próximas Tareas

### Para Backend (Servidor)

1. Implementar `GameRules` en servidor
2. Implementar `BattleCalculator` en servidor
3. Asegurar validación completa
4. Crear endpoints REST completos
5. Implementar WebSocket correctamente

### Para Frontend (Cliente)

1. Verificar APIClient completamente funcional
2. Testear flujo completo (intent → server → response → rerender)
3. Hacer que TestBoard funcione como cliente normal con 2 players
4. Testear GameBoard con servidor real
5. Testear multiplayer sin conflictos

---

## 📖 Guía Rápida

### Para Agregar Nueva Funcionalidad

1. **¿Necesitas validar algo?**
   - ✅ Valida MÍNIMO en cliente (propiedades visibles)
   - ✅ Forwardea al servidor
   - ❌ NO hagas validación compleja

2. **¿Necesitas comunicación con servidor?**
   - ✅ Usa APIClient (HTTP)
   - ✅ Usa WebSocketManager (WebSocket)
   - ❌ NUNCA HTTPRequest directo

3. **¿Necesitas modificar GameState?**
   - ✅ SOLO desde MatchManager
   - ✅ SOLO cuando responde servidor
   - ❌ NUNCA directo desde controller

4. **¿Necesitas animar cambios?**
   - ✅ Escucha GameState.state_changed signal
   - ✅ Renderiza automáticamente
   - ❌ NO asumas cambios locales

---

## 📞 Referencias Rápidas

| Necesito... | Usar... | NO usar... |
|-------------|---------|-----------|
| Validar UX | GameController | GameRules |
| Forwardear acción | MatchManager | HTTPRequest directo |
| HTTP | APIClient | Llamadas HTTP locales |
| WebSocket | WebSocketManager | Conexiones WS locales |
| Actualizar GameState | MatchManager | Modificación directa |
| Renderizar | Escucha signals | Modificación asumida |

---

## 🎯 El Principio

> **"El servidor manda en ambos tipos de partidas. El cliente solo verifica UX y forwardea."**

- ✅ TestBoard = cliente que maneja 2 players
- ✅ GameBoard = cliente que maneja 1 player
- ✅ Ambos dependen del servidor para validación
- ✅ No hay "modo local con reglas propias"

---

**Actualizado**: 22 de Diciembre, 2025  
**Referencia obligatoria**: [docs/CLAUDE.md](docs/CLAUDE.md)


---

## 📚 Documentación Rápida

| Lo quiero saber | Archivo |
|-----------------|---------|
| Cómo probar? | **TESTBOARD-QUICK-START.md** ⚡ |
| Qué cambió? | **DEBUGGING-SESSION-SUMMARY.md** 📝 |
| Estado total? | **PROJECT-STATUS.md** 📊 |
| Cómo debuggear? | **TEST-BOARD-DEBUG-GUIDE.md** 🔧 |
| Todos los docs? | **INDEX.md** 📚 |

---

## ✅ Lo Que Se Ha Arreglado

| Problema | Solución | Estado |
|----------|----------|--------|
| Cartas no responden a clicks | GUI input manual conectado | ✅ Hecho |
| Contadores de decks incorrectos | Server expande cartas | ✅ Hecho |
| Dorsos no cargan | Caché y preload | ✅ Hecho |
| No hay forma de debuggear | TestBoard creado | ✅ Nuevo |

---

## 🚀 Nuevo: TestBoard

**Qué es**: Entorno de prueba simplificado para testear interactividad de cartas

**Dónde está**: Botón "🧪 Test" en MainLobby

**Qué genera**: Logs `[TEST]` en la consola para cada interacción

**Por qué**: Para aislar si el problema está en GameBoard o en el sistema fundamental

---

## 📁 Archivos Clave

```
ccg/
├── TESTBOARD-QUICK-START.md          ⚡ EMPIEZA AQUÍ
├── INDEX.md                          📚 Todos los documentos
├── PROJECT-STATUS.md                 📊 Estado completo
├── DEBUGGING-SESSION-SUMMARY.md      📝 Cambios realizados
│
├── scenes/test/TestBoard.tscn        🧪 Nuevo (escena)
├── scripts/game/TestBoard.gd         🧪 Nuevo (lógica)
├── scenes/main/MainLobby.tscn        ✏️ Modificado (+ botón)
├── scripts/cards/CardDisplay.gd      ✏️ Modificado (logging)
└── scenes/game/GameBoard.gd          ✏️ Modificado (conexión manual)
```

---

## 🔍 Validación

```
✅ No hay errores de compilación
✅ Todos los scripts compilan
✅ TestBoard está listo para usar
✅ MainLobby tiene botón 🧪 Test
✅ Documentación completa
```

---

## 🎯 Próximo Paso

👉 Lee: **TESTBOARD-QUICK-START.md**

Es todo lo que necesitas para probar.

---

**Última actualización**: Diciembre 2025  
**Estado**: ✅ Listo para Testing
