# LocalizationManager.gd
# Gestiona la internacionalización del juego (i18n)
extends Node

signal language_changed(new_language: String)

# Idiomas disponibles
enum Languages {
	ES, # Español
	EN, # English
	PT  # Português
}

# Idioma actual
var current_language: Languages = Languages.ES

# Diccionario de traducciones
var translations: Dictionary = {}

# Clave para guardar preferencia de idioma
const LANGUAGE_SAVE_KEY = "user_language"

func _ready():
	load_translations()
	load_saved_language()
	# Recargar cartas cuando cambie el idioma (si CardDatabase ya está cargado)
	language_changed.connect(_on_language_changed)


func _on_language_changed(new_lang: String) -> void:
	if has_node("/root/CardDatabase"):
		get_node("/root/CardDatabase").reload_for_language(new_lang)

# Cargar todas las traducciones
func load_translations():
	translations = {
		Languages.ES: {
			# UI General
			"loading": "Cargando...",
			"error": "Error",
			"success": "Éxito",
			"cancel": "Cancelar",
			"accept": "Aceptar",
			"back": "Volver",
			"continue": "Continuar",
			"close": "Cerrar",
			"save": "Guardar",
			"delete": "Eliminar",
			"edit": "Editar",
			"search": "Buscar",
			"filter": "Filtrar",
			
			# Autenticación
			"login": "Iniciar Sesión",
			"register": "Registrarse",
			"logout": "Cerrar Sesión",
			"email": "Correo Electrónico",
			"username": "Usuario",
			"password": "Contraseña",
			"confirm_password": "Confirmar Contraseña",
			"login_failed": "Error al iniciar sesión",
			"register_failed": "Error al registrarse",
			"login_success": "Sesión iniciada correctamente",
			"register_success": "Registro exitoso",
			
			# Cartas
			"cards": "Cartas",
			"my_cards": "Mis Cartas",
			"card_details": "Detalles de la Carta",
			"attack": "Ataque",
			"defense": "Defensa",
			"health": "Vida",
			"cosmos": "Cosmos",
			"cost": "Coste",
			"generate": "Genera",
			"rarity": "Rareza",
			"element": "Elemento",
			"faction": "Facción",
			"abilities": "Habilidades",
			"description": "Descripción",
			
			# Tipos de Carta
			"knight": "Caballero",
			"technique": "Técnica",
			"item": "Objeto",
			"stage": "Escenario",
			"helper": "Ayudante",
			"event": "Ocasión",
			
			# Rareza
			"common": "Común",
			"rare": "Rara",
			"epic": "Épica",
			"legendary": "Legendaria",
			"divine": "Divina",
			
			# Elementos
			"steel": "Acero",
			"fire": "Fuego",
			"water": "Agua",
			"earth": "Tierra",
			"wind": "Viento",
			"light": "Luz",
			"dark": "Oscuridad",
			"none": "Ninguno",
			
			# Mazos
			"decks": "Mazos",
			"my_decks": "Mis Mazos",
			"create_deck": "Crear Mazo",
			"edit_deck": "Editar Mazo",
			"delete_deck": "Eliminar Mazo",
			"deck_name": "Nombre del Mazo",
			"deck_cards": "Cartas del Mazo",
			"add_card": "Agregar Carta",
			"remove_card": "Quitar Carta",
			"deck_valid": "Mazo válido",
			"deck_invalid": "Mazo inválido",
			"cards_count": "Cartas: %d/%d",
			
			# Sobres
			"packs": "Sobres",
			"shop": "Tienda",
			"buy_pack": "Comprar Sobre",
			"open_pack": "Abrir Sobre",
			"pack_price": "Precio: %d monedas",
			"insufficient_coins": "Monedas insuficientes",
			"pack_purchased": "Sobre comprado",
			"pack_opened": "Sobre abierto",
			
			# Partidas
			"play": "Jugar",
			"find_match": "Buscar Partida",
			"searching": "Buscando...",
			"match_found": "¡Partida encontrada!",
			"your_turn": "ES TU TURNO",
			"opponent_turn": "TURNO DEL OPONENTE",
			"turn": "Turno: %d",
			"pass_turn": "Pasar Turno",
			"surrender": "Rendirse",
			"victory": "¡VICTORIA!",
			"defeat": "DERROTA",
			"draw": "EMPATE",
			
			# Estados de Juego
			"hand": "Mano",
			"field": "Campo",
			"graveyard": "Cementerio",
			"hand_count": "Mano: %d cartas",
			"life": "Vida: %d",
			"cosmos_count": "Cosmos: %d",
			
			# Mensajes
			"connection_error": "Error de conexión",
			"server_error": "Error del servidor",
			"invalid_credentials": "Credenciales inválidas",
			"fields_required": "Todos los campos son obligatorios",
			"passwords_not_match": "Las contraseñas no coinciden",
		},
		
		Languages.EN: {
			# UI General
			"loading": "Loading...",
			"error": "Error",
			"success": "Success",
			"cancel": "Cancel",
			"accept": "Accept",
			"back": "Back",
			"continue": "Continue",
			"close": "Close",
			"save": "Save",
			"delete": "Delete",
			"edit": "Edit",
			"search": "Search",
			"filter": "Filter",
			
			# Authentication
			"login": "Login",
			"register": "Sign Up",
			"logout": "Logout",
			"email": "Email",
			"username": "Username",
			"password": "Password",
			"confirm_password": "Confirm Password",
			"login_failed": "Login failed",
			"register_failed": "Registration failed",
			"login_success": "Successfully logged in",
			"register_success": "Registration successful",
			
			# Cards
			"cards": "Cards",
			"my_cards": "My Cards",
			"card_details": "Card Details",
			"attack": "Attack",
			"defense": "Defense",
			"health": "Health",
			"cosmos": "Cosmos",
			"cost": "Cost",
			"generate": "Generate",
			"rarity": "Rarity",
			"element": "Element",
			"faction": "Faction",
			"abilities": "Abilities",
			"description": "Description",
			
			# Card Types
			"knight": "Knight",
			"technique": "Technique",
			"item": "Item",
			"stage": "Stage",
			"helper": "Helper",
			"event": "Event",
			
			# Rarity
			"common": "Common",
			"rare": "Rare",
			"epic": "Epic",
			"legendary": "Legendary",
			"divine": "Divine",
			
			# Elements
			"steel": "Steel",
			"fire": "Fire",
			"water": "Water",
			"earth": "Earth",
			"wind": "Wind",
			"light": "Light",
			"dark": "Dark",
			"none": "None",
			
			# Decks
			"decks": "Decks",
			"my_decks": "My Decks",
			"create_deck": "Create Deck",
			"edit_deck": "Edit Deck",
			"delete_deck": "Delete Deck",
			"deck_name": "Deck Name",
			"deck_cards": "Deck Cards",
			"add_card": "Add Card",
			"remove_card": "Remove Card",
			"deck_valid": "Valid Deck",
			"deck_invalid": "Invalid Deck",
			"cards_count": "Cards: %d/%d",
			
			# Packs
			"packs": "Packs",
			"shop": "Shop",
			"buy_pack": "Buy Pack",
			"open_pack": "Open Pack",
			"pack_price": "Price: %d coins",
			"insufficient_coins": "Insufficient coins",
			"pack_purchased": "Pack purchased",
			"pack_opened": "Pack opened",
			
			# Matches
			"play": "Play",
			"find_match": "Find Match",
			"searching": "Searching...",
			"match_found": "Match found!",
			"your_turn": "YOUR TURN",
			"opponent_turn": "OPPONENT'S TURN",
			"turn": "Turn: %d",
			"pass_turn": "Pass Turn",
			"surrender": "Surrender",
			"victory": "VICTORY!",
			"defeat": "DEFEAT",
			"draw": "DRAW",
			
			# Game States
			"hand": "Hand",
			"field": "Field",
			"graveyard": "Graveyard",
			"hand_count": "Hand: %d cards",
			"life": "Life: %d",
			"cosmos_count": "Cosmos: %d",
			
			# Messages
			"connection_error": "Connection error",
			"server_error": "Server error",
			"invalid_credentials": "Invalid credentials",
			"fields_required": "All fields are required",
			"passwords_not_match": "Passwords do not match",
		},
		
		Languages.PT: {
			# UI General
			"loading": "Carregando...",
			"error": "Erro",
			"success": "Sucesso",
			"cancel": "Cancelar",
			"accept": "Aceitar",
			"back": "Voltar",
			"continue": "Continuar",
			"close": "Fechar",
			"save": "Salvar",
			"delete": "Eliminar",
			"edit": "Editar",
			"search": "Pesquisar",
			"filter": "Filtrar",
			
			# Autenticação
			"login": "Entrar",
			"register": "Registrar",
			"logout": "Sair",
			"email": "Email",
			"username": "Usuário",
			"password": "Senha",
			"confirm_password": "Confirmar Senha",
			"login_failed": "Erro ao entrar",
			"register_failed": "Erro ao registrar",
			"login_success": "Login bem-sucedido",
			"register_success": "Registro bem-sucedido",
			
			# Cartas
			"cards": "Cartas",
			"my_cards": "Minhas Cartas",
			"card_details": "Detalhes da Carta",
			"attack": "Ataque",
			"defense": "Defesa",
			"health": "Vida",
			"cosmos": "Cosmos",
			"cost": "Custo",
			"generate": "Gera",
			"rarity": "Raridade",
			"element": "Elemento",
			"faction": "Facção",
			"abilities": "Habilidades",
			"description": "Descrição",
			
			# Tipos de Carta
			"knight": "Cavaleiro",
			"technique": "Técnica",
			"item": "Objeto",
			"stage": "Cenário",
			"helper": "Ajudante",
			"event": "Ocasião",
			
			# Raridade
			"common": "Comum",
			"rare": "Rara",
			"epic": "Épica",
			"legendary": "Lendária",
			"divine": "Divina",
			
			# Elementos
			"steel": "Aço",
			"fire": "Fogo",
			"water": "Água",
			"earth": "Terra",
			"wind": "Vento",
			"light": "Luz",
			"dark": "Escuridão",
			"none": "Nenhum",
			
			# Baralhos
			"decks": "Baralhos",
			"my_decks": "Meus Baralhos",
			"create_deck": "Criar Baralho",
			"edit_deck": "Editar Baralho",
			"delete_deck": "Eliminar Baralho",
			"deck_name": "Nome do Baralho",
			"deck_cards": "Cartas do Baralho",
			"add_card": "Adicionar Carta",
			"remove_card": "Remover Carta",
			"deck_valid": "Baralho válido",
			"deck_invalid": "Baralho inválido",
			"cards_count": "Cartas: %d/%d",
			
			# Pacotes
			"packs": "Pacotes",
			"shop": "Loja",
			"buy_pack": "Comprar Pacote",
			"open_pack": "Abrir Pacote",
			"pack_price": "Preço: %d moedas",
			"insufficient_coins": "Moedas insuficientes",
			"pack_purchased": "Pacote comprado",
			"pack_opened": "Pacote aberto",
			
			# Partidas
			"play": "Jogar",
			"find_match": "Procurar Partida",
			"searching": "Procurando...",
			"match_found": "Partida encontrada!",
			"your_turn": "SUA VEZ",
			"opponent_turn": "VEZ DO OPONENTE",
			"turn": "Turno: %d",
			"pass_turn": "Passar Turno",
			"surrender": "Render-se",
			"victory": "VITÓRIA!",
			"defeat": "DERROTA",
			"draw": "EMPATE",
			
			# Estados do Jogo
			"hand": "Mão",
			"field": "Campo",
			"graveyard": "Cemitério",
			"hand_count": "Mão: %d cartas",
			"life": "Vida: %d",
			"cosmos_count": "Cosmos: %d",
			
			# Mensagens
			"connection_error": "Erro de conexão",
			"server_error": "Erro do servidor",
			"invalid_credentials": "Credenciais inválidas",
			"fields_required": "Todos os campos são obrigatórios",
			"passwords_not_match": "As senhas não coincidem",
		}
	}

# Obtener traducción
func translate(key: String, args: Array = []) -> String:
	var lang_dict = translations.get(current_language, {})
	var text = lang_dict.get(key, key)
	
	# Si hay argumentos, formatear el texto
	if args.size() > 0:
		return text % args
	
	return text

# Cambiar idioma
func set_language(lang: Languages):
	if lang != current_language:
		current_language = lang
		save_language()
		language_changed.emit(get_language_code())

# Obtener código de idioma actual
func get_language_code() -> String:
	match current_language:
		Languages.ES:
			return "es"
		Languages.EN:
			return "en"
		Languages.PT:
			return "pt"
		_:
			return "es"

# Obtener idioma desde código
func get_language_from_code(code: String) -> Languages:
	match code.to_lower():
		"en":
			return Languages.EN
		"pt":
			return Languages.PT
		_:
			return Languages.ES

# Guardar idioma preferido
func save_language():
	var config = ConfigFile.new()
	config.set_value("localization", "language", get_language_code())
	config.save("user://settings.cfg")

# Cargar idioma guardado
func load_saved_language():
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	if err == OK:
		var lang_code = config.get_value("localization", "language", "es")
		current_language = get_language_from_code(lang_code)
	else:
		# Detectar idioma del sistema si no hay guardado
		var system_locale = OS.get_locale().split("_")[0]
		current_language = get_language_from_code(system_locale)

# Obtener todos los idiomas disponibles
func get_available_languages() -> Array:
	return [
		{"code": "es", "name": "Español", "enum": Languages.ES},
		{"code": "en", "name": "English", "enum": Languages.EN},
		{"code": "pt", "name": "Português", "enum": Languages.PT}
	]
