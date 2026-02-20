#!/usr/bin/env python3
"""
Script para redimensionar end_turn_button.png a 32x32px
"""

try:
    from PIL import Image
    import sys
    
    input_path = r"d:\Disco E\Nacho\Projects\ccg\assets\ui-icons\end_turn_button.png"
    output_path = input_path
    
    # Cargar imagen
    img = Image.open(input_path)
    print(f"Tamaño original: {img.size}")
    
    # Redimensionar a 32x32 con alta calidad
    img_resized = img.resize((32, 32), Image.Resampling.LANCZOS)
    print(f"Nuevo tamaño: {img_resized.size}")
    
    # Guardar
    img_resized.save(output_path, "PNG", quality=95)
    print(f"✅ Imagen redimensionada y guardada en: {output_path}")
    
except ImportError:
    print("❌ Pillow no instalado. Instalando...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pillow"])
    print("✅ Pillow instalado. Ejecuta el script de nuevo.")
except Exception as e:
    print(f"❌ Error: {e}")
