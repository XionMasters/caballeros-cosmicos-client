# ⚡ Energy Reservation Pattern - Arquitectura Correcta

**Status:** ✅ Implementado
**Pattern:** Server-Authoritative + Client Optimistic

---

## El Problema

Consumir energía directamente es peligroso:

```gdscript
# ❌ INCORRECTO
player_cosmos -= cost        # Consume local
send_to_server(card)         # Envía al servidor
# Si el servidor rechaza → energía perdida (desfasado)
```

---

## La Solución: Energy Reservation

```gdscript
# ✅ CORRECTO
player_cosmos -= cost                    # Consume local
_pending_energy_costs.append(entry)      # Guarda en pending
send_to_server(card)                     # Envía al servidor

# Cuando llega respuesta:
if server_accepted:
    _confirm_pending_energy(card)        # ✅ Elimina del pending
else:
    _revert_pending_energy(card)         # ⚠️ Devuelve energía
```

---

## Flujo Completo

```
1️⃣ Usuario arrastra carta
   ↓
2️⃣ CardSlot emite card_dropped(card_instance)
   ↓
3️⃣ MatchPlayController recibe
   ├─ _validate_energy_cost()     → ¿Hay suficiente? (NO MODIFICA estado)
   │                                 ✅ SI → continúa
   │                                 ❌ NO → BLOQUEA
   ├─ _attempt_play_card_in_slot()
   │  ├─ card_play_requested.emit()  → Envía intención al servidor
   │  └─ _reserve_energy()           → Resta cosmos + guarda pending
   │     • player_cosmos -= cost
   │     • _pending_energy_costs.append({card_id, cost, timestamp})
   │
4️⃣ Servidor procesa
   ├─ ✅ ACEPTADO → responde con OK
   │  └─ Cliente recibe GameState
   │     └─ on_game_state_updated()
   │        └─ _confirm_pending_energy()    ← AQUÍ
   │           • _pending_energy_costs.remove(card_id)
   │           • Log: "Energía CONFIRMADA"
   │
   └─ ❌ RECHAZADO → responde con ERROR
      └─ Cliente recibe error
         └─ _revert_pending_energy()       ← O AQUÍ
            • player_cosmos += cost
            • _pending_energy_costs.remove(card_id)
            • Log: "Energía REVERTIDA"
```

---

## Fuente de Verdad: CardInstance

**Priority order:**

```gdscript
# 1️⃣ FUENTE DE VERDAD
var cost = card_instance.base_data.cost  (CardData.cost)

# 2️⃣ FALLBACK (si CardInstance no tiene costo)
var cost = card_display.get_data().cost   (CardDisplay UI data)
```

**Por qué:**
- CardInstance viene del servidor (fuente de verdad)
- CardDisplay es solo UI (puede estar desactualizada, ser mock, etc)
- Validación siempre usa CardInstance cuando es posible

---

## Métodos Implementados

### `_validate_energy_cost(card_instance, card_display) -> bool`
✅ **Valida sin modificar estado**
- Lee `player_cosmos` y `card_cost`
- Retorna `true` si `player_cosmos >= card_cost`
- Retorna `false` si no hay suficiente
- **No modifica nada**

### `_reserve_energy(card_instance, card_display) -> bool`
⚠️ **Modifica estado localmente**
- Resta `player_cosmos -= cost`
- Guarda en `_pending_energy_costs`
- Log: "Energía RESERVADA"
- Retorna `true` si éxito

### `_confirm_pending_energy(card_instance) -> void`
✅ **Confirma después del ACK**
- Busca en `_pending_energy_costs` por `card_id`
- Elimina del array (limpia pending)
- Log: "Energía CONFIRMADA"
- **No modifica cosmos** (ya fue restado)

### `_revert_pending_energy(card_instance) -> void`
⚠️ **Revierte si el servidor rechaza**
- Busca en `_pending_energy_costs` por `card_id`
- Suma `player_cosmos += cost` (devuelve energía)
- Elimina del array (limpia pending)
- Log: "Energía REVERTIDA"

---

## Estados Posibles

### Cosmos Pendientes
```
_pending_energy_costs = [
    {card_id: "abc", card_name: "Shiryu", cost: 3, timestamp: 1234567},
    {card_id: "def", card_name: "Hyoga", cost: 2, timestamp: 1234568}
]

# Total pendiente: 5
# Cosmos real: player_cosmos (ya incluye pendientes restados)
# Cosmos disponible: player_cosmos (no restes esto nuevamente!)
```

---

## Logs Esperados

**Caso exitoso:**
```
[MatchPlayController] ⚡ Validando energía: tengo=10, costo=3
[MatchPlayController] ✅ Energía válida
[MatchPlayController] ✅ Enviando al servidor: Shiryu → field_knight[0]
[MatchPlayController] ⚡ Energía RESERVADA: 3 (pending: 1, cosmos: 7)
[ServerResponse] ✅ Play aceptado
[MatchPlayController] ⚡ Energía CONFIRMADA: Shiryu (3 cosmos)
```

**Caso rechazado:**
```
[MatchPlayController] ⚡ Validando energía: tengo=10, costo=3
[MatchPlayController] ✅ Energía válida
[MatchPlayController] ✅ Enviando al servidor: Shiryu → field_knight[0]
[MatchPlayController] ⚡ Energía RESERVADA: 3 (pending: 1, cosmos: 7)
[ServerResponse] ❌ Play rechazado: slot occupied
[MatchPlayController] ⚡ Energía REVERTIDA: Shiryu (3 cosmos devueltos → total: 10)
```

**Caso sin energía:**
```
[MatchPlayController] ⚡ Validando energía: tengo=2, costo=3
[MatchPlayController] ❌ Energía insuficiente! Necesitas 3, tienes 2
```

---

## Arquitectura UI

Perfect flow respecto a lo que vos mencionaste:

```
┌─────────────────────────────────────┐
│          USUARIO (UI)               │
│  → Arrastra carta (intención)       │
└────────────────┬────────────────────┘
                 │
┌────────────────▼────────────────────┐
│       CARDSLOT (Detector)           │
│  → Emite card_dropped(card_instance)│
└────────────────┬────────────────────┘
                 │
┌────────────────▼──────────────────────────────┐
│    MATCHPLAYCONTROLLER (Regulador)           │
│  → Valida reglas (energía, tipos, etc)       │
│  → Propone intención al servidor             │
│  → Maneja ciclo de vida de energía           │
└────────────────┬──────────────────────────────┘
                 │
┌────────────────▼──────────────────────────────┐
│    SERVIDOR (Árbitro/Fuente de Verdad)       │
│  → Valida todo nuevamente                    │
│  → Aplica reglas del juego                   │
│  → Responde: ✅ aceptado o ❌ rechazado      │
│  → Envía GameState actualizado               │
└────────────────┬──────────────────────────────┘
                 │
┌────────────────▼──────────────────────────────┐
│    CLIENT (Sincroniza)                       │
│  → Recibe GameState                          │
│  → Confirma/Revierte energía según respuesta │
│  → Re-renderiza UI                           │
└──────────────────────────────────────────────┘
```

**Separación de responsabilidades:**
- **UI**: Propone (emite intención)
- **Controlador**: Decide reglas locales (valida, reserva energía)
- **Servidor**: Decide verdad (ÚNICO que puede modificar estado permanente)

---

## Próximos Pasos

🟢 Energy Reservation implementado
🟢 Validación con fuente de verdad (CardInstance)
⏳ Conectar `_confirm_pending_energy()` cuando llega respuesta del servidor
⏳ Conectar `_revert_pending_energy()` cuando el servidor rechaza

La estructura está lista. Solo falta conectar estos métodos con MatchEventBridge/GameState updates.

