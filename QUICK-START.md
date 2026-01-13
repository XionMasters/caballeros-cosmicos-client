# 🎮 Cómo Probar el Tablero Actualizado

## Quick Start (2 minutos)

### Paso 1: Abrir Godot
```
cd d:\Disco E\Nacho\Projects\ccg
godot
```

### Paso 2: Abrir TestBoard
```
File → Recent Files → TestBoard.tscn
O
File → Open Scene → res://scenes/test/TestBoard.tscn
```

### Paso 3: Run
```
Press F5
O
Scene → Run
```

### Paso 4: Observar

Debería ver un tablero completamente funcional con:
- ✅ Cartas en mano del oponente (arriba)
- ✅ Campos de caballeros y técnicas del oponente
- ✅ Campos de técnicas y caballeros del jugador (abajo)
- ✅ Mano del jugador VISIBLE COMPLETAMENTE (no cortada)
- ✅ Scenario y piles en la derecha
- ✅ Mazos en la izquierda

---

## Verificación Rápida

### En la consola deberías ver:

✅ `[TestBoard] ✅ Todos los slots de campo validados correctamente`

✅ `[TestBoard] ⚔️ Caballero jugador: ...`

✅ `[TestBoard] 🔮 Técnica jugador: ...` (si hay técnicas)

✅ `[TestBoard] ✅ Campos de técnicas renderizados`

✅ `[TestBoard] ✅ Zonas especiales renderizadas`

---

## Features Testeables

### 1. Mano del Jugador
```
✓ Cartas visibles en la parte inferior
✓ NO deberían estar cortadas
✓ Deberían ser interactuables
```

### 2. Campos de Caballeros
```
✓ 5 slots negros por jugador
✓ Si hay caballeros, deberían aparecer
✓ Double-click muestra detail
```

### 3. Campos de Técnicas
```
✓ 5 slots negros por jugador NUEVO
✓ Si hay técnicas, deberían aparecer
✓ Double-click muestra detail
```

### 4. Zonas Especiales
```
✓ Helper slot visible (derecha de técnicas)
✓ Occasion slot visible (derecha de caballeros del jugador)
✓ Scenario slot visible (en RightColumn)
```

### 5. Piles
```
✓ Yomotsu: 0 (visible en RightColumn)
✓ Cositos: 0 (visible en RightColumn)
```

---

## Si Algo Falla

### Cartas aún cortadas?
```
1. Abre TestBoard.tscn
2. Selecciona PlayerHeader
3. Verifica que PlayerHand tenga size_flags_vertical = 3
4. Verifica que PlayerArea tenga size_flags_vertical = 2
```

### Slots no visibles?
```
1. Selecciona CenterColumn en el editor
2. Verifica que tenga size_flags_horizontal = 3
3. Verifica que RightColumn tenga custom_minimum_size = Vector2(140, 0)
```

### Errores en consola?
```
Busca "[TestBoard]" en la consola
Lee el mensaje de error completo
Revisa que todas las referencias @onready se conecten (should say ✅)
```

---

## Archivos Importantes

| Archivo | Propósito |
|---------|-----------|
| `scenes/test/TestBoard.tscn` | Scene con todos los slots |
| `scripts/game/TestBoard.gd` | Controller que renderiza |
| `scripts/game/CardDisplay.gd` | Card visual (con double-click) |
| `scripts/models/CardSlot.gd` | Slot container |

---

## Documentación Completa

Para más detalles, consulta:
- `TABLERO-AHORA-COMPLETO.md` - Descripción completa
- `TABLERO-ACTUALIZADO-COMPLETO.md` - Cambios técnicos
- `CARD-DETAIL-VIEW-IMPLEMENTATION.md` - Detail overlay feature

---

**¡Que disfrutes! 🎮**

