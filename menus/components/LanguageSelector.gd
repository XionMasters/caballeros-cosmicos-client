# LanguageSelector.gd
# UI para seleccionar el idioma del juego
# NOTA: Sistema de localización deshabilitado temporalmente
extends Control

@onready var language_dropdown = $VBoxContainer/LanguageDropdown
@onready var apply_button = $VBoxContainer/ApplyButton
@onready var close_button = $VBoxContainer/CloseButton

signal language_selected(language_code: String)

var _selected_language: int = 0

# Idiomas disponibles (hardcoded mientras no existe Localization)
var available_languages = [
	{"code": "es", "name": "Español", "enum": 0},
	{"code": "en", "name": "English", "enum": 1},
	{"code": "pt", "name": "Português", "enum": 2}
]

func _ready():
	populate_languages()
	apply_button.pressed.connect(_on_apply_pressed)
	close_button.pressed.connect(_on_close_pressed)

func populate_languages():
	language_dropdown.clear()
	
	for i in range(available_languages.size()):
		var lang = available_languages[i]
		language_dropdown.add_item(lang["name"])
		
		# Seleccionar español por defecto
		if lang["code"] == "es":
			language_dropdown.selected = i
			_selected_language = i

func _on_apply_pressed():
	var selected = language_dropdown.selected
	
	if selected >= 0 and selected < available_languages.size():
		var lang = available_languages[selected]
		# TODO: Implementar cambio de idioma cuando exista sistema de localización
		language_selected.emit(lang["code"])
		print("Idioma seleccionado: ", lang["name"])

func _on_close_pressed():
	queue_free()
