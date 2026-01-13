# Cambios: Visualización de Mazos y Mano del Oponente

## Resumen

Se implementaron DeckDisplay para los mazos y HandLayout para la mano del oponente, mostrando dorsos de cartas en lugar de solo contadores numéricos.

---

## Cambios en GameBoard.tscn

### 1. Recursos Adicionales (Load Steps)

```gdscript
[ext_resource type="Script" path="res://scripts/models/DeckDisplay.gd" id="8_deckdisplay"]
[ext_resource type="PackedScene" uid="uid://bkm3xrw8qaa" path="res://scenes/ui/CardBack.tscn" id="9_cardback"]
```

### 2. PlayerDeck - De Panel+Label a DeckDisplay

**Antes:**
```gdscript
[node name="DeckPile" type="Panel" parent="...PlayerDeck"]
custom_minimum_size = Vector2(80, 120)
layout_mode = 2
tooltip_text = "Tu Mazo"

[node name="Count" type="Label" parent="...PlayerDeck/DeckPile"]
# ... configuración de Label centrado
text = "40"
```

**Después:**
```gdscript
[node name="DeckPile" type="Control" parent="...PlayerDeck"]
custom_minimum_size = Vector2(80, 120)
layout_mode = 2
tooltip_text = "Tu Mazo"
script = ExtResource("8_deckdisplay")
card_back_scene = ExtResource("9_cardback")
```

### 3. OpponentDeck - De Panel+Label a DeckDisplay

**Antes:**
```gdscript
[node name="DeckPile" type="Panel" parent="...OpponentDeck"]
custom_minimum_size = Vector2(80, 120)
layout_mode = 2
tooltip_text = "Mazo Oponente"

[node name="Count" type="Label" parent="...OpponentDeck/DeckPile"]
# ... configuración de Label centrado
text = "40"
```

**Después:**
```gdscript
[node name="DeckPile" type="Control" parent="...OpponentDeck"]
custom_minimum_size = Vector2(80, 120)
layout_mode = 2
tooltip_text = "Mazo Oponente"
script = ExtResource("8_deckdisplay")
card_back_scene = ExtResource("9_cardback")
```

### 4. OpponentHand - De Control vacío a HandLayout

**Antes:**
```gdscript
[node name="OpponentHand" type="Control" parent="...OpponentHeader"]
layout_mode = 2
size_flags_horizontal = 3
```

**Después:**
```gdscript
[node name="OpponentHand" type="Control" parent="...OpponentHeader"]
custom_minimum_size = Vector2(0, 180)
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 1
script = ExtResource("5_handlayout")
card_width = 100.0
max_total_width = 700.0
card_scale = 0.7
hover_scale = 0.7        # Sin hover (oponente)
hover_offset_y = 0.0     # Sin elevación
```

---

## Cambios en GameBoard.gd

### 1. Referencias a Nodos Actualizadas

**Antes:**
```gdscript
@onready var player_deck_count = $MainContainer/LeftColumn/PlayerDeck/DeckPile/Count
@onready var opponent_deck_count = $MainContainer/LeftColumn/OpponentDeck/DeckPile/Count
```

**Después:**
```gdscript
@onready var player_deck = $MainContainer/LeftColumn/PlayerDeck/DeckPile
@onready var opponent_hand = $MainContainer/CenterColumn/OpponentArea/OpponentHeader/OpponentHand
@onready var opponent_deck = $MainContainer/LeftColumn/OpponentDeck/DeckPile
```

### 2. Método `_update_pile_counts()` - Usar `set_count()` en DeckDisplay

**Antes:**
```gdscript
player_deck_count.text = str(current_match.get("player1_deck_size", 40))
opponent_deck_count.text = str(current_match.get("player2_deck_size", 40))
```

**Después:**
```gdscript
player_deck.set_count(current_match.get("player1_deck_size", 40))
opponent_deck.set_count(current_match.get("player2_deck_size", 40))
```

### 3. Método `render_all_zones()` - Agregar Renderizado de Mano del Oponente

**Antes:**
```gdscript
# Renderizar mano del jugador
for card_instance in game_state.player_hand:
    _add_card_to_hand(card_instance)

# Renderizar caballeros del jugador
```

**Después:**
```gdscript
# Renderizar mano del jugador
for card_instance in game_state.player_hand:
    _add_card_to_hand(card_instance)

# Renderizar mano del oponente (solo dorsos)
_render_opponent_hand(game_state.opponent_hand_count)

# Renderizar caballeros del jugador
```

### 4. Método `_clear_all_zones()` - Limpiar Mano del Oponente

**Antes:**
```gdscript
# Limpiar mano del jugador
if player_hand.has_method("clear_cards"):
    player_hand.clear_cards()
else:
    for child in player_hand.get_children():
        child.queue_free()
```

**Después:**
```gdscript
# Limpiar mano del jugador
if player_hand.has_method("clear_cards"):
    player_hand.clear_cards()
else:
    for child in player_hand.get_children():
        child.queue_free()

# Limpiar mano del oponente
if opponent_hand.has_method("clear_cards"):
    opponent_hand.clear_cards()
else:
    for child in opponent_hand.get_children():
        child.queue_free()
```

### 5. Nuevo Método: `_render_opponent_hand()`

```gdscript
func _render_opponent_hand(card_count: int):
    """Renderizar mano del oponente como dorsos de carta"""
    # Limpiar primero
    if opponent_hand.has_method("clear_cards"):
        opponent_hand.clear_cards()
    
    # Agregar dorsos según la cantidad de cartas
    for i in range(card_count):
        var card_back = CARD_BACK_TEMPLATE.instantiate()
        opponent_hand.add_card(card_back)
```

---

## Resultado Visual

### PlayerDeck / OpponentDeck
- ✅ Muestra stack de hasta 3 dorsos superpuestos (con offset de 6px)
- ✅ Contador numérico superpuesto en el centro
- ✅ Actualización automática con `set_count()`
- ✅ Usa `DeckDisplay` (extends `CardCollection`)

### OpponentHand
- ✅ Muestra dorsos de cartas (cantidad desde `game_state.opponent_hand_count`)
- ✅ Layout horizontal con HandLayout
- ✅ Cartas más pequeñas (`card_width=100`, `card_scale=0.7`)
- ✅ Sin hover ni elevación (oponente no interactúa)
- ✅ Se actualiza automáticamente cuando cambia el estado del match

### PlayerHand (Sin cambios, pero para referencia)
- ✅ Muestra cartas conocidas con datos completos
- ✅ Layout horizontal con hover y drag & drop
- ✅ `card_width=120`, `card_scale=0.85`, `hover_scale=1.1`

---

## Integración con GameState

El `GameState` ya provee:
- `game_state.opponent_hand_count` - Cantidad de cartas en mano del oponente
- `game_state.player_deck_count` / `game_state.opponent_deck_count` - Contadores de mazos

Estos valores se obtienen del servidor en la respuesta de `match_state`:
```json
{
  "player1_hand_count": 5,
  "player2_hand_count": 3,
  "player1_deck_size": 35,
  "player2_deck_size": 32
}
```

---

## Dependencias

### DeckDisplay.gd
- Requiere `card_back_scene` asignado en el editor (res://scenes/ui/CardBack.tscn)
- Extiende `CardCollection`
- Propiedades:
  - `max_visible_cards: int = 3`
  - `stack_offset: float = 6.0`
  - `show_counter: bool = true`

### CardBack.tscn / CardBack.gd
- Tamaño: 80x120 (proporción 2:3)
- Cache global de textura (una sola descarga HTTP para todas las instancias)
- Descarga automática de `/assets/cards/card_back.png` del servidor
- Fallback: Color sólido si falla la descarga

### HandLayout.gd
- Extiende `CardCollection`
- Acepta cualquier nodo hijo (CardDisplay o CardBack)
- Layout horizontal con solapamiento automático
- Centrado automático

---

## Próximos Pasos (Opcional)

1. **Animaciones de Robo**: Animar `pop_card_back()` del mazo cuando se roba
2. **Yomotsu/Cositos con DeckDisplay**: Convertir esos paneles también
3. **Animación de Descarte**: Transición de mano → yomotsu
4. **Sonidos**: Efecto de sonido al robar/descartar

---

## Testing

Para probar:
1. Iniciar partida desde `MatchSearch`
2. Observar los mazos (stack de dorsos + contador)
3. Observar mano del oponente (dorsos horizontales)
4. Robar cartas → contador y dorsos se actualizan
5. Verificar que `game_state.opponent_hand_count` se sincroniza correctamente
