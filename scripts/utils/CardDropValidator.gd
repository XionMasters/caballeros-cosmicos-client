# CardDropValidator.gd - Validación de drops basada en criterios
# Permite agregar reglas personalizadas para qué cartas pueden ir a dónde
extends Node
class_name CardDropValidator

# Drop zone rules: zone_name -> validation function
var zone_rules: Dictionary = {}

# Predefined validators
enum ValidationType {
	ALLOW_ALL,
	BY_RARITY,
	BY_TYPE,
	BY_ELEMENT,
	BY_COST,
	CUSTOM
}


func _init() -> void:
	# Setup default rules (ALLOW_ALL by default)
	pass


## Add custom validation rule for a zone
func add_rule(zone_name: String, validation_func: Callable) -> void:
	zone_rules[zone_name] = validation_func
	print("[VALIDATOR] Regla agregada para ", zone_name)


## Check if card can be dropped in zone
func can_drop_card(card: CardDisplay, zone_name: String) -> bool:
	if zone_name not in zone_rules:
		return true  # No rule = allow all
	
	var rule = zone_rules[zone_name]
	return rule.call(card)


## Validator: Allow only cards of specific rarity
func validator_by_rarity(allowed_rarities: Array[String]) -> Callable:
	return func(card: CardDisplay) -> bool:
		if card.card_data:
			return card.card_data.rarity in allowed_rarities
		return false


## Validator: Allow only cards of specific type
func validator_by_type(allowed_types: Array[String]) -> Callable:
	return func(card: CardDisplay) -> bool:
		if card.card_data:
			return card.card_data.type in allowed_types
		return false


## Validator: Allow only cards with cost <= max_cost
func validator_by_max_cost(max_cost: int) -> Callable:
	return func(card: CardDisplay) -> bool:
		if card.card_data:
			return card.card_data.cost <= max_cost
		return false


## Validator: Allow only cards of specific element
func validator_by_element(allowed_elements: Array[String]) -> Callable:
	return func(card: CardDisplay) -> bool:
		if card.card_data:
			return card.card_data.element in allowed_elements
		return false


## Validator: Max cards in zone
func validator_max_cards(max_count: int, current_count_func: Callable) -> Callable:
	return func(_card: CardDisplay) -> bool:
		return current_count_func.call() < max_count


## Validator: Combination of multiple rules (AND logic)
func validator_and(validators: Array[Callable]) -> Callable:
	return func(card: CardDisplay) -> bool:
		for validator in validators:
			if not validator.call(card):
				return false
		return true


## Validator: Combination of multiple rules (OR logic)
func validator_or(validators: Array[Callable]) -> Callable:
	return func(card: CardDisplay) -> bool:
		for validator in validators:
			if validator.call(card):
				return true
		return false


# --- Preset configurations for common game scenarios ---

## Setup for a "Creature Zone" - only knight type cards
func setup_creature_zone(zone_name: String) -> void:
	add_rule(zone_name, validator_by_type(["knight"]))


## Setup for a "Spell Zone" - only technique type cards, max 3
func setup_spell_zone(zone_name: String, zone_container: Node) -> void:
	var can_fit = func() -> int:
		return zone_container.get_child_count()
	
	var type_check = validator_by_type(["technique"])
	var count_check = validator_max_cards(3, can_fit)
	
	add_rule(zone_name, validator_and([type_check, count_check]))


## Setup for a "Low Cost Zone" - only cards with cost <= 3
func setup_low_cost_zone(zone_name: String) -> void:
	add_rule(zone_name, validator_by_max_cost(3))


## Setup for an "Element Zone" - only cards of specific element
func setup_element_zone(zone_name: String, element: String) -> void:
	add_rule(zone_name, validator_by_element([element]))
