# BattleSummary.gd
# Pantalla de resultado al terminar una partida: ilustración de victoria o derrota a
# pantalla completa, título enorme que entra de golpe y botón para volver al lobby.
extends Control

const WIN_ART := "res://assets/images/win.png"
const LOSE_ART := "res://assets/images/lose.png"

# ============================================================================
# REFERENCIAS
# ============================================================================
@onready var art: TextureRect = %Art
@onready var flash: ColorRect = %Flash
@onready var eyebrow_label: Label = %EyebrowLabel
@onready var result_label: Label = %ResultLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var button_row: Control = %ButtonRow
@onready var continue_button: Button = %ContinueButton


# ============================================================================
# CICLO DE VIDA
# ============================================================================
func _ready() -> void:
	# Leer datos pasados por SceneTransition / game_match.gd
	var data := {}
	if SceneTransition.has_method("get_pending_data"):
		var pending = SceneTransition.get_pending_data()
		if pending is Dictionary:
			data = pending

	var won: bool = data.get("won", false)
	_setup_ui(won)
	continue_button.pressed.connect(_on_continue_pressed)
	_play_intro(won)


func _setup_ui(won: bool) -> void:
	var accent := UIPalette.GOLD_LIGHT if won else UIPalette.LIFE
	result_label.text = "¡VICTORIA!" if won else "DERROTA"
	result_label.add_theme_color_override("font_color", accent)
	result_label.add_theme_color_override("font_shadow_color", UIPalette.alpha(accent, 0.45))
	eyebrow_label.add_theme_color_override("font_color", UIPalette.ACCENT if won else UIPalette.TEXT_MUTED)

	subtitle_label.text = (
		"Has demostrado ser un verdadero Caballero Cósmico." if won
		else "El cosmos no estuvo de tu lado hoy. ¡Sigue entrenando!"
	)

	var path := WIN_ART if won else LOSE_ART
	if ResourceLoader.exists(path):
		art.texture = load(path)
	# En la derrota la ilustración se apaga un poco
	art.modulate = Color.WHITE if won else Color(0.75, 0.72, 0.85)


# ============================================================================
# ANIMACIÓN
# ============================================================================
func _play_intro(won: bool) -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return

	# Arte: zoom lento hacia dentro
	art.pivot_offset = art.size / 2.0
	art.scale = Vector2(1.12, 1.12)
	create_tween().tween_property(art, "scale", Vector2.ONE, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Título: cae desde grande con un destello
	result_label.pivot_offset = result_label.size / 2.0
	result_label.scale = Vector2(2.4, 2.4)
	result_label.modulate.a = 0.0
	for node in [eyebrow_label, subtitle_label, button_row]:
		node.modulate.a = 0.0

	var slam := create_tween()
	slam.tween_interval(0.25)
	slam.set_parallel()
	slam.tween_property(result_label, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slam.tween_property(result_label, "modulate:a", 1.0, 0.12)
	slam.chain().tween_callback(_impact.bind(won))
	slam.chain().set_parallel()
	slam.tween_property(eyebrow_label, "modulate:a", 1.0, 0.3)
	slam.tween_property(subtitle_label, "modulate:a", 1.0, 0.3).set_delay(0.1)
	slam.tween_property(button_row, "modulate:a", 1.0, 0.3).set_delay(0.35)


func _impact(won: bool) -> void:
	# Destello de pantalla y temblor breve al "caer" el título
	flash.color = Color(UIPalette.GOLD_LIGHT if won else UIPalette.LIFE, 0.55)
	create_tween().tween_property(flash, "color:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var origin := position
	var shake := create_tween()
	for offset in [Vector2(14, -6), Vector2(-10, 8), Vector2(6, -4), Vector2(-3, 2), Vector2.ZERO]:
		shake.tween_property(self, "position", origin + offset, 0.04)

	if won:
		# Brillo pulsante del título de victoria
		var glow := create_tween().set_loops()
		glow.tween_property(result_label, "modulate", Color(1.2, 1.15, 1.0), 1.1).set_trans(Tween.TRANS_SINE)
		glow.tween_property(result_label, "modulate", Color.WHITE, 1.1).set_trans(Tween.TRANS_SINE)


# ============================================================================
# INTERACCIÓN
# ============================================================================
func _on_continue_pressed() -> void:
	SceneTransition.go_to_mainlobby()
