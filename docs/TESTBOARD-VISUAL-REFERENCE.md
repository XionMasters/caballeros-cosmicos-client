# 🎯 TestBoard Interactive System - Visual Reference

## Arquitectura General

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│                         TESTBOARD.GD                            │
│                    (Orquestador Principal)                      │
│                                                                  │
│  _ready()                                                        │
│    ├─ Crear BoardRenderer                                       │
│    ├─ Crear MatchInitializer                                    │
│    └─ Escuchar eventos del servidor                             │
│                                                                  │
│  _on_match_started()                                            │
│    ├─ Guardar GameState                                         │
│    ├─ Llamar render_all_zones()                                │
│    └─ Crear MatchPlayController + MatchEventBridge ✨          │
│                                                                  │
│  _on_match_state_updated()                                      │
│    ├─ Re-renderizar tablero                                     │
│    └─ Re-conectar eventos de cartas ✨                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
         │                    │                        │
         ▼                    ▼                        ▼
    ┌─────────────┐    ┌──────────────┐    ┌──────────────────────┐
    │ BoardRend   │    │ MatchInit    │    │ MatchPlayController  │
    │ ════════    │    │ ═════════    │    │ ════════════════════ │
    │ Renderiza   │    │ Orquesta     │    │ Maneja INPUT         │
    │ cartas      │    │ inicio de    │    │ Valida acciones      │
    │ Llena slots │    │ partida      │    │ Emite signals        │
    │ Posiciona   │    │ Carga estado │    │ Reconecta UI         │
    └─────────────┘    │ inicial      │    └──────────────────────┘
                       │ Crea          │             │
                       │ GameState     │             ▼
                       └──────────────┘    ┌──────────────────────┐
                                           │ MatchEventBridge     │
                                           │ ════════════════════ │
                                           │ Escucha servidor     │
                                           │ Traduce eventos      │
                                           │ Coordina re-render   │
                                           │ Avisa a controller   │
                                           └──────────────────────┘
```

---

## Ciclo de Vida Completo

```
PASO 1: Inicialización
┌──────────────────────────────────────────────────────┐
│ TestBoard._ready()                                   │
│ - Crear BoardRenderer                               │
│ - Crear MatchInitializer con providers              │
│ - Conectar signals de MatchManager                  │
└──────────────────────────────────────────────────────┘
                    │
                    ▼
PASO 2: Match Iniciado
┌──────────────────────────────────────────────────────┐
│ MatchInitializer.start_match()                       │
│ - Validar deck                                       │
│ - Enviar al servidor                                │
│ - Servidor responde con GameState                   │
└──────────────────────────────────────────────────────┘
                    │
                    ▼
PASO 3: Renderizar + Crear Controllers
┌──────────────────────────────────────────────────────┐
│ TestBoard._on_match_started(GameState)              │
│ - Guardar game_state                                │
│ - Llamar board_renderer.render(game_state)         │
│ - Crear MatchPlayController                         │
│ - Crear MatchEventBridge                            │
│ - Conectar eventos de cartas                        │
└──────────────────────────────────────────────────────┘
                    │
                    ▼
PASO 4: Usuario Juega Carta
┌──────────────────────────────────────────────────────┐
│ CardDisplay (usuario arrastra)                       │
│ - Emite drag_started signal                          │
│ - MatchPlayController escucha                        │
│ - Destaca carta                                      │
│                                                      │
│ CardDisplay (usuario suelta)                         │
│ - Emite drag_ended signal                            │
│ - MatchPlayController valida                         │
│ - Emite card_play_requested                          │
│ - MatchEventBridge escucha                           │
│ - Envía a servidor                                   │
└──────────────────────────────────────────────────────┘
                    │
                    ▼
PASO 5: Servidor Responde
┌──────────────────────────────────────────────────────┐
│ WebSocket Message: match_state_updated               │
│ - GameState actualizado en servidor                 │
│ - MatchManager actualiza game_state local           │
│ - Emite match_state_updated signal                  │
└──────────────────────────────────────────────────────┘
                    │
                    ▼
PASO 6: Re-renderizar
┌──────────────────────────────────────────────────────┐
│ TestBoard._on_match_state_updated()                 │
│ - Llamar board_renderer.render(game_state)         │
│ - Update UI labels (turno, fase, etc)              │
│ - Llamar match_play_controller.setup_card_interactions()
└──────────────────────────────────────────────────────┘
                    │
                    ▼
PASO 7: Re-conectar Eventos
┌──────────────────────────────────────────────────────┐
│ MatchPlayController.setup_card_interactions()        │
│ - Buscar todos los CardDisplay                       │
│ - Conectar drag_started, drag_ended, clicked        │
│ - Guardar CardInstance en mapeo                      │
│ - Listo para siguiente acción                        │
└──────────────────────────────────────────────────────┘
                    │
                    ▼
                VUELVE AL PASO 4
```

---

## Detalle: _on_card_drag_ended (El Momento Crítico)

```
Usuario suelta la carta
    │
    ▼
CardDisplay.drag_ended.emit()
    │
    ▼
MatchPlayController._on_card_drag_ended(card_data, card_display)
    │
    ├─ _detect_drop_zone()
    │   └─ Comparar global_position con rects de slots
    │       └─ Devuelve: "field_knight", "field_technique", etc
    │
    ├─ _detect_drop_slot()
    │   └─ Encontrar índice del slot específico
    │       └─ Devuelve: 0-4
    │
    ├─ _attempt_play_card(card_display, target_zone, target_slot)
    │   │
    │   ├─ Obtener CardInstance de meta
    │   │
    │   ├─ _validate_card_play()
    │   │   ├─ ¿Es tu turno? ✓
    │   │   ├─ ¿Carta en tu mano? ✓
    │   │   └─ ¿Tipo válido para zona? ✓
    │   │
    │   └─ Emitir: card_play_requested(card_instance, zone, slot)
    │
    └─ MatchEventBridge escucha card_play_requested
        └─ Llama: MatchManager.play_card(instance_id, zone, slot)
            └─ MatchManager hace HTTP/WebSocket
                └─ Servidor valida
                    └─ Servidor responde
                        └─ MatchManager actualiza GameState
                            └─ Emite match_state_updated
                                └─ TestBoard re-renderiza
                                    └─ MatchPlayController re-conecta
```

---

## Componentes Principales

### 📊 MatchPlayController Métodos

```
Públicos:
├─ setup_card_interactions()      # Conectar eventos de TODAS las cartas
├─ on_game_state_updated()        # Llamado cuando server actualiza
└─ cleanup()                        # Limpiar conexiones

Internos (Handlers de Eventos):
├─ _on_card_drag_started()        # Usuario comienza arrastrar
├─ _on_card_drag_ended()          # Usuario suelta
├─ _on_card_clicked()             # Usuario hace click
└─ _attempt_play_card()           # Validar + enviar servidor

Validación:
├─ _validate_card_play()          # Validaciones UX
├─ _is_valid_zone_for_card()      # ¿Zona válida para tipo?
├─ _detect_drop_zone()            # ¿En qué zona se soltó?
├─ _detect_drop_slot()            # ¿Qué slot específico?
├─ _is_position_in_rect()         # Helper geométrico
└─ _can_interact()                # ¿Es tu turno?
```

### 🌉 MatchEventBridge Métodos

```
Setup:
└─ setup()                         # Conectar a MatchManager

Handlers (Escucha de Servidor):
├─ _on_card_play_requested()      # Reenvía al servidor
├─ _on_card_played()              # Carta fue jugada OK
├─ _on_card_play_failed()         # Server rechazó
├─ _on_turn_changed()             # Turno cambió
└─ _on_match_state_updated()      # Estado actualizado

Cleanup:
└─ cleanup()                        # Desconectar eventos
```

### 🎨 CardDisplay Signals

```
Emitidas por CardDisplay:
├─ drag_started(card_data)         # Usuario comienza drag
├─ drag_ended(card_data)           # Usuario termina drag
├─ card_clicked(card_data)         # Usuario hace click
└─ card_double_clicked(card_data)  # Usuario doble click
```

---

## Validaciones en Cada Punto

```
PUNTO 1: UX Local (MatchPlayController)
┌─────────────────────────────────────┐
│ ¿Es tu turno?                       │
│ ¿Carta está en tu mano?             │
│ ¿Tipo de carta válido para zona?    │
│ → Si TODO OK → Enviar al servidor   │
└─────────────────────────────────────┘

PUNTO 2: Servidor (Authoritative)
┌─────────────────────────────────────┐
│ ¿Costo de carta asequible?          │
│ ¿Zona no está llena?                │
│ ¿Cartas pre-requeridas disponibles? │
│ Aplicar efectos si es correcto      │
│ → Responder con nuevo GameState     │
└─────────────────────────────────────┘

PUNTO 3: Cliente Valida Respuesta
┌─────────────────────────────────────┐
│ Recibir nuevo GameState             │
│ Verificar que carta está en campo   │
│ Re-renderizar                       │
│ Re-conectar eventos                 │
└─────────────────────────────────────┘
```

---

## Estado de Cartas (CardInstance)

```
CardInstance dentro de meta de CardDisplay:
{
  instance_id: "uuid-1234",          # ID único
  base_data: CardData,                # Datos de carta
  zone: "hand",                       # "hand", "field_knight", etc
  position: 0,                        # Índice en zona
  player_number: 1,                   # Jugador propietario
  mode: "normal",                     # "normal", "defense", "evasion"
  is_exhausted: false,                # ¿Está agotada?
  status_effects: [],                 # Arrays de efectos
  buffs: {}                           # Dict de buffs
}
```

---

## Debugging Rápido

```
Presiona en TestBoard:

┌─────────────────────────────────────────────┐
│ D - Ver diagnostics completos               │
│     ├─ GameState: ✅/❌                    │
│     ├─ BoardRenderer: ✅/❌                │
│     ├─ CardDisplay: cantidad + meta OK      │
│     ├─ MatchPlayController: ✅/❌          │
│     └─ Event Connections: ✅ para cada     │
│                                             │
│ T - Simular drag automático                 │
│     └─ Útil para testing sin ratón          │
│                                             │
│ P - Imprimir estado actual                  │
│     ├─ Turn, Player, Phase                  │
│     ├─ Hand size                            │
│     └─ Can interact: ✅/❌                  │
└─────────────────────────────────────────────┘
```

---

## Estado: ✅ SISTEMA FUNCIONAL

```
✓ Cartas se creen correctamente
✓ Eventos están conectados
✓ Validación funciona
✓ Servidor responde
✓ GameState se actualiza
✓ UI re-renderiza
✓ Eventos se re-conectan

🎮 READY FOR GAMEPLAY
```

**Última actualización:** 23 de Diciembre 2025
