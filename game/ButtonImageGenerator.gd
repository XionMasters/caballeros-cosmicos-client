# ButtonImageGenerator.gd
# Script helper para generar imágenes de botones usando IA
# Configurado para usar fal.ai o similar

extends Node
class_name ButtonImageGenerator

# Configuración de API (configurable en el proyecto)
var use_image_generation: bool = true
var api_endpoint: String = ""  # Configurar en project settings si es necesario
var button_output_path: String = "res://assets/ui-icons/"

# Prompt para el botón de End Turn en estética Saint Seiya
var END_TURN_PROMPT = """
Saint Seiya style icon for end turn button, glowing golden arrow pointing forward with cosmos energy burst, 
metallic shine with bronze finish, transparent background, sacred geometry patterns, ancient Greek aesthetic, 
high quality, 128x128px, vibrant colors, cosmic particles around the arrow, professional game UI icon
""".strip_edges()


func _ready() -> void:
	print("[ButtonImageGenerator] 🎨 Inicializando generador de imágenes...")
	
	# Verificar si ya existe la imagen
	if ResourceLoader.exists(button_output_path + "end_turn_button.png"):
		print("[ButtonImageGenerator] ✅ Imagen del botón End Turn ya existe")
		return
	
	# Generar la imagen si está habilitada
	if use_image_generation:
		await generate_end_turn_button_image()
	else:
		print("[ButtonImageGenerator] ℹ️ Generación de imágenes deshabilitada")


func generate_end_turn_button_image() -> bool:
	"""Generar imagen del botón End Turn usando IA"""
	print("[ButtonImageGenerator] 🚀 Generando imagen del botón End Turn...")
	
	# Este es un placeholder para la integración con fal.ai, DALL-E, etc.
	# Para usar: configurar API_KEY en project settings y descomentar la llamada
	
	# Opciones de generación:
	# 1. Usar fal.ai (requiere key)
	# 2. Usar DALL-E 3 vía API OpenAI
	# 3. Usar Leonardo.ai
	# 4. Usar Stable Diffusion
	
	var success = await _generate_with_fal_ai()
	
	if success:
		print("[ButtonImageGenerator] ✅ Imagen generada exitosamente")
		return true
	else:
		print("[ButtonImageGenerator] ⚠️ No se pudo generar la imagen, usar fallback")
		_create_fallback_image()
		return false


func _generate_with_fal_ai() -> bool:
	"""Generar usando fal.ai (requiere key configurada)"""
	# Placeholder para futura integración
	# Aquí iría la lógica de llamada a fal.ai API
	
	print("[ButtonImageGenerator] ℹ️ Integración fal.ai: [PENDIENTE]")
	print("[ButtonImageGenerator] 📋 Usa este prompt en tu generador:")
	print("  " + END_TURN_PROMPT)
	
	return false


func _create_fallback_image() -> void:
	"""Crear imagen de fallback simple usando Godot"""
	print("[ButtonImageGenerator] 🎨 Creando imagen de fallback...")
	
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	
	# Fondo transparente con gradiente sutil
	for y in range(128):
		for x in range(128):
			var gradient = float(x) / 128.0
			var color = Color(
				0.2 + gradient * 0.3,  # R: 0.2 -> 0.5 (azul oscuro a azul más claro)
				0.15,                   # G
				0.4,                    # B
				0.8 if y < 110 else 0.3  # Alpha: gradiente al borde
			)
			image.set_pixel(x, y, color)
	
	# Dibujar una flecha dorada simplificada
	_draw_arrow_on_image(image)
	
	# Guardar imagen
	var path = button_output_path + "end_turn_button.png"
	var error = image.save_png(path)
	
	if error == OK:
		print("[ButtonImageGenerator] ✅ Imagen de fallback guardada: %s" % path)
	else:
		print("[ButtonImageGenerator] ❌ Error guardando imagen: %d" % error)


func _draw_arrow_on_image(image: Image) -> void:
	"""Dibujar una flecha dorada en la imagen"""
	# Esto es una aproximación simple; para mejor resultado usar un generador de imágenes
	
	var gold_color = Color(1.0, 0.84, 0.0, 1.0)  # Color dorado
	var center_x = 64
	var center_y = 64
	
	# Dibujar triángulo (flecha simple)
	# Punta: (100, 64)
	# Base izquierda: (40, 40)
	# Base derecha: (40, 88)
	
	var points = [
		Vector2i(100, 64),  # Punta derecha
		Vector2i(40, 40),   # Arriba izquierda
		Vector2i(40, 88),   # Abajo izquierda
		Vector2i(100, 64),  # Cerrar
	]
	
	# Dibujar líneas de la flecha (aproximación simple)
	_draw_line_on_image(image, points[0], points[1], gold_color)
	_draw_line_on_image(image, points[1], points[2], gold_color)
	_draw_line_on_image(image, points[2], points[0], gold_color)


func _draw_line_on_image(image: Image, from: Vector2i, to: Vector2i, color: Color) -> void:
	"""Dibujar línea en imagen usando Bresenham"""
	var dx = abs(to.x - from.x)
	var dy = abs(to.y - from.y)
	var sx = 1 if from.x < to.x else -1
	var sy = 1 if from.y < to.y else -1
	var err = dx - dy
	
	var x = from.x
	var y = from.y
	
	while true:
		if 0 <= x < 128 and 0 <= y < 128:
			image.set_pixel(x, y, color)
		
		if x == to.x and y == to.y:
			break
		
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy


func print_generation_instructions() -> void:
	"""Imprimir instrucciones para generar la imagen manualmente"""
	print("""
╔════════════════════════════════════════════════════════════════╗
║    📋 INSTRUCCIONES: Generar imagen del botón End Turn        ║
╚════════════════════════════════════════════════════════════════╝

1. Usa uno de estos generadores (con límite gratis):
   • Microsoft Designer: https://www.bing.com/images/create
   • Leonardo.ai: https://leonardo.ai
   • Ideogram: https://ideogram.ai
   
2. Copia y pega este prompt:
   """)
	print("   " + END_TURN_PROMPT.replace("\n", "\n   "))
	print("""
3. Descarga la imagen generada
4. Colócala en: res://assets/ui-icons/end_turn_button.png
5. Reinicia la aplicación

📌 Alternativamente, usa tu generador favorito (DALL-E, Midjourney, etc.)
	""")