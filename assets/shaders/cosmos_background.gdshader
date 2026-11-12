// Fondo de cosmos animado: nebulosas saturadas, haces de luz desde arriba,
// estrellas que titilan y aura dorada central.
shader_type canvas_item;

uniform vec4 color_deep : source_color = vec4(0.03, 0.012, 0.11, 1.0);
uniform vec4 color_nebula_a : source_color = vec4(0.55, 0.13, 0.78, 1.0);
uniform vec4 color_nebula_b : source_color = vec4(0.06, 0.3, 0.95, 1.0);
uniform vec4 color_gold : source_color = vec4(1.0, 0.78, 0.32, 1.0);
// Intensidad de los haces de luz (0 = sin haces)
uniform float rays_strength = 0.22;
// ancho / alto del rect, lo actualiza el script al redimensionar
uniform float aspect = 1.0;
// 0..1, sube al "encender el cosmos" (feedback al iniciar sesión)
uniform float aura_boost = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		value += amplitude * noise(p);
		p *= 2.0;
		amplitude *= 0.5;
	}
	return value;
}

float star_layer(vec2 p, float scale, float t) {
	vec2 grid = p * scale;
	vec2 id = floor(grid);
	vec2 f = fract(grid);
	float h = hash(id);
	if (h < 0.93) {
		return 0.0;
	}
	vec2 pos = vec2(hash(id + 3.1), hash(id + 7.7)) * 0.8 + 0.1;
	float d = length(f - pos);
	float twinkle = 0.55 + 0.45 * sin(t * (1.0 + h * 3.0) + h * 40.0);
	return smoothstep(0.08, 0.0, d) * twinkle;
}

void fragment() {
	vec2 uv = UV;
	vec2 p = vec2(uv.x * aspect, uv.y);
	float t = TIME;

	// Degradado vertical: más luz arriba, suelo oscuro abajo
	vec3 col = mix(color_deep.rgb * 1.6, color_deep.rgb * 0.7, uv.y);

	// Nebulosas en lento movimiento
	float n = fbm(p * 2.0 + vec2(t * 0.012, t * 0.006));
	float n2 = fbm(p * 3.5 - vec2(t * 0.009, 0.0) + n);
	col = mix(col, color_nebula_b.rgb, smoothstep(0.35, 0.95, n) * 0.6);
	col = mix(col, color_nebula_a.rgb, smoothstep(0.45, 1.0, n2) * 0.65);

	// Haces de luz que caen desde arriba y giran muy despacio
	vec2 from_top = (uv - vec2(0.5, -0.15)) * vec2(aspect, 1.0);
	float angle = atan(from_top.x, from_top.y);
	float rays = pow(0.5 + 0.5 * sin(angle * 14.0 + t * 0.15), 6.0);
	rays += 0.6 * pow(0.5 + 0.5 * sin(angle * 23.0 - t * 0.1 + 1.7), 8.0);
	float ray_fade = smoothstep(1.25, 0.1, length(from_top));
	col += mix(color_nebula_b.rgb, vec3(0.75, 0.85, 1.0), 0.5) * rays * ray_fade * rays_strength;

	// Aura dorada central que "respira"
	float r = length((uv - vec2(0.5, 0.45)) * vec2(aspect, 1.0));
	float breath = 0.85 + 0.15 * sin(t * 1.4);
	col += color_gold.rgb * (0.12 + 0.35 * aura_boost) * exp(-r * r * (6.0 - 3.0 * aura_boost)) * breath;

	// Tres capas de estrellas con distinta escala y deriva
	float s = star_layer(p + vec2(t * 0.002, 0.0), 45.0, t);
	s += star_layer(p, 90.0, t * 1.3) * 0.7;
	s += star_layer(p + vec2(0.0, t * 0.001), 170.0, t * 0.7) * 0.5;
	col += vec3(s) * mix(vec3(1.0), color_gold.rgb, 0.25);

	// Viñeta para enfocar el centro
	float vignette = smoothstep(1.3, 0.3, length((uv - vec2(0.5, 0.45)) * vec2(aspect, 1.0)));
	COLOR = vec4(col * mix(0.45, 1.0, vignette), 1.0);
}
