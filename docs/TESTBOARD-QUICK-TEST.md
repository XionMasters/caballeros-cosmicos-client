# Quick Test - TestBoard Rebuild

**Objetivo**: Verificar que Fase 1-2 funcionan correctamente

---

## Paso a Paso

### 1. Abrir Godot
```bash
Abre Godot editor
```

### 2. Cargar TestBoard
```bash
File → Open Recent → TestBoard.tscn
O: Navega a scenes/test/TestBoard.tscn
```

### 3. Ejecutar
```bash
Presiona F5 o Play button
```

### 4. Mira la consola de Output
```
View → Output (o presiona Ctrl+Shift+C)
```

---

## Qué Buscar en los Logs

### ✅ Señal Correcta

```
[TestBoard] 📊 Fase 1: Renderizando mazos...
[TestBoard] ✅ Mazos: P1=35, P2=40
[TestBoard] 🎴 Fase 2: Animando robo de cartas...
[CardDealAnimator] 🎴 Robando 7 cartas...
[CardDealAnimator] ✅ Carta 1 robada
[CardDealAnimator] ✅ Carta 2 robada
[CardDealAnimator] ✅ Carta 3 robada
[CardDealAnimator] ✅ Carta 4 robada
[CardDealAnimator] ✅ Carta 5 robada
[CardDealAnimator] ✅ Carta 6 robada
[CardDealAnimator] ✅ Carta 7 robada
[CardDealAnimator] ✅ Robo completado!
[TestBoard] 🎯 Fase 3: Renderizando campo...
[TestBoard] ✅ Mano oponente: 7 dorsos
[TestBoard] ✅ Field renderizado
[TestBoard] 🎮 Fase 4: Configurando controllers...
[TestBoard] ✅ Controllers configurados!
[TestBoard] ✅ Partida lista para jugar
```

### ❌ Señal de Error

```
[CardDealAnimator] ❌ Configuración incompleta
→ CardDealAnimator no se inicializó bien

[TestBoard] ⚠️ No hay cartas para robar!
→ GameState no tiene cartas en mano

❌ ERROR (sin contexto)
→ Exception en algún lado (revisar line number)
```

---

## Qué Buscar Visualmente

### ✅ Correcto

1. **Mazo**: Número visible en esquina izquierda (35 o 40)
2. **Animación**: Cartas se mueven suavemente desde mazo hacia mano
3. **Escala**: Cartas crecen mientras se mueven
4. **Timing**: Cartas salen con delay (una por una, no todas juntas)
5. **Final**: 7 cartas visibles en mano del jugador
6. **Oponente**: 7 dorsos azules en mano del oponente
7. **Field**: Slots vacíos o con cartas (según servidor)

### ❌ Incorrecto

```
Cartas aparecen de golpe
→ Sin animación, error en tween

Cartas se ven en mazo al final
→ No se están agregando a mano

Cartas muy pequeñas o muy grandes
→ Ajustar card_scale en CardDealAnimator

Cartas saltan jerky
→ Aumentar deal_duration (0.5 → 1.0)

Aparecen más de 7 cartas
→ Error en conteo de mano
```

---

## Debugging Específico

### Si FASE 1 no aparece (mazos)
**Archivo a revisar**: `TestBoard.gd` línea `_render_decks_only()`

```gdscript
print("DEBUG P1: %s" % player_deck)
print("DEBUG P2: %s" % opponent_deck)
```

### Si FASE 2 no termina (cartas no llegan)
**Archivo a revisar**: `CardDealAnimator.gd` línea `_deal_single_card()`

```gdscript
print("DEBUG deal_single_card card: %s" % card_instance.base_data.name)
print("DEBUG target_hand children before: %d" % target_hand.get_children().size())
```

### Si FASE 3 no renderiza field
**Archivo a revisar**: `TestBoard.gd` línea `_render_field_only()`

```gdscript
print("DEBUG knights: %d" % knights.size())
print("DEBUG slots: %d" % player_knight_slots.size())
```

### Si FASE 4 falla (controllers)
**Archivo a revisar**: `TestBoard.gd` línea `_setup_match_controllers()`

```gdscript
print("DEBUG match_play_controller: %s" % match_play_controller)
print("DEBUG match_event_bridge: %s" % match_event_bridge)
```

---

## Posibles Errores y Soluciones

### Error: "Configuración incompleta"
**Causa**: CardDealAnimator no recibió argumentos
**Solución**: En `TestBoard._animate_initial_deal()`, verifica que todos los parámetros sean válidos:
```gdscript
print("Animation manager: %s" % CardAnimationManager.new())
print("Card template: %s" % CARD_DISPLAY_TEMPLATE)
print("Target hand: %s" % player_hand)
print("Deck position: %s" % player_deck.global_position)
```

### Error: "No hay cartas para robar!"
**Causa**: `game_state.get_hand_for_player()` devuelve array vacío
**Solución**: Verificar que el servidor envió las cartas:
```gdscript
print("Player number: %d" % game_state.player_number)
print("Hand size: %d" % game_state.player_hand.size())
print("Hand content: %s" % game_state.player_hand)
```

### Cartas no aparecen en mano
**Causa**: Posible issue con `HandLayout.add_card()`
**Solución**: Verificar que HandLayout está funcionando:
```gdscript
print("HandLayout children: %d" % player_hand.get_children().size())
print("HandLayout cards: %d" % player_hand.get_cards().size())
```

### Animación muy rápida/lenta
**Solución**: En `CardDealAnimator.gd`, línea 24-25:
```gdscript
var deal_duration: float = 0.5  # Cambiar a 1.0 para más lento
var delay_between_cards: float = 0.15  # Cambiar a 0.3 para más espaciado
```

---

## Validación Paso a Paso

```
☐ Proyecto compila (sin errores rojos)
  ↓
☐ TestBoard carga sin crash
  ↓
☐ Log muestra "Fase 1: Renderizando mazos..."
  ↓
☐ Mazos visibles en pantalla con números
  ↓
☐ Log muestra "Fase 2: Animando robo..."
  ↓
☐ Cartas se animan desde mazo
  ↓
☐ Cartas llegan a mano (7 cartas visibles)
  ↓
☐ Log muestra "Robo completado!"
  ↓
☐ Log muestra "Fase 3: Renderizando campo..."
  ↓
☐ Mano oponente muestra 7 dorsos
  ↓
☐ Log muestra "Fase 4: Configurando controllers..."
  ↓
☐ Ningún error después
  ↓
✅ TODO FUNCIONA
```

---

## Próximo Paso

Una vez que Fase 1-4 funcione:

1. **Intenta arrastrar una carta**
2. **Comprueba si se mueve el mouse**
3. **Si no funciona**: Revisar `mouse_filter` en TestBoard.tscn

---

## Contacto con Problemas

Si algo falla:

1. **Copiar el log completo**
2. **Anotar qué fase falla**
3. **Describir qué falta visualmente**
4. **Revisar los archivos sugeridos arriba**

Ejemplo de buena descripción:
```
"Fase 2 no muestra. Mazo está visto, pero cartas no se animan.
Logs muestran 'Robando 7 cartas...' pero luego 'ERROR: ..." 
```

