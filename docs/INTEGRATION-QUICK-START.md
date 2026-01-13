# Guía de Integración Rápida - Módulos de Reglas

## Arquitectura Completa de Módulos

```
┌─────────────────────────────────────────────────────┐
│                    GameState                         │
│  (Datos: jugadores, cartas, zonas, cosmos, vida)    │
└────────────────────────┬────────────────────────────┘
                         │
              ┌──────────┴──────────┐
              │                     │
         ┌────▼─────────┐    ┌──────▼────────┐
         │  GameRules   │    │ BattleCalc    │
         │ (Validación) │    │ (Cálculos)    │
         └────┬─────────┘    └──────┬────────┘
              │                     │
              └──────────┬──────────┘
                         │
              ┌──────────▼──────────┐
              │  GameController     │
              │ (Orquestador)       │
              └──────────┬──────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
    ┌────▼────┐   ┌──────▼────┐  ┌──────▼──────┐
    │  Hand    │   │ Field     │  │ Other       │
    │ Manager  │   │ Manager   │  │ Managers    │
    └──────────┘   └───────────┘  └─────────────┘
         │               │
         └───────────────┼─────────────────────┐
                         │                     │
                    ┌────▼──────────┐    ┌────▼────────┐
                    │  GameBoard    │    │ Other UI    │
                    │ (Renderiza)   │    │ Components  │
                    └───────────────┘    └─────────────┘
```

---

## Inicialización (Setup)

### En TestBoard.gd o GameBoard.gd:

```gdscript
func _ready() -> void:
	# 1. Crear instancia de GameState
	game_state = GameState.new()
	game_state.match_id = "test-match-123"
	game_state.current_player = 1
	game_state.current_turn = 1
	game_state.current_phase = "main"
	
	# 2. Crear GameController
	var game_controller = GameController.new()
	game_controller.set_game_state(game_state)
	add_child(game_controller)  # Agregarlo al árbol
	
	# 3. Crear managers
	var hand_manager = HandManager.new()
	hand_manager.set_game_state(game_state)
	add_child(hand_manager)
	
	var field_manager = FieldManager.new()
	field_manager.set_game_state(game_state)
	add_child(field_manager)
	
	# 4. Conectar signals de GameController
	game_controller.card_played.connect(_on_card_played)
	game_controller.attack_declared.connect(_on_attack_declared)
	game_controller.phase_changed.connect(_on_phase_changed)
	
	# 5. Conectar signals de managers
	hand_manager.hand_updated.connect(_on_hand_updated)
	field_manager.field_updated.connect(_on_field_updated)
	
	# 6. Cargar decks y inicializar partida
	await _load_decks_from_server()
	_initialize_game()
```

---

## Flujo de Acción: Jugar una Carta

### 1. Jugador arrastra carta de mano a slot

```gdscript
# En CardSlot.gd
func _on_drop_received(card_display: Control) -> void:
	var card_instance = card_display.get_meta("card_instance")
	var zone = "field_knight"  # Dependiendo del slot
	
	# Llamar GameController para jugar
	if GameController.play_card(card_instance, zone):
		# UI se actualiza automáticamente vía signals
		pass
	else:
		# Mostrar error: "No puedes jugar esta carta"
		pass
```

### 2. GameController.play_card() ejecuta:

```gdscript
# En GameController.gd
func play_card(card_instance: CardInstance, zone: String, position: int = -1) -> bool:
	# Paso 1: VALIDAR
	if not game_rules.can_play_card(card_instance, game_state.get_player_cosmos(current_player)):
		return false
	
	if not game_rules.can_place_card(card_instance, zone, game_state, current_player):
		return false
	
	# Paso 2: EJECUTAR
	game_state.modify_player_cosmos(current_player, -card_instance.base_data.cost)
	game_state.remove_card_from_zone("hand", card_instance.instance_id, current_player)
	game_state.add_card_to_zone(zone, card_instance, position, current_player)
	
	# Paso 3: EMITIR
	card_played.emit(card_instance, zone, position)
	return true
```

### 3. GameBoard escucha el signal:

```gdscript
# En GameBoard.gd
func _on_card_played(card: CardInstance, zone: String, position: int) -> void:
	# Actualizar visual
	var card_display = CardDisplay.new()
	card_display.setup(card.base_data)
	field_manager.place_card_on_field(card, zone, position, game_state.current_player)
	
	# Animar
	CardAnimationManager.animate_card_play(card_display, field_slot)
	
	# Actualizar UI
	_update_cosmos_display()
	_update_hand_display()
```

---

## Flujo de Acción: Atacar

### 1. Jugador clickea botón "Atacar" en caballero

```gdscript
# En GameBoard.gd o CardSlot.gd
func _on_knight_attack_button_pressed(knight_card: CardInstance, target_card: CardInstance) -> void:
	if GameController.declare_attack(knight_card.instance_id, target_card.instance_id):
		# Animación ocurre en signal handler
		pass
	else:
		# Error: "Este caballero no puede atacar"
		pass
```

### 2. GameController.declare_attack() ejecuta:

```gdscript
# En GameController.gd
func declare_attack(attacker_id: String, defender_id: String) -> bool:
	# Validar con GameRules
	var attacker = game_state.get_card_by_instance_id(attacker_id)
	if not game_rules.can_declare_attack(attacker, game_state):
		return false
	
	# Calcular daño con BattleCalculator
	var damage = battle_calculator.calculate_damage(attacker, defender)
	
	# Aplicar daño en GameState
	defender.buffs["hp"] = max(0, current_hp - damage)
	
	# Marcar atacante como exhausto
	attacker.is_exhausted = true
	
	# Emitir signal
	attack_declared.emit(attacker_id, defender_id, damage)
	return true
```

### 3. GameBoard anima el ataque:

```gdscript
# En GameBoard.gd
func _on_attack_declared(attacker_id: String, defender_id: String, damage: int) -> void:
	var attacker = field_manager.get_card_by_id(attacker_id, game_state.current_player)
	var defender = field_manager.get_card_by_id(defender_id, 3 - game_state.current_player)
	
	# Animar ataque
	CardAnimationManager.animate_attack(attacker, defender, damage)
	
	# Efecto visual de daño
	MatchEffectsManager.spawn_damage_number(defender, damage)
	
	# Actualizar vidas/cosmos en UI
	_update_player_stats()
```

---

## Métodos Más Comunes

### GameState (Lectura)

```gdscript
# Obtener información
var my_hand = game_state.get_hand_for_player(1)
var my_cosmos = game_state.get_player_cosmos(1)
var my_life = game_state.get_player_life(1)
var my_knights = game_state.get_cards_in_zone("field_knight", 1)

# Buscar carta
var card = game_state.get_card_by_instance_id("card-123")
var player_owning_card = game_state.get_player_of_card("card-123")
```

### GameRules (Validación)

```gdscript
# ¿Puedo jugar esta carta?
if GameRules.can_play_card(card, current_cosmos):
	print("✓ Puedo jugar")

# ¿Dónde puedo colocar esta carta?
if GameRules.can_place_card(card, "field_knight", game_state, my_player):
	print("✓ Puedo colocar aquí")

# ¿Puedo atacar con este caballero?
if GameRules.can_declare_attack(knight, game_state):
	print("✓ Puedo atacar")

# ¿Puedo usar esta técnica?
if GameRules.can_use_technique(technique, knight, game_state):
	print("✓ Puedo usar técnica")
```

### GameController (Ejecución)

```gdscript
# Jugar carta
GameController.play_card(card, "field_knight", 0)

# Atacar
GameController.declare_attack(attacker_id, defender_id)

# Usar técnica
GameController.use_technique(technique_id, activator_id, [target_id])

# Acción especial
GameController.execute_knight_action(knight_id, "carregar_cosmo")

# Terminar turno
GameController.end_turn()
```

### HandManager (Gestión de Mano)

```gdscript
# Agregar/quitar
HandManager.add_card_to_hand(card, 1)
HandManager.remove_card_from_hand(card_id, 1)

# Consultar
var hand = HandManager.get_cards_in_hand(1)
var playable = HandManager.get_playable_cards(1, current_cosmos)
var count = HandManager.get_hand_size(1)

# Búsqueda
var card = HandManager.get_card_by_id(card_id, 1)
var pos = HandManager.get_card_position_in_hand(card_id, 1)

# Ordenar
HandManager.sort_hand_by_cost(1)  # Menor a mayor
HandManager.sort_hand_by_type(1)  # Agrupar por tipo
```

### FieldManager (Gestión de Campo)

```gdscript
# Colocar/quitar
FieldManager.place_card_on_field(card, "field_knight", 0, 1)
FieldManager.remove_card_from_field(card_id, "field_knight", 1)

# Consultar
var knights = FieldManager.get_knights_on_field(1)
var active = FieldManager.get_active_knights(1)
var techniques = FieldManager.get_techniques_on_field(1)

# Validación
if FieldManager.can_place_knight(1):
	print("Hay espacio para otro caballero")

# Búsqueda
var card = FieldManager.get_card_by_id(card_id, 1)
var zone = FieldManager.get_card_zone(card_id, 1)

# Helper/Scenario
var helper = FieldManager.get_helper_card(1)
var scenario = FieldManager.get_scenario_card(1)
```

---

## Ejemplo Completo: Turno Jugador 1

```gdscript
# Fase 1: DRAW
GameController.end_turn()  # Automáticamente roba una carta

# Fase 2: MAIN - Jugar cartas
var playable = HandManager.get_playable_cards(1, game_state.get_player_cosmos(1))
if playable.size() > 0:
	var card_to_play = playable[0]
	GameController.play_card(card_to_play, "field_knight", 0)

# Fase 3: BATTLE - Atacar
var my_knights = FieldManager.get_active_knights(1)
var opponent_knights = FieldManager.get_knights_on_field(2)

if my_knights.size() > 0 and opponent_knights.size() > 0:
	GameController.declare_attack(my_knights[0].instance_id, opponent_knights[0].instance_id)

# Fase 4: END - Terminar turno
GameController.end_turn()  # Cambia a jugador 2
```

---

## Signals a los que Escuchar

### De GameController

```gdscript
# Juego en general
GameController.card_played.connect(_on_card_played)          # Carta jugada
GameController.attack_declared.connect(_on_attack_declared)  # Ataque
GameController.technique_used.connect(_on_technique_used)    # Técnica
GameController.knight_action_executed.connect(...)           # Acción
GameController.player_took_damage.connect(...)               # Daño
GameController.phase_changed.connect(_on_phase_changed)      # Cambio fase
```

### De HandManager

```gdscript
HandManager.card_added_to_hand.connect(_on_hand_card_added)
HandManager.card_removed_from_hand.connect(_on_hand_card_removed)
HandManager.hand_updated.connect(_on_hand_updated)
HandManager.hand_limit_reached.connect(_on_hand_full)
```

### De FieldManager

```gdscript
FieldManager.card_placed_on_field.connect(_on_field_card_placed)
FieldManager.card_removed_from_field.connect(_on_field_card_removed)
FieldManager.field_updated.connect(_on_field_updated)
FieldManager.zone_full.connect(_on_zone_full)
```

---

## Testing en TestBoard

### Cargar el módulo en TestBoard.gd:

```gdscript
# En _ready():
var game_controller = GameController.new()
game_controller.set_game_state(game_state)

# En un botón de test:
func _on_test_play_card():
	var hand = game_state.get_hand_for_player(1)
	if hand.size() > 0:
		var card = hand[0]
		game_controller.play_card(card, "field_knight", 0)
		print("✓ Carta jugada: %s" % card.base_data.name)

func _on_test_attack():
	var my_knights = game_state.get_cards_in_zone("field_knight", 1)
	var opp_knights = game_state.get_cards_in_zone("field_knight", 2)
	
	if my_knights.size() > 0 and opp_knights.size() > 0:
		game_controller.declare_attack(my_knights[0].instance_id, opp_knights[0].instance_id)
		print("✓ Ataque ejecutado")
```

---

## Notas Importantes

1. **GameState es lectura**: Solo GameController modifica su estado
2. **GameRules es puro**: No modifica estado, solo valida
3. **BattleCalculator es puro**: Solo calcula, no modifica cartas
4. **Managers coordinan**: HandManager y FieldManager coordinan con GameState vía GameController
5. **Signals desaclopan**: UI escucha signals, no accede directamente a GameController

---

**Última actualización**: Después de crear GameRules, BattleCalculator, GameController, HandManager, FieldManager
