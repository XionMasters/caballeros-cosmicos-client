# 🧪 TestBoard - Configuración Completa

## ✅ Estado Actual

Todo el sistema TestBoard está **completamente implementado y listo para usar**.

### Lo que se ha configurado:

1. **TestBoard.tscn** - Escena con 3 zonas
   - Panel izquierdo: Etiquetas
   - Centro: Mano del jugador (HandContainer)
   - Derecha: DropZone
   - Abajo: Botones (Back, Clear, Reload)

2. **TestBoard.gd** - Lógica de carga y debugging
   - Carga mazos del usuario vía `DecksManager.fetch_user_decks()`
   - Obtiene cartas del deck via `GET /decks/{id}/cards`
   - Muestra las primeras 7 cartas
   - Conecta manualmente `gui_input` en cada CardDisplay
   - Imprime logs `[TEST]` para cada interacción

3. **MainLobby** - Navegación
   - Nuevo botón "🧪 Test" en la barra de navegación
   - Lleva a TestBoard

4. **Documentación** - Guía visual en `docs/TEST-BOARD-DEBUG-GUIDE.md`

---

## 🚀 Cómo Usar

### Paso 1: Abre el Cliente
Godot editor o compilado, apunta a `res://scenes/main/MainLobby.tscn`

### Paso 2: Haz Click en "🧪 Test"
En la barra de navegación del menú principal (entre Batalla y Chat)

### Paso 3: Abre Consola
- **Godot**: F8 o View → Output
- **VSCode Remote**: Ver terminal del proceso de Godot

### Paso 4: Interactúa con Cartas

#### Test 1: Click
```
1. Haz click en una carta en la mano
2. Busca en consola: [TEST] CLICK: <nombre>
3. ¿Lo ves? → ✅ interactividad funciona
4. ¿No lo ves? → ❌ evento no llega
```

#### Test 2: Drag
```
1. Click y arrastra una carta a la zona roja
2. Busca en consola: [TEST] DRAG START y [TEST] DRAG END
3. ¿Los ves? → ✅ dragging funciona
4. ¿No los ves? → ❌ evento no llega
```

---

## 📊 Interpretación de Resultados

### Escenario A: ✅ Todo funciona
```
[TEST] CLICK: Athena
[TEST] DRAG START
[TEST] DRAG END
```
**Conclusión**: El sistema de interactividad funciona. El problema está en GameBoard.  
**Siguiente**: Investigar diferencias en GameBoard (nodos, mouse_filter, overlays)

### Escenario B: ❌ Nada funciona
```
(No ves [TEST] CLICK, [TEST] DRAG START, etc.)
```
**Conclusión**: El patrón de interactividad está roto a nivel fundamental.  
**Siguiente**: Validar que Godot recibe eventos del mouse

```gdscript
# Agregar temporalmente en TestBoard._ready():
func _input(event: InputEvent):
    if event is InputEventMouseButton:
        print("[MOUSE EVENT] Button: ", event.button_index, " Pressed: ", event.pressed)
```

Busca `[MOUSE EVENT]` → Si aparece, ✅ Godot recibe eventos. Si no, ❌ problema del sistema.

### Escenario C: Parcial (solo clicks, no drag)
```
[TEST] CLICK: Athena
(No ves [TEST] DRAG START)
```
**Conclusión**: Clicks funcionan pero drag está roto.  
**Siguiente**: Revisar `CardDisplay._get_drag_data()` en `scripts/cards/CardDisplay.gd`

---

## 🔍 Logs Esperados por Fase

### Fase 1: Carga
```
[TEST] TestBoard._ready completado
[TEST] Solicitando mazos del usuario...
[TEST] _on_decks_loaded: 1 mazos encontrados
[TEST] Usando deck: Starter Deck (...)
[TEST] Fetching cards from: http://localhost:3000/api/decks/.../cards
[TEST] Deck tiene 40 cartas
[TEST] Cargadas 7 cartas en la mano
[TEST] Card added: Athena
[TEST] Card added: Ikki
[TEST] gui_input conectado para Athena
[TEST] gui_input conectado para Ikki
```

### Fase 2: Interactividad (lo que falta ver)
```
[TEST] CLICK: <nombre>          ← cuando haces click
[TEST] DRAG START               ← cuando empiezas a arrastrar
[TEST] DRAG END                 ← cuando sueltas
```

---

## 🛠 Troubleshooting

### "No veo cartas cargadas"
```
Causas posibles:
1. Usuario no autenticado → Revisar AuthManager token
2. No hay decks → Crear deck en aplicación web
3. Error HTTP → Ver logs de error en consola

Solución:
- Click "Reload" para reintentar
- Ir a MainLobby y volver
```

### "Cartas cargadas pero no responden a clicks"
```
Esto es lo que estamos testeando. Si esto pasa:
1. Es el problema que buscamos encontrar
2. Reporta esta situación → indica que ni siquiera TestBoard funciona
3. Revisa docs/TEST-BOARD-DEBUG-GUIDE.md sección "ESCENARIO 2"
```

### "Godot se crashea al cargar TestBoard"
```
Probablemente un error de script en TestBoard.gd
1. Abre TestBoard.gd en VSCode
2. Busca líneas con errores (VSCode los marca)
3. Revisa la Output console de Godot para detalles
```

---

## 🎯 Propósito Real de TestBoard

TestBoard NO es para jugar. Es para:

1. **Validar** que el sistema de interactividad funciona en un contexto simple
2. **Aislar** si el problema está en GameBoard o en el patrón fundamental
3. **Generar logs claros** que muestren exactamente qué está fallando
4. **Proporcionar un "laboratorio"** donde podemos agregar debug sin afectar GameBoard

---

## 📋 Checklist Pre-Test

- [ ] Cliente lanzado y autenticado
- [ ] Botón "🧪 Test" visible en MainLobby
- [ ] Console de Godot abierto (F8)
- [ ] Decks del usuario existen (si falta, crear uno en web)
- [ ] Conexión al servidor OK

---

## 📝 Reporte Esperado

Después de usar TestBoard, reporta:

```
1. ¿Aparecen logs de Fase 1 (carga)?
   [ ] Sí, todas las cartas cargadas
   [ ] Sí, pero con errores
   [ ] No, TestBoard está en blanco

2. ¿Responden los clicks?
   [ ] Sí, veo [TEST] CLICK: ...
   [ ] No, nada sucede

3. ¿Funciona el drag?
   [ ] Sí, veo [TEST] DRAG START/END
   [ ] No, nada sucede

4. ¿Qué logs viste exactamente?
   [Copia/pega los logs de la consola aquí]
```

---

## 🔗 Archivos Relacionados

- `scripts/game/TestBoard.gd` - Lógica principal
- `scenes/test/TestBoard.tscn` - Scene visual
- `scenes/main/MainLobby.gd` - Navegación
- `scripts/cards/CardDisplay.gd` - Interactividad de cartas
- `docs/TEST-BOARD-DEBUG-GUIDE.md` - Guía detallada
- `docs/LANGUAGE-PERSISTENCE-EXPLAINED.md` - Localization

---

**¡TestBoard está listo! 🚀 Haz las pruebas y reporta qué ves en los logs.**
