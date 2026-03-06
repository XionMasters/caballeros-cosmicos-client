# BattleSummary.gd
# Pantalla de resumen al finalizar una partida
# Muestra el resultado (victoria/derrota) y transiciona al lobby
extends Control


# ============================================================================
# REFERENCIAS
# ============================================================================
@onready var result_label: Label = $CenterContainer/VBoxContainer/ResultLabel
@onready var subtitle_label: Label = $CenterContainer/VBoxContainer/SubtitleLabel
@onready var summary_image: TextureRect = $CenterContainer/VBoxContainer/SummaryImage
@onready var continue_button: Button = $CenterContainer/VBoxContainer/ContinueButton


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

	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)


func _setup_ui(won: bool) -> void:
	if result_label:
		result_label.text = "¡VICTORIA!" if won else "DERROTA"
		result_label.add_theme_color_override(
			"font_color",
			Color.GOLD if won else Color.CRIMSON
		)

	if subtitle_label:
		subtitle_label.text = (
			"Has demostrado ser un verdadero Caballero Cósmico." if won
			else "El cosmos no estuvo de tu lado hoy. ¡Sigue entrenando!"
		)

	# summary_image queda vacío — placeholder para imagen de arte futuro
	if summary_image:
		summary_image.texture = null  # Asignar aquí una textura de victoria/derrota en el futuro

	if continue_button:
		continue_button.text = "Continuar"


# ============================================================================
# INTERACCIÓN
# ============================================================================
func _on_continue_pressed() -> void:
	SceneTransition.go_to_mainlobby()
