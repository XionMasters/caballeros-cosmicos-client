# ProfileScene.gd
# Perfil del jugador: identidad y avatar, estadísticas reales de partidas,
# progreso de colección, galería de avatares, dorso del mazo activo e historial.
extends Control

const LOCK_ICON := preload("res://assets/ui-icons/lobby/lock.svg")
const MONTHS := ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
	"agosto", "septiembre", "octubre", "noviembre", "diciembre"]
const UNLOCK_HINTS := {
	"default": "Disponible",
	"card_unlock": "Consigue la carta",
	"achievement": "Se obtiene con un logro",
	"purchase": "Disponible en la tienda",
	"seasonal": "Evento de temporada",
	"special": "Recompensa especial",
}

@onready var back_button: Button = %BackButton
@onready var loading_label: Label = %LoadingLabel
@onready var current_avatar: TextureRect = %CurrentAvatar
@onready var username_label: Label = %Username
@onready var avatar_name_label: Label = %AvatarName
@onready var member_since_label: Label = %MemberSince
@onready var wins_value: Label = %WinsValue
@onready var losses_value: Label = %LossesValue
@onready var total_value: Label = %TotalValue
@onready var streak_value: Label = %StreakValue
@onready var streak_caption: Label = %StreakCaption
@onready var winrate_bar: ProgressBar = %WinRateBar
@onready var winrate_label: Label = %WinRateLabel
@onready var practice_label: Label = %PracticeLabel
@onready var collection_bar: ProgressBar = %CollectionBar
@onready var collection_label: Label = %CollectionLabel
@onready var collection_detail: Label = %CollectionDetail
@onready var avatars_grid: GridContainer = %AvatarsGrid
@onready var deck_backs_grid: GridContainer = %DeckBacksGrid
@onready var deck_backs_hint: Label = %DeckBacksHint
@onready var history_list: VBoxContainer = %HistoryList
@onready var toast: ToastNotice = %Toast
@onready var confirm_dialog: ConfirmationDialog = %ConfirmDialog

var API_URL = GameConfig.API_URL

var profile_data: Dictionary = {}
var available_avatars: Array = []
var available_deck_backs: Array = []
var _pending_action: Callable
var _pending_requests := 0


func _ready():
	back_button.pressed.connect(_on_back_pressed)
	confirm_dialog.confirmed.connect(func(): if _pending_action.is_valid(): _pending_action.call())

	username_label.text = UserManager.get_username()
	_load_all()


# ============================================================================
# CARGA
# ============================================================================

func _load_all() -> void:
	# Primero comprobar desbloqueos por cartas legendarias; luego cargar todo
	_request(HTTPClient.METHOD_POST, "/profile/check-unlocks", {}, func(ok: bool, data):
		if ok and data is Dictionary and not (data.get("new_unlocks", []) as Array).is_empty():
			_show_toast(data.get("message", "¡Nuevo avatar desbloqueado!"))
		_load_profile()
		_load_avatars()
		_load_deck_backs()
	)


func _load_profile() -> void:
	_request(HTTPClient.METHOD_GET, "/profile", null, func(ok: bool, data):
		if not ok:
			_show_toast("No se pudo cargar el perfil", true)
			return
		profile_data = data
		_update_identity()
		_update_stats()
		_update_collection()
		_update_history()
		# Avatar y dorso marcados como "en uso" dependen del perfil
		if not available_avatars.is_empty():
			_populate_avatar_gallery()
		if not available_deck_backs.is_empty():
			_populate_deck_backs()
	)


func _load_avatars() -> void:
	_request(HTTPClient.METHOD_GET, "/profile/avatars", null, func(ok: bool, data):
		if not ok:
			_show_toast("No se pudieron cargar los avatares", true)
			return
		available_avatars = data.get("avatars", []) if data is Dictionary else data
		if not profile_data.is_empty():
			_populate_avatar_gallery()
	)


func _load_deck_backs() -> void:
	_request(HTTPClient.METHOD_GET, "/profile/deck-backs", null, func(ok: bool, data):
		if not ok:
			_show_toast("No se pudieron cargar los dorsos", true)
			return
		available_deck_backs = data if data is Array else []
		if not profile_data.is_empty():
			_populate_deck_backs()
	)


# ============================================================================
# IDENTIDAD, ESTADÍSTICAS, COLECCIÓN, HISTORIAL
# ============================================================================

func _current_avatar() -> Dictionary:
	var avatar = profile_data.get("profile", {}).get("avatar")
	return avatar if avatar is Dictionary else {}


func _update_identity() -> void:
	var user: Dictionary = profile_data.get("user", {})
	if user.get("username"):
		username_label.text = user.username

	var avatar := _current_avatar()
	avatar_name_label.text = avatar.get("name", "Sin avatar")
	if avatar.get("image_url", "") != "":
		_load_image(current_avatar, avatar.image_url)

	var since := _format_month_year(str(user.get("member_since", "")))
	member_since_label.text = "Caballero desde %s" % since if since != "" else ""


func _update_stats() -> void:
	var stats: Dictionary = profile_data.get("stats", {})
	var wins := int(stats.get("wins", 0))
	var losses := int(stats.get("losses", 0))
	var total := int(stats.get("total_matches", 0))
	var rate := float(stats.get("win_rate", 0.0)) * 100.0
	var streak := int(stats.get("current_streak", 0))

	_animate_number(wins_value, wins)
	_animate_number(losses_value, losses)
	_animate_number(total_value, total)

	# Racha actual si va ganando; si no, la mejor racha conseguida
	if streak > 1:
		streak_caption.text = "Racha actual"
		_animate_number(streak_value, streak)
	else:
		streak_caption.text = "Mejor racha"
		_animate_number(streak_value, int(stats.get("best_win_streak", 0)))

	create_tween().tween_property(winrate_bar, "value", rate, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	winrate_label.text = "%d%%" % roundi(rate)

	var practice := int(stats.get("practice_matches", 0))
	if total == 0 and practice > 0:
		practice_label.text = "Aún no has jugado partidas contra otros caballeros. Tus %d partidas de prueba no cuentan para las estadísticas." % practice
	elif practice > 0:
		practice_label.text = "Además, %d partidas de prueba (no cuentan)." % practice
	elif total == 0:
		practice_label.text = "Busca una partida desde el menú principal para empezar tu historial."
	else:
		practice_label.text = ""


func _update_collection() -> void:
	var collection: Dictionary = profile_data.get("collection", {})
	var unique := int(collection.get("unique_cards", 0))
	var catalog := maxi(int(collection.get("catalog_size", 0)), 1)
	collection_bar.max_value = catalog
	create_tween().tween_property(collection_bar, "value", unique, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	collection_label.text = "%d / %d cartas distintas (%d%%)" % [unique, catalog, roundi(100.0 * unique / catalog)]
	collection_detail.text = "%d copias en total · %d mazos" % [int(collection.get("total_copies", 0)), int(collection.get("decks", 0))]


func _update_history() -> void:
	for child in history_list.get_children():
		child.queue_free()

	var matches: Array = profile_data.get("recent_matches", [])
	if matches.is_empty():
		history_list.add_child(_make_empty_label("Todavía no has terminado ninguna partida."))
		return

	for entry in matches:
		history_list.add_child(_create_history_row(entry))


func _create_history_row(entry: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ItemCard"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var badge := Label.new()
	badge.custom_minimum_size = Vector2(110, 0)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.theme_type_variation = &"SectionTitle"
	match entry.get("result", ""):
		"win":
			badge.text = "VICTORIA"
			badge.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6))
		"loss":
			badge.text = "DERROTA"
			badge.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		_:
			badge.text = "PRUEBA"
			badge.add_theme_color_override("font_color", Color(0.7, 0.75, 1.0))
	row.add_child(badge)

	var opponent := Label.new()
	opponent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rival = entry.get("opponent")
	opponent.text = "contra %s" % rival if rival else "Partida de prueba"
	row.add_child(opponent)

	var date := Label.new()
	date.theme_type_variation = &"Subtitle"
	date.text = _format_date(str(entry.get("finished_at", "")))
	row.add_child(date)
	return panel


# ============================================================================
# AVATARES
# ============================================================================

func _populate_avatar_gallery() -> void:
	for child in avatars_grid.get_children():
		child.queue_free()

	var current_id: String = str(_current_avatar().get("id", ""))
	for avatar_data in available_avatars:
		var unlocked: bool = avatar_data.get("is_unlocked", false)
		var is_current: bool = str(avatar_data.get("id", "")) == current_id

		var hint := ""
		if not unlocked:
			var card = avatar_data.get("required_card")
			if card is Dictionary and card.get("name"):
				hint = "Consigue: %s" % card.name
			else:
				hint = UNLOCK_HINTS.get(avatar_data.get("unlock_type", ""), "Bloqueado")

		var item := _create_item_card(
			avatar_data.get("name", "Avatar"),
			avatar_data.get("image_url", ""),
			Vector2(140, 140),
			unlocked,
			is_current,
			hint,
			_confirm_avatar.bind(avatar_data)
		)
		avatars_grid.add_child(item)


func _confirm_avatar(avatar_data: Dictionary) -> void:
	_ask("¿Usar «%s» como tu avatar?" % avatar_data.get("name", "este avatar"), func():
		_request(HTTPClient.METHOD_PUT, "/profile/avatar", {"avatar_id": avatar_data.get("id", "")}, func(ok: bool, data):
			if not ok:
				_show_toast(_error_text(data, "No se pudo cambiar el avatar"), true)
				return
			# Actualizar localmente sin recargar todo
			var profile: Dictionary = profile_data.get("profile", {})
			profile["avatar"] = data.get("avatar", avatar_data)
			profile_data["profile"] = profile
			_update_identity()
			_populate_avatar_gallery()
			_pulse(current_avatar.get_parent())
			_show_toast("Avatar actualizado")
		)
	)


# ============================================================================
# DORSOS
# ============================================================================

func _populate_deck_backs() -> void:
	for child in deck_backs_grid.get_children():
		child.queue_free()

	var active_deck = profile_data.get("active_deck")
	if not (active_deck is Dictionary):
		deck_backs_hint.text = "Activa un mazo en «Mazos» para poder elegir su dorso."
	else:
		deck_backs_hint.text = "Dorso de tu mazo activo «%s». Lo verá tu rival durante la partida." % active_deck.get("name", "")

	var current_back_id := ""
	if active_deck is Dictionary and active_deck.get("deck_back") is Dictionary:
		current_back_id = str(active_deck.deck_back.get("id", ""))

	for back in available_deck_backs:
		var unlocked: bool = back.get("is_unlocked", false)
		var item := _create_item_card(
			back.get("name", "Dorso"),
			back.get("image_url", ""),
			Vector2(110, 154),
			unlocked and active_deck is Dictionary,
			str(back.get("id", "")) == current_back_id,
			"" if unlocked else UNLOCK_HINTS.get(back.get("unlock_type", ""), "Bloqueado"),
			_confirm_deck_back.bind(back)
		)
		deck_backs_grid.add_child(item)


func _confirm_deck_back(back: Dictionary) -> void:
	var active_deck: Dictionary = profile_data.get("active_deck", {})
	_ask("¿Usar «%s» en tu mazo «%s»?" % [back.get("name", "este dorso"), active_deck.get("name", "")], func():
		var body := {"deck_id": active_deck.get("id", ""), "deck_back_id": back.get("id", "")}
		_request(HTTPClient.METHOD_PUT, "/profile/deck-back", body, func(ok: bool, data):
			if not ok:
				_show_toast(_error_text(data, "No se pudo cambiar el dorso"), true)
				return
			active_deck["deck_back"] = data.get("deck_back", back)
			profile_data["active_deck"] = active_deck
			_populate_deck_backs()
			_show_toast("Dorso actualizado")
		)
	)


# ============================================================================
# COMPONENTES
# ============================================================================

func _create_item_card(title: String, image_url: String, image_size: Vector2, selectable: bool,
		is_current: bool, locked_hint: String, on_select: Callable) -> Control:
	"""Tarjeta de galería (avatar o dorso): imagen, nombre y acción"""
	var card := PanelContainer.new()
	card.theme_type_variation = &"ItemCardSelected" if is_current else &"ItemCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var image := TextureRect.new()
	image.custom_minimum_size = image_size
	image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(image)
	if image_url != "":
		_load_image(image, image_url)

	var locked := locked_hint != ""
	if locked:
		image.modulate = Color(0.35, 0.33, 0.45)
		var lock := TextureRect.new()
		lock.texture = LOCK_ICON
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		lock.custom_minimum_size = Vector2(44, 44)
		lock.size = Vector2(44, 44)
		lock.position = (image_size - lock.size) / 2.0
		image.add_child(lock)

	var name_label := Label.new()
	name_label.text = title
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)

	var button := Button.new()
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_current:
		button.text = "✓ En uso"
		button.disabled = true
	elif locked:
		button.text = locked_hint
		button.disabled = true
	elif not selectable:
		button.text = "No disponible"
		button.disabled = true
	else:
		button.text = "Usar"
		button.pressed.connect(on_select)
	vbox.add_child(button)

	# Resaltar al pasar el ratón por las seleccionables
	if selectable and not is_current and not locked:
		card.mouse_entered.connect(func(): card.modulate = Color(1.12, 1.08, 1.0))
		card.mouse_exited.connect(func(): card.modulate = Color.WHITE)
	return card


func _make_empty_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"Subtitle"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _ask(question: String, action: Callable) -> void:
	_pending_action = action
	confirm_dialog.dialog_text = question
	confirm_dialog.popup_centered()


func _show_toast(text: String, is_error := false) -> void:
	toast.show_message(text, is_error)


func _pulse(node: Control) -> void:
	node.pivot_offset = node.size / 2.0
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2(1.08, 1.08), 0.15).set_trans(Tween.TRANS_BACK)
	tween.tween_property(node, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE)


func _animate_number(label: Label, target: int) -> void:
	create_tween().tween_method(func(v: int): label.text = str(v), 0, target, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# ============================================================================
# RED Y UTILIDADES
# ============================================================================

func _request(method: int, path: String, body, on_done: Callable) -> void:
	"""Petición HTTP autenticada; on_done(ok: bool, data: Variant). Libera el nodo al terminar."""
	var http := HTTPRequest.new()
	add_child(http)
	_set_loading(1)

	http.request_completed.connect(func(_result, code: int, _headers, response: PackedByteArray):
		http.queue_free()
		_set_loading(-1)
		var data = JSON.parse_string(response.get_string_from_utf8()) if response.size() > 0 else null
		on_done.call(code >= 200 and code < 300, data)
	)

	var payload := "" if body == null else JSON.stringify(body)
	var err := http.request(API_URL + path, AuthManager.get_auth_headers(), method, payload)
	if err != OK:
		http.queue_free()
		_set_loading(-1)
		on_done.call(false, null)


func _set_loading(delta: int) -> void:
	_pending_requests = maxi(_pending_requests + delta, 0)
	loading_label.visible = _pending_requests > 0


func _load_image(texture_rect: TextureRect, url: String) -> void:
	# Referencia débil: si la galería se reconstruye o se sale de la pantalla
	# antes de que llegue la imagen, el nodo ya no existe y no hay que tocarlo.
	var target: WeakRef = weakref(texture_rect)
	ApiClient.get_image_with_callback(url, func(image: Image, _tag = null) -> void:
		var rect: TextureRect = target.get_ref()
		if image and rect:
			rect.texture = ImageTexture.create_from_image(image)
	, "profile_img_%s" % url.hash())


func _error_text(data, fallback: String) -> String:
	if data is Dictionary and data.get("error"):
		return str(data.error)
	return fallback


func _format_month_year(iso: String) -> String:
	# "2025-11-20T18:46:05.878Z" -> "noviembre de 2025"
	var parts := iso.split("-")
	if parts.size() < 2 or not parts[1].is_valid_int():
		return ""
	var month := clampi(parts[1].to_int(), 1, 12)
	return "%s de %s" % [MONTHS[month - 1], parts[0]]


func _format_date(iso: String) -> String:
	# "2026-10-27T03:20:06Z" -> "27/10/2026"
	var date := iso.split("T")[0].split("-")
	if date.size() < 3:
		return ""
	return "%s/%s/%s" % [date[2], date[1], date[0]]


func _on_back_pressed():
	SceneTransition.go_to_mainlobby()
