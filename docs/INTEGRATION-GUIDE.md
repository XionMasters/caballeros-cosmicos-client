# GUÍA DE INTEGRACIÓN: Nuevos Managers en GameBoard

**Fecha**: Diciembre 15, 2025
**Versión**: 1.0

---

## 📋 Resumen de Nuevos Managers

| Manager | Propósito | Archivo | Estado |
|---------|----------|---------|--------|
| `DeckLoadingManager` | Cargar mazo async, deduplicar imágenes | `scripts/managers/DeckLoadingManager.gd` | ✅ Listo |
| `CardCostValidator` | Validar costos de cartas, gestionar recursos | `scripts/game/CardCostValidator.gd` | ✅ Listo |
| `CardPlayManager` | Orquestar jugar cartas (validación + servidor) | `scripts/game/CardPlayManager.gd` | ✅ Listo |
| `PlayerState` | Gestionar estado del jugador (cosmos, HP, etc) | `scripts/models/PlayerState.gd` | ✅ Listo |
| `CardDisplayFactory` | Factory para crear CardDisplay sin duplicación | `scripts/factories/CardDisplayFactory.gd` | ✅ Listo |
| `CardAnimationManager` | Gestionar todas las animaciones de cartas | `scripts/managers/CardAnimationManager.gd` | ✅ Listo |
| `SlotGroup` | Gestionar grupos de slots unificados | `scripts/models/SlotGroup.gd` | ✅ Listo |

---

## 🔧 Integración en GameBoard.gd

### 1. Declaraciones de Variables (arriba del archivo)

```gdscript
# Managers
var deck_loader: DeckLoadingManager = null
var card_play_manager: CardPlayManager = null
var animation_manager: CardAnimationManager = null
var card_factory: CardDisplayFactory = null

# Estado del jugador
var player_state: PlayerState = null
var opponent_state: PlayerState = null

# Slot groups (nuevo sistema unificado)
var player_knight_slots_group: SlotGroup = null
var player_technique_slots_group: SlotGroup = null
var opponent_knight_slots_group: SlotGroup = null
var opponent_technique_slots_group: SlotGroup = null
```

### 2. Setup en `_ready()` o `_initialize_match()`

```gdscript
func _initialize_match() -> void:
	# Inicializar managers
	_setup_managers()
	
	# Inicializar estado del jugador
	_setup_player_states()
	
	# Inicializar slot groups
	_setup_slot_groups()
	
	# Cargar mazo
	_load_deck()
	
	# Conectar señales
	_connect_signals()


func _setup_managers() -> void:
	# Deck loader
	deck_loader = DeckLoadingManager.new()
	add_child(deck_loader)
	
	# Card play manager
	card_play_manager = CardPlayManager.new()
	add_child(card_play_manager)
	
	# Animation manager
	animation_manager = CardAnimationManager.new()
	add_child(animation_manager)
	
	# Card factory
	card_factory = CardDisplayFactory.new(CARD_DISPLAY_SCENE, CARD_BACK_TEMPLATE)


func _setup_player_states() -> void:
	# Crear estado para cada jugador
	player_state = PlayerState.new("player-1", 1)
	player_state.max_cosmos = 10
	player_state.current_cosmos = 3  # Comenzar con 3 cosmos
	player_state.current_health = 20
	
	opponent_state = PlayerState.new("opponent-1", 2)
	opponent_state.max_cosmos = 10
	opponent_state.current_cosmos = 3
	opponent_state.current_health = 20
	
	# Conectar señales
	player_state.cosmos_changed.connect(_on_player_cosmos_changed)
	player_state.health_changed.connect(_on_player_health_changed)
	opponent_state.cosmos_changed.connect(_on_opponent_cosmos_changed)
	opponent_state.health_changed.connect(_on_opponent_health_changed)


func _setup_slot_groups() -> void:
	# Crear groups para cada tipo de slot
	player_knight_slots_group = SlotGroup.new("knights", 5)
	player_knight_slots_group.initialize_from_nodes(player_knight_slots)
	
	player_technique_slots_group = SlotGroup.new("techniques", 5)
	player_technique_slots_group.initialize_from_nodes(player_technique_slots)
	
	opponent_knight_slots_group = SlotGroup.new("knights", 5)
	opponent_knight_slots_group.initialize_from_nodes(opponent_knight_slots)
	
	opponent_technique_slots_group = SlotGroup.new("techniques", 5)
	opponent_technique_slots_group.initialize_from_nodes(opponent_technique_slots)


func _load_deck() -> void:
	# Usar DeckLoadingManager para cargar mazo
	await deck_loader.fetch_and_load_active_deck()
	
	# Dibujar mano inicial
	_draw_initial_hand()


func _draw_initial_hand() -> void:
	# Obtener 7 cartas del mazo
	var initial_cards = deck_loader.draw_cards_from_deck(7)
	
	# Crear CardDisplay para cada carta
	var card_displays = await card_factory.create_batch(initial_cards, true)
	
	# Agregar a la mano
	for card_display in card_displays:
		player_hand.add_card(card_display)
		
		# Conectar señales de click
		card_display.card_clicked.connect(_on_card_clicked_from_hand.bind(card_display))
```

### 3. Señales de PlayerState

```gdscript
func _on_player_cosmos_changed(new_amount: int, old_amount: int) -> void:
	# Actualizar UI de cosmos
	player_cosmos_label.text = str(new_amount)
	player_cosmos_bar.value = new_amount
	
	# Efecto visual
	animation_manager.animate_mode_change(cosmos_label, "change", 0.2)


func _on_player_health_changed(new_amount: int, old_amount: int) -> void:
	# Actualizar UI de HP
	player_health_label.text = str(new_amount)
	player_health_bar.value = new_amount
	
	# Efecto si recibió daño
	if new_amount < old_amount:
		animation_manager.animate_take_damage(player_avatar, 0.3)


func _on_opponent_cosmos_changed(new_amount: int, old_amount: int) -> void:
	opponent_cosmos_label.text = str(new_amount)
	opponent_cosmos_bar.value = new_amount


func _on_opponent_health_changed(new_amount: int, old_amount: int) -> void:
	opponent_health_label.text = str(new_amount)
	opponent_health_bar.value = new_amount
```

### 4. Manejador de Click de Cartas (USA CardPlayManager)

```gdscript
func _on_card_clicked_from_hand(card_display: Control) -> void:
	var card_instance = card_display.get_meta("card_instance") as CardInstance
	
	if not card_instance:
		return
	
	# Validar que pueda jugar la carta
	var can_play = card_play_manager.can_play_card(
		card_instance,
		player_state.current_cosmos
	)
	
	if not can_play:
		print("No puedo jugar esta carta")
		return
	
	# Determinar zona según tipo de carta
	var zone = "field_knight" if card_instance.base_data.type == "knight" else "field_technique"
	var slot_group = player_knight_slots_group if zone == "field_knight" else player_technique_slots_group
	
	# Obtener primer slot vacío
	var target_slot = slot_group.get_first_empty_slot()
	if not target_slot:
		push_warning("No hay slots disponibles para %s" % zone)
		return
	
	# Jugar la carta (valida, envía servidor, actualiza UI)
	card_play_manager.play_card_to_field(
		card_instance,
		zone,
		target_slot.slot_index
	)


func _on_card_play_manager_card_played(card_instance: CardInstance, success: bool) -> void:
	if success:
		# Restar cosmos del jugador
		player_state.subtract_cosmos(card_instance.base_data.cost)
		
		# Animar carta
		var card_display = _find_card_display_by_instance(card_instance)
		if card_display:
			# Obtener posición del slot
			var slot = _find_slot_for_instance(card_instance)
			if slot:
				animation_manager.animate_card_play(card_display, slot.global_position)
			
			# Remover de mano
			player_hand.remove_card(card_display)
	else:
		print("Error al jugar carta")
```

### 5. Usar Animaciones

```gdscript
# Cuando se dibuja una carta
func _draw_card_from_deck(card_instance: CardInstance) -> void:
	var card_display = card_factory.create_from_instance(card_instance, Vector2.ZERO, false)
	
	# Animar desde el mazo
	animation_manager.animate_flip_from_deck(
		card_display,
		player_deck.global_position,
		player_hand.global_position
	)
	
	player_hand.add_card(card_display)


# Cuando se descarta una carta
func _discard_card(card_instance: CardInstance) -> void:
	var card_display = _find_card_display_by_instance(card_instance)
	
	if card_display:
		animation_manager.animate_card_discard(
			card_display,
			discard_pile.global_position
		)
		
		player_hand.remove_card(card_display)


# Cuando una carta ataca
func _card_attacks(attacker: CardInstance, defender: CardInstance, damage: int) -> void:
	var attacker_display = _find_card_display_by_instance(attacker)
	var defender_display = _find_card_display_by_instance(defender)
	
	if attacker_display:
		var target_pos = defender_display.global_position if defender_display else Vector2.ZERO
		animation_manager.animate_attack_pulse(attacker_display, target_pos)
	
	if defender_display:
		animation_manager.animate_take_damage(defender_display)
		
		# Actualizar HP
		if attacker.player_number == 1:
			opponent_state.take_damage(damage)
		else:
			player_state.take_damage(damage)
```

### 6. Usar SlotGroups para Validación

```gdscript
func _can_place_card_in_slot(card_instance: CardInstance, slot_type: String) -> bool:
	var slot_group: SlotGroup = null
	
	if slot_type == "knights":
		slot_group = player_knight_slots_group
	elif slot_type == "techniques":
		slot_group = player_technique_slots_group
	else:
		return false
	
	# Verificar si hay slots disponibles
	if slot_group.is_full():
		return false
	
	# Validaciones específicas según tipo
	if slot_type == "knights":
		# Validar stats mínimos
		var knight_data = card_instance.base_data as CardKnightData
		if knight_data and knight_data.power < 3:
			return false
	
	return true


func _get_slot_status() -> String:
	var status = ""
	status += player_knight_slots_group.get_debug_status() + "\n"
	status += player_technique_slots_group.get_debug_status() + "\n"
	status += opponent_knight_slots_group.get_debug_status() + "\n"
	status += opponent_technique_slots_group.get_debug_status()
	return status
```

---

## 📊 Comparación: Antes vs Después

### Antes (Código Duplicado)

```gdscript
# Cargar mazo (50 líneas)
func _on_decks_loaded(decks):
	var active_deck = decks[0]
	# ... 48 más líneas de setup ...

# Conectar slots manualmente (50 líneas)
func _connect_all_slots():
	for slot in player_knight_slots:
		slot.card_placed.connect(_on_card_placed_in_slot)
		slot.card_removed.connect(_on_card_removed_from_slot)
	for slot in player_technique_slots:
		slot.card_placed.connect(_on_card_placed_in_slot)
		slot.card_removed.connect(_on_card_removed_from_slot)
	# ... repetir para opponent ...

# Animar cartas (código mezclado en CardDisplay)
func play_card(card_display, slot):
	card_display.get_node("Tween").kill()
	var tween = create_tween()
	# ... 20 líneas de código de animación ...
```

### Después (Código Genérico)

```gdscript
# Cargar mazo (1 línea)
await deck_loader.fetch_and_load_active_deck()

# Conectar slots (4 líneas)
player_knight_slots_group.connect_signal_all("card_placed", _on_card_placed)
player_technique_slots_group.connect_signal_all("card_placed", _on_card_placed)
opponent_knight_slots_group.connect_signal_all("card_placed", _on_card_placed)
opponent_technique_slots_group.connect_signal_all("card_placed", _on_card_placed)

# Animar cartas (1 línea)
animation_manager.animate_card_play(card_display, target_position)
```

**Reducción de código**: ~150 líneas eliminadas, 0 duplicación

---

## ✅ Checklist de Integración

- [ ] Declarar variables de managers en GameBoard.gd
- [ ] Crear `_initialize_match()` y `_setup_managers()`
- [ ] Crear `_setup_player_states()`
- [ ] Crear `_setup_slot_groups()`
- [ ] Actualizar `_load_deck()` para usar DeckLoadingManager
- [ ] Actualizar `_draw_initial_hand()` para usar CardDisplayFactory
- [ ] Crear manejadores de señales de PlayerState
- [ ] Actualizar `_on_card_clicked_from_hand()` para usar CardPlayManager
- [ ] Actualizar métodos de animación para usar CardAnimationManager
- [ ] Testear flujo completo: login → mazo carga → dibujar → jugar carta
- [ ] Verificar que todos los managers se inicializan sin errores
- [ ] Verificar que las señales se conectan correctamente

---

## 🐛 Debugging

### Imprimir estado de SlotGroups
```gdscript
print(player_knight_slots_group.get_debug_status())
# Output: KNIGHTS: 2/5 (■■□□□)
```

### Imprimir recursos del jugador
```gdscript
print("Cosmos: %d/%d" % [player_state.current_cosmos, player_state.max_cosmos])
print("HP: %d/%d" % [player_state.current_health, player_state.max_health])
```

### Listar tweens activas
```gdscript
print("Tweens activas: %d" % animation_manager.active_tweens.size())
```

---

## 🚀 Próximos Pasos

1. **Integración de GameBoard** (AHORA)
   - Copiar y pegar código de secciones 1-6
   - Testear que compile sin errores
   - Testear que el mazo carga correctamente

2. **Integración de Servidor** (Próxima sesión)
   - Verificar endpoint `/api/combat/play-card` existe
   - Verificar respuesta correcta del servidor
   - Testear validación de costos en servidor

3. **UI Feedback** (Próxima sesión)
   - Conectar cosmos_changed a label UI
   - Conectar health_changed a barra HP
   - Mostrar mensajes de error (sin cosmos, etc)

4. **Audio & Effects** (Fase siguiente)
   - Reproducir sonido al jugar carta
   - Reproducir sonido al cambiar cosmos
   - Reproducir sonido al cambiar modo batalla

---

**Archivo generado por**: Refactorización automática
**Mantenedor**: GitHub Copilot
**Última actualización**: Diciembre 15, 2025

