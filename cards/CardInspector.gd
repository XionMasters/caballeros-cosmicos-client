# CardInspector.gd
# Detalle de una carta a pantalla completa: la carta en grande y, al lado, sus datos,
# estadísticas (las actuales si está en juego), estados activos y habilidades.
# La abre CardDetailManager (clic derecho o doble clic sobre una carta).
# Se cierra con clic fuera, Esc, clic derecho o el botón Cerrar.
extends Control

signal closed

const CARD_SIZE := Vector2(400, 524)  # proporción de carta (0.764)

const RARITY_LABELS := {
	"common": "Común", "rare": "Rara", "epic": "Épica", "legendary": "Legendaria", "divine": "Divina",
}
const ELEMENT_LABELS := {
	"steel": "Acero", "fire": "Fuego", "water": "Agua", "earth": "Tierra",
	"wind": "Viento", "light": "Luz", "dark": "Oscuridad",
}
const ABILITY_TYPE_LABELS := {
	"activa": "Activa", "pasiva": "Pasiva", "campo": "Campo", "equipamiento": "Equipamiento",
}
const STATUS_LABELS := {
	"defense": "Modo Defensa", "evasion": "Modo Evasión", "prayer": "Oración",
	"ce_boost": "CE aumentada", "ar_boost": "AR aumentada", "hp_boost": "LP máximos aumentados",
	"ignore_armor": "Ignora la armadura", "ce_double": "CE doble", "unicorn_horn": "Cuerno de Unicornio",
	"divine_frenzy_form": "Frenesí divino",
	"burn": "Quemado", "poison": "Envenenado", "frozen": "Congelado", "paralyzed": "Paralizado",
	"last_stand": "Determinación interior", "last_stand_active": "Determinación activa",
	"dot_immune": "Inmune a quemaduras y veneno", "burn_immune": "Inmune a quemaduras",
	"poison_immune": "Inmune al veneno", "immune_negative": "Inmune a estados negativos",
	"ignore_block_mode": "Ignora el Modo Defensa", "ignore_evade_mode": "Ignora el Modo Evasión",
	"pierce_evasion": "Atraviesa la evasión", "dragon_shield": "Escudo del Dragón",
	"electric_charge": "Carga eléctrica", "life_floor_1": "La vida no baja de 1",
	"dragon_rage": "Cólera del Dragón", "taunt": "Provocación", "armor_unbreakable": "Armadura irrompible",
}
## Marcadores internos del motor que no aportan nada al jugador
const HIDDEN_STATUSES := ["ability_used", "phoenix_rebirth_cooldown"]

var _card_image: TextureRect
var _info_box: VBoxContainer
var _scroll: ScrollContainer
var _image_request_url := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_layout()
	hide()


# ============================================================================
# API
# ============================================================================
func show_card(card: CardData, instance: CardInstance = null, texture: Texture2D = null) -> void:
	if card == null:
		return
	_fill(card, instance)
	_set_image(card, texture)
	_scroll.scroll_vertical = 0
	show()
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.18)


func close() -> void:
	if not visible:
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	await tween.finished
	hide()
	closed.emit()


# ============================================================================
# ENTRADA
# ============================================================================
func _gui_input(event: InputEvent) -> void:
	# Clic en el fondo (fuera del panel) o clic derecho en cualquier sitio: cerrar
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			close()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


# ============================================================================
# CONTENIDO
# ============================================================================
func _fill(card: CardData, instance: CardInstance) -> void:
	for child in _info_box.get_children():
		child.queue_free()

	# Nombre
	var name_label := Label.new()
	name_label.theme_type_variation = &"TitleLabel"
	name_label.text = card.name
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_box.add_child(name_label)

	# Tipo · Rareza · Facción
	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 10)
	_info_box.add_child(meta)
	meta.add_child(_chip(CardData.get_type_label(card.type), UIPalette.TEXT))
	if card.rarity != "":
		meta.add_child(_chip(RARITY_LABELS.get(card.rarity, card.rarity), UIPalette.rarity(card.rarity)))
	if card.faction != "":
		meta.add_child(_chip(card.faction, UIPalette.TEXT_MUTED))
	if card.element != "":
		meta.add_child(_chip(ELEMENT_LABELS.get(card.element, card.element), UIPalette.element(card.element)))
	if card.unique:
		meta.add_child(_chip("Única", UIPalette.GOLD_LIGHT))

	# Coste y generación de cosmo
	var economy: Array[String] = []
	if card.cost > 0:
		economy.append("Coste %d CP" % card.cost)
	if card.generate > 0:
		economy.append("Genera %d CP" % card.generate)
	if not economy.is_empty():
		_info_box.add_child(_text(" · ".join(economy), UIPalette.COSMOS))

	# Estadísticas
	if card.type == "knight":
		_info_box.add_child(_knight_stats(card, instance))
	elif card.type == "technique" and not card.technique.is_empty():
		_info_box.add_child(_technique_stats(card.technique))

	# Estados activos (solo en partida)
	if instance:
		var statuses := _visible_statuses(instance)
		if not statuses.is_empty():
			_info_box.add_child(_section("Estados"))
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 8)
			flow.add_theme_constant_override("v_separation", 8)
			for status in statuses:
				flow.add_child(_chip(status.text, status.color))
			_info_box.add_child(flow)

	# Habilidades
	_info_box.add_child(_section("Habilidades"))
	var abilities: Array = card.abilities if card.abilities is Array else []
	if abilities.is_empty():
		_info_box.add_child(_text("Esta carta no tiene habilidades.", UIPalette.TEXT_MUTED))
	for ability in abilities:
		if ability is Dictionary:
			_info_box.add_child(_ability_card(ability))

	# Texto de la carta
	if card.description.strip_edges() != "":
		_info_box.add_child(_section("Descripción"))
		var desc := _text(card.description, UIPalette.TEXT_MUTED)
		_info_box.add_child(desc)


func _knight_stats(card: CardData, instance: CardInstance) -> Control:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	var ce := instance.current_attack if instance else card.attack
	var ar := instance.current_defense if instance else card.defense
	var lp := instance.current_health if instance else card.health
	var lp_max := instance.max_health if instance and instance.max_health > 0 else card.health
	var cp := instance.current_cosmos if instance else card.cosmos
	var cp_max := instance.max_cosmos if instance and instance.max_cosmos > 0 else card.cosmos
	grid.add_child(_stat_tile("CE", str(ce), card.attack, ce, UIPalette.POWER))
	grid.add_child(_stat_tile("AR", str(ar), card.defense, ar, UIPalette.ARMOR))
	grid.add_child(_stat_tile("LP", "%d/%d" % [lp, lp_max], -1, 0, UIPalette.LIFE))
	grid.add_child(_stat_tile("CP", "%d/%d" % [cp, cp_max], -1, 0, UIPalette.COSMOS))
	return grid


func _technique_stats(tech: Dictionary) -> Control:
	var parts: Array[String] = []
	var hits := int(tech.get("hit_count", 1))
	parts.append("%d golpe%s de %d CE" % [hits, "" if hits == 1 else "s", int(tech.get("hit_ce", 0))])
	parts.append("Coste de TA: %d CP del caballero" % int(tech.get("ta_cost", 0)))
	if tech.get("target_all", false):
		parts.append("Golpea a todos los rivales")
	var tags = tech.get("compatible_tags", [])
	if tags is Array and not tags.is_empty():
		parts.append("La pueden usar: %s" % ", ".join(tags))
	var box := VBoxContainer.new()
	for part in parts:
		box.add_child(_text(part, UIPalette.TEXT))
	return box


func _visible_statuses(instance: CardInstance) -> Array:
	var out: Array = []
	for effect in instance.status_effects:
		if not (effect is Dictionary):
			continue
		var type := str(effect.get("type", ""))
		if type == "" or type in HIDDEN_STATUSES or type.begins_with("ta_"):
			continue
		var label: String = STATUS_LABELS.get(type, type.replace("_", " ").capitalize())
		var value = effect.get("value", null)
		if value != null and type in ["ce_boost", "ar_boost", "hp_boost", "burn", "poison"]:
			label += " (%s%d)" % ["+" if type.ends_with("boost") and int(value) > 0 else "", int(value)]
		var turns = effect.get("remaining_turns", null)
		if turns != null and int(turns) > 0 and int(turns) < 90:
			label += " · %d turno%s" % [int(turns), "" if int(turns) == 1 else "s"]
		var negative := type in ["burn", "poison", "frozen", "paralyzed"]
		out.append({"text": label, "color": UIPalette.LIFE if negative else UIPalette.TARGET})
	return out


func _ability_card(ability: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ItemCard"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	box.add_child(header)

	var type := str(ability.get("type", "")).to_lower()
	header.add_child(_chip(ABILITY_TYPE_LABELS.get(type, type.capitalize()), _ability_color(type)))

	var title := Label.new()
	title.text = str(ability.get("name", "Habilidad"))
	title.theme_type_variation = &"SectionTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(title)

	var cost := _ability_cost(ability)
	if cost > 0:
		header.add_child(_chip("%d CP" % cost, UIPalette.COSMOS))

	var description := str(ability.get("description", "")).strip_edges()
	if description != "":
		box.add_child(_text(description, UIPalette.TEXT))
	return panel


func _ability_cost(ability: Dictionary) -> int:
	var effects = ability.get("effects", {})
	if not (effects is Dictionary):
		return 0
	var cost = effects.get("cost", [])
	var total := 0
	if cost is Array:
		for entry in cost:
			if entry is Dictionary and str(entry.get("type", "")) == "cosmos":
				total += int(entry.get("amount", 0))
	return total


func _ability_color(type: String) -> Color:
	match type:
		"activa": return UIPalette.GOLD
		"pasiva": return UIPalette.ABILITY
		"campo": return UIPalette.COSMOS
		"equipamiento": return UIPalette.ARMOR
		_: return UIPalette.TEXT_MUTED


# ============================================================================
# IMAGEN
# ============================================================================
func _set_image(card: CardData, texture: Texture2D) -> void:
	if texture == null and CardsManager._image_cache.has(card.id):
		texture = CardsManager._image_cache[card.id]
	_card_image.texture = texture
	_image_request_url = ""
	if texture == null and card.image_url != "":
		var url := card.image_url
		_image_request_url = url
		ApiClient.get_image_with_callback(url, func(image: Image, _tag = null) -> void:
			# Ignorar si mientras tanto se abrió otra carta
			if image and is_instance_valid(self) and _image_request_url == url:
				_card_image.texture = ImageTexture.create_from_image(image)
		, "inspector_%s" % card.id)


# ============================================================================
# CONSTRUCCIÓN DE LA INTERFAZ
# ============================================================================
func _build_layout() -> void:
	var dim := ColorRect.new()
	dim.color = UIPalette.alpha(UIPalette.ABYSS, 0.84)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.theme_type_variation = &"BannerPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP  # los clics dentro del panel no cierran
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	margin.add_child(row)

	_card_image = TextureRect.new()
	_card_image.custom_minimum_size = CARD_SIZE
	_card_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_card_image)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(640, CARD_SIZE.y)
	right.add_theme_constant_override("separation", 12)
	row.add_child(right)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(_scroll)

	_info_box = VBoxContainer.new()
	_info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_box.add_theme_constant_override("separation", 12)
	_scroll.add_child(_info_box)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(footer)
	var hint := Label.new()
	hint.theme_type_variation = &"Caption"
	hint.text = "Esc o clic fuera para cerrar"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(hint)
	var close_button := Button.new()
	close_button.text = "Cerrar"
	close_button.custom_minimum_size = Vector2(120, 44)
	close_button.pressed.connect(close)
	footer.add_child(close_button)


func _section(title: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"SectionTitle"
	label.text = title
	return label


func _text(content: String, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	return label


func _chip(text: String, color: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UIPalette.alpha(color, 0.14)
	style.border_color = UIPalette.alpha(color, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 14)
	chip.add_child(label)
	return chip


func _stat_tile(caption: String, value_text: String, base_value: int, current_value: int, color: Color) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.theme_type_variation = &"StatTile"
	tile.custom_minimum_size = Vector2(140, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	tile.add_child(box)
	var value := Label.new()
	value.text = value_text
	value.theme_type_variation = &"StatValue"
	value.add_theme_color_override("font_color", color)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value)
	var label := Label.new()
	label.theme_type_variation = &"Caption"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = caption
	# Si la estadística actual difiere de la base, indicarlo
	if base_value >= 0 and current_value != base_value:
		label.text = "%s (base %d)" % [caption, base_value]
	box.add_child(label)
	return tile
