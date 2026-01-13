# 🧪 Guía Rápida de Testing: Drag-Drop Implementation

**Versión:** 1.0
**Última Actualización:** Diciembre 26, 2025

---

## 🎯 Quick Start Testing

### 1. Iniciar TestBoard
```
1. Open Godot editor
2. Scene → TestBoard.tscn
3. Play (F5)
4. Wait for match to load
```

### 2. Observar Logs
En Output console, deberías ver:
```
[TestBoard] 🎭 Inicializando tablero de prueba...
[TestBoard] ✅ Inicializado y escuchando servidor
[MatchInitializer] Iniciando match test...
[TestBoard] ✅ GameState cargado
[TestBoard] 📊 Fase 1: Renderizando mazos...
[TestBoard] 🎴 Fase 2: Esperando precarga de imágenes...
[TestBoard] ✅ BoardRenderer creado
[MatchPlayController] 🎮 Configurando interacciones de cartas...
[MatchPlayController] ✅ Slots conectados: 12  ← Esto es CRÍTICO
[TestBoard] ✅ Partida lista para jugar
```

**Si ves "Slots conectados: 12"** → ✅ Setup correcto

---

## 🎴 Test 1: Drag Básico

### Pasos
1. Ver mano del jugador (cartas en la parte inferior)
2. **Hover** sobre una carta → debe destacarse
3. **Press + Hold** sobre carta
4. **Drag** hacia un slot de caballero (arriba)
5. **Release** en el slot

### Logs Esperados
```
[CardDisplay] 🎴 get_drag_data(): preparado [CARD_NAME] con type=knight
[CardSlot] _can_drop_data() returns true
[CardSlot] _drop_data() emitted card_dropped
[MatchPlayController] 🎯 Carta soltada en slot
[MatchPlayController] 📍 Drop zone: field_knight, slot: 0
[MatchPlayController] ✅ Enviando al servidor: [CARD_NAME] → field_knight[0]
[MatchEventBridge] 📤 Reenviando al servidor...
[MatchManager] 📡 HTTP: play_card()
```

### Resultados Esperados
- ✅ Carta se coloca en el slot
- ✅ Card se remueve de mano
- ✅ Logs muestran flujo completo
- ✅ NO hay errores en Output

---

## 🚫 Test 2: Validación de Tipo

### Pasos
1. Drag una carta de **TÉCNICA** (no caballero)
2. Soltar en slot de **CABALLERO**

### Logs Esperados
```
[CardDisplay] 🎴 get_drag_data(): preparado [TECHNIQUE_NAME] con type=technique
[CardSlot] _can_drop_data() returns false  ← RECHAZADO
[MatchPlayController] (No se emite card_dropped - slot rechazó)
```

### Resultados Esperados
- ✅ Carta NO se coloca
- ✅ Carta regresa a mano
- ✅ CardSlot rechaza por tipo inválido

---

## 🎯 Test 3: Validación de Slot Vacío

### Pasos
1. Drag una carta de CABALLERO
2. Soltar en slot de CABALLERO que YA TIENE CARTA

### Logs Esperados
```
[CardSlot] _can_drop_data() returns false  ← Slot ocupado
```

### Resultados Esperados
- ✅ Carta NO se coloca
- ✅ Carta regresa a mano

---

## 🔄 Test 4: Ciclo Completo

### Pasos Detallados
1. Drag carta 1 a knight slot 0
2. Ver que se coloca
3. Drag carta 2 a knight slot 1
4. Ver que se coloca
5. Presiona "End Turn" button
6. Espera a que servidor responda
7. Ver que cartas permanecen en slots
8. Ver que nueva mano se roba

### Validaciones
- ✅ Las cartas se colocan correctamente
- ✅ Las cartas desaparecen de mano
- ✅ El servidor responde
- ✅ GameState se actualiza
- ✅ setup_card_interactions() se vuelve a llamar
- ✅ Puedes seguir jugando

---

## 🐛 Troubleshooting

### Problema: "Slots conectados: 0"
**Causa:** BoardRenderer no se inicializó
**Solución:** 
```
1. Ver _setup_match_controllers() en TestBoard.gd
2. Verificar que board_renderer se crea
3. Verificar que se pasa a MatchPlayController
```

### Problema: Drag no funciona
**Causa:** CardDisplay no emite drag_started
**Solución:**
```
1. Verificar que CardDisplay._ready() conecta gui_input
2. Verificar que can_be_dragged() retorna true
3. Ver logs de [CardDisplay] en Output
```

### Problema: Slot rechaza carta válida
**Causa:** CardSlot._can_drop_data() retorna false
**Solución:**
```
1. Ver log de _can_drop_data() 
2. Verificar que card_type coincide con slot_type
3. Verificar que slot no está ocupado
4. Debug en CardSlot._can_drop_data()
```

### Problema: Carta se coloca pero servidor rechaza
**Causa:** Validaciones del servidor fallaron
**Solución:**
```
1. Ver logs del servidor Node.js
2. Verificar que endpoint play_card existe
3. Verificar que jugador tiene suficiente cosmos
4. Verificar que carta existe en mano
```

---

## 📊 Debug Commands (En TestBoard)

### Presionar 'D' - Diagnostics
```
Muestra:
✅ GameState status
✅ MatchPlayController status
✅ Signal connections
✅ Cards in hand count
```

### Presionar 'T' - Simulate Drag
```
Simula automáticamente un drag de carta
Útil para testear sin mouse
```

### Presionar 'P' - Print State
```
Imprime GameState completo en Output
Útil para ver qué cartas hay donde
```

---

## ✅ Checklist Final

- [ ] Logs muestran flujo correto
- [ ] Cartas se colocan en slots
- [ ] Tipos incorrectos se rechazan
- [ ] Slots ocupados se rechazan
- [ ] Servidor responde
- [ ] GameState se actualiza
- [ ] Puedes seguir jugando después
- [ ] Sin errores en Output
- [ ] Sin warnings en Output

Si todo ✅, **¡El drag-drop está listo para producción!**

---

## 🎓 Arquitectura Validada

```
✅ CardDisplay.get_drag_data() funciona
✅ CardSlot._can_drop_data() valida
✅ MatchPlayController._on_card_dropped_in_slot() recibe
✅ MatchEventBridge forwardea
✅ MatchManager envía HTTP
✅ Servidor responde
✅ TestBoard re-renderiza
✅ Ciclo se repite
```

**Responsabilidades CLARAS y SEPARADAS** ✅

