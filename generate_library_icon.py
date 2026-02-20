#!/usr/bin/env python3
"""
Script para generar un icono de biblioteca válido en PNG
"""

try:
    from PIL import Image, ImageDraw
    import os
    
    # Crear imagen con fondo transparente
    size = 256
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Colores
    gold = (255, 215, 0, 255)  # Dorado
    bronze = (205, 127, 50, 255)  # Bronce
    gray = (169, 169, 169, 255)  # Gris
    
    # Dibujar libro abierto (simple)
    # Página izquierda
    draw.rectangle([80, 70, 125, 200], outline=gray, fill=gold, width=3)
    draw.line([(102, 70), (102, 200)], fill=gray, width=2)
    
    # Página derecha
    draw.rectangle([130, 70, 175, 200], outline=gray, fill=gold, width=3)
    draw.line([(152, 70), (152, 200)], fill=gray, width=2)
    
    # Centro del lomo
    draw.rectangle([120, 190, 135, 210], fill=bronze, width=0)
    
    # Guardar
    output_path = r"d:\Disco E\Nacho\Projects\ccg\assets\ui-icons\library_icon_new.png"
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    img.save(output_path, 'PNG')
    print(f"✅ Imagen PNG válida guardada en: {output_path}")
    print(f"   Tamaño: {img.size}")
    print(f"   Modo: {img.mode}")
    
except ImportError:
    print("Instalando Pillow...")
    import subprocess
    import sys
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pillow"])
    print("✅ Pillow instalado. Ejecuta el script de nuevo.")
except Exception as e:
    print(f"❌ Error: {e}")
