# 🔍 Logs de Debuggeo - End Turn Button

## Qué buscar en la consola de Godot

Cuando presiones el botón "End Turn", deberías ver logs como estos:

### 1. **Inicialización** (al cargar la escena)
```
[GameMatch] 🔧 Configurando End Turn button...
[GameMatch] ✅ Button encontrado: EndTurnButton
[GameMatch] 🔗 Conectando pressed signal...
[GameMatch] ✅ Signal CONECTADA correctamente
```

Si ves esto, la conexión del botón está bien.

---

### 2. **Al Presionar el Botón**
```
╔════════════════════════════════════════╗
║  🎮 BOTÓN END TURN PRESIONADO 🎮     ║
╚════════════════════════════════════════╝
[GameMatch] is_in_match: true
[GameMatch] current_match exists: true
[GameMatch] current_match keys: [id, player1_id, player2_id, player1_name, player2_name, mode]
[GameMatch] match_id obtenido: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
[GameMatch] 🔄 Pasando turno...
[GameMatch] Enviando: POST /matches/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/pass-turn
```

**Si ves esto:** El botón se activó y está enviando la solicitud.

---

### 3. **Respuesta del Servidor**
```
[GameMatch] 🌐 Llamando ApiClient.post_request_with_callback()...
[GameMatch]    URL: /matches/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/pass-turn
[GameMatch] 📡 CALLBACK RECIBIDO
[GameMatch]    success: true
[GameMatch]    data: {'success': true, 'message': 'Turno pasado exitosamente', ...}
[GameMatch]    error: 
[GameMatch] ✅ Turno pasado exitosamente
[GameMatch] 📋 Respuesta del servidor: {...}
```

**Si ves esto:** El turno se pasó correctamente al servidor.

---

## 🐛 Troubleshooting por Mensaje

### ❌ "BOTÓN END TURN PRESIONADO" NO APARECE
- El botón NO se está presionando
- **Verificar:**
  - ¿El botón es clickeable? (no está fuera de pantalla, cubierto, etc.)
  - ¿El botón existe en la escena?
  - Abre DevTools → Inspector → busca "EndTurnButton"

### ❌ "Signal CONECTADA correctamente" NO APARECE
- La conexión de la signal falló
- **Verificar:**
  - ¿El nodo tiene el nombre exacto "EndTurnButton"?
  - ¿La ruta es correcta? Revisa GameMatch.tscn

### ❌ "match_id obtenido: ''" (string vacío)
- MatchManager.current_match no tiene ID
- **Verificar:**
  - Que `MatchManager.current_match` se inicializó
  - Ver logs de MatchManager cuando se crea la partida

### ❌ "No hay match activa"
- `MatchManager.is_in_match == false` o `current_match` es null
- **Verificar:**
  - Que lanzaste una partida TEST correctamente
  - Ver logs si la partida falló al iniciar

### ❌ "CALLBACK RECIBIDO success: false"
- El servidor rechazó la solicitud
- **Verificar:**
  - El mensaje de error en `error` field
  - Los logs del servidor (terminal donde corre Node.js)
  - Si es error de turno, validación, etc.

---

## 📋 Flujo Completo de Logs

Cuando todo funciona bien, deberías ver:

```
1. [Iniciar escena GameMatch]
   ✅ Signal CONECTADA correctamente

2. [Presionar botón]
   ✅ BOTÓN END TURN PRESIONADO
   ✅ match_id obtenido: 'xxx...'

3. [Hacer request]
   ✅ Pasando turno...
   ✅ Llamando ApiClient.post_request_with_callback()

4. [Respuesta del servidor]
   ✅ CALLBACK RECIBIDO
   ✅ success: true
   ✅ Turno pasado exitosamente
```

Si ves este flujo completo: **TODO FUNCIONA** ✅

---

## 🔗 Cómo Ver Logs en Godot

1. **Inicia la escena** (F5 o Play)
2. **Abre Output:** `View → Output` o `Ctrl + K`
3. **Presiona el botón**
4. **Mira los logs**

---

## 📊 Esperado por Modo

### Modo TEST
Después de "Turno pasado exitosamente", deberías ver:
```
[GameMatch] 🧪 TEST MODE: Esperando turno del rival...
```

### Modo PVP
Después, deberías ver:
```
[GameMatch] ⏳ Esperando turno del rival...
```

---

**Si algo no coincide con esto, reporta el mensaje exacto que ves.** ✅
