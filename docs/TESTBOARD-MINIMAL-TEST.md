# TestBoard Minimal Test Guide

**Objetivo**: Verificar que cartas se animan sin duplicación y son interactuables

---

## Pasos

### 1. Abrir Godot
```
File > Open Project > ccg/
```

### 2. Cargar Escena
```
scenes/test/TestBoard.tscn
```

### 3. Ejecutar
```
F5 (Play)
```

### 4. Ver Output Panel
```
View > Output (o presiona F10)
```

---

## Qué Esperar (Logs)

Deberías ver estos mensajes EN ESTE ORDEN:

```
[TestBoard] ✅ Inicializado y escuchando servidor
[TestBoard] 🎪 Match TEST iniciado - Esperando servidor...
[TestBoard] 🎪 Partida recibida del servidor
[TestBoard] 🎴 Fase 1: Renderizando mazos...
[TestBoard] ✅ Mazos: P1=33, P2=33
[TestBoard] 🎴 Fase 2: Animando robo de cartas...
  (cartas aparecen con animación)
[TestBoard] ✅ Cartas animadas: 7 cartas
[TestBoard] 🎯 Fase 3: Renderizando mano oponente...
[TestBoard] ✅ Mano oponente: 7 dorsos
[TestBoard] 🎮 Fase 4: Configurando controllers...
[TestBoard] ✅ Turno: 1, Fase: draw
[TestBoard] 🎮 Configurando controllers de juego...
[TestBoard] ✅ Controllers configurados!
```

---

## Qué Ver Visualmente

- [ ] 2 pilas de mazo en la izquierda (con contadores: 33/33)
- [ ] 7 cartas visibles en la mano inferior
- [ ] 7 dorsos (cartas de atrás) en la mano superior
- [ ] Labels de turno/fase/vida/cosmos arriba

---

## Test de Interactividad

### 1. Intentar Arrastrar Carta
```
1. Hacer hover sobre una carta en tu mano
2. Debería elevarse/agrandarse un poco
3. Hacer click + drag
4. Arrastrar hacia cualquier lado
5. Soltar (drop)
```

### 2. Resultado Esperado
Alguno de estos:
- ✅ Carta se mueve a nueva posición
- ✅ Se ve feedback visual (color, opacidad)
- ✅ Aparece mensaje en Output
- ❌ Si NO pasa nada = problema en MatchPlayController

### 3. Si Cartas No Responden
Revisar:
```
1. ¿Output muestra todos los logs de Fase 1-4?
   ├─ NO: Problema en _on_match_started()
   └─ SÍ: Continuar paso 2

2. ¿Output muestra "Controllers configurados!"?
   ├─ NO: Problema en _setup_match_controllers()
   └─ SÍ: MatchPlayController creado ok

3. ¿Puedes ver las cartas?
   ├─ NO: Problema en CardDealAnimator
   └─ SÍ: Continuar paso 4

4. ¿Las cartas tienen cursor de mano (pointer)?
   ├─ NO: CardDisplay no recibe mouse events
   └─ SÍ: Problema en drag logic
```

---

## Checklist Final

- [ ] Sin logs de error en Output
- [ ] 7 cartas en mano + 7 dorsos oponente
- [ ] Contadores: P1=33, P2=33
- [ ] Cursor cambia a "mano" al pasar sobre cartas
- [ ] Al hacer hover, cartas se elevan/agrandas
- [ ] **IMPORTANTE**: Sin cartas duplicadas en mano

---

## Si Las Cartas Están Duplicadas

Ejemplo problema:
```
Debería haber 7 cartas, pero aparecen 14 (duplicadas)
```

**Causa**: `_on_match_state_updated()` está llamando a `render_all_zones()`

**Solución**: YA ELIMINADO en esta versión - si aún ocurre, reportar error

---

## Debug Command (Optional)

Si quieres ver el GameState completo, agregar en TestBoard._on_match_started():

```gdscript
func _on_match_started(state: GameState) -> void:
    game_state = state
    
    # 🔍 DEBUG
    print("\n=== GAME STATE ===")
    print("Player hand count: ", game_state.get_hand_for_player(1).size())
    print("Opponent hand count: ", game_state.opponent_hand_count)
    print("Player deck: ", game_state.player_deck_count)
    print("Opponent deck: ", game_state.opponent_deck_count)
    print("==================\n")
    
    # ... resto de código
```

---

## Success Criteria ✅

Testboard se considera **FUNCIONAL MINIMAL** si:

1. ✅ Se carga sin errores
2. ✅ Anima 7 cartas de mazo a mano
3. ✅ Muestra 7 dorsos en mano oponente
4. ✅ Cartas no están duplicadas
5. ✅ Cursor responde al pasar sobre cartas
6. ✅ Cartas responden a drag (aunque no hagan nada especial aún)

---

## Próximas Fases (Después de Verificar)

Una vez que ESTO funcione sin problemas:

1. **Fase 5**: Implementar drop logic (validar dónde se puede soltar)
2. **Fase 6**: Enviar al servidor (play_card endpoint)
3. **Fase 7**: Agregar field slots cuando necesario
4. **Fase 8**: Animar transiciones

Pero por ahora: **SOLO VERIFICAR QUE CARTAS SON INTERACTUABLES**

