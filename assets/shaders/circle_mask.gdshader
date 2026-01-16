shader_type canvas_item;

// Controla el suavizado del borde (0 = borde duro, 1 = muy suave)
uniform float smoothness : hint_range(0.0, 0.5) = 0.05;
// Controla el tamaño del círculo (1.0 = usa todo el espacio)
uniform float circle_size : hint_range(0.1, 1.5) = 1.0;

void fragment() {
	// Centrar las coordenadas UV (-1 a 1 en ambas direcciones)
	vec2 centered_uv = (UV - 0.5) * 2.0;
    
	// Calcular la relación de aspecto de la textura
	// TEXTURE_PIXEL_SIZE.x/y nos da el tamaño de un píxel en UV space
	float tex_aspect_ratio = TEXTURE_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.x;
	vec2 aspect_correction = vec2(1.0, tex_aspect_ratio);
    
	// Aplicar corrección de aspecto para hacer el círculo perfecto
	vec2 adjusted_uv = centered_uv * aspect_correction;
    
	// Calcular distancia desde el centro (corregida por aspecto)
	float dist = length(adjusted_uv);
    
	// Suavizado del borde usando smoothstep
	// La transición ocurre entre (circle_size - smoothness) y circle_size
	float alpha = smoothstep(circle_size, circle_size - smoothness, dist);
    
	// Si es completamente transparente, descartar el píxel para eficiencia
	if (alpha <= 0.0) {
		discard;
	}
    
	// Obtener el color de la textura original
	vec4 tex_color = texture(TEXTURE, UV);
    
	// Aplicar la transparencia del borde suavizado
	COLOR = vec4(tex_color.rgb, tex_color.a * alpha);
}