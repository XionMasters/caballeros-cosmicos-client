// Fondo de cosmos animado: nebulosas, estrellas que titilan y aura dorada central.
shader_type canvas_item;

uniform vec4 color_deep : source_color = vec4(0.02, 0.01, 0.07, 1.0);
uniform vec4 color_nebula_a : source_color = vec4(0.38, 0.12, 0.58, 1.0);
uniform vec4 color_nebula_b : source_color = vec4(0.08, 0.22, 0.62, 1.0);
uniform vec4 color_gold : source_color = vec4(1.0, 0.78, 0.32, 1.0);
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

	// Nebulosas en lento movimiento
	float n = fbm(p * 2.0 + vec2(t * 0.012, t * 0.006));
	float n2 = fbm(p * 3.5 - vec2(t * 0.009, 0.0) + n);
	vec3 col = color_deep.rgb;
	col = mix(col, color_nebula_b.rgb, smoothstep(0.35, 0.95, n) * 0.55);
	col = mix(col, color_nebula_a.rgb, smoothstep(0.45, 1.0, n2) * 0.6);

	// Aura dorada central que "respira"
	float r = length((uv - vec2(0.5, 0.45)) * vec2(aspect, 1.0));
	float breath = 0.85 + 0.15 * sin(t * 1.4);
	col += color_gold.rgb * (0.16 + 0.35 * aura_boost) * exp(-r * r * (6.0 - 3.0 * aura_boost)) * breath;

	// Tres capas de estrellas con distinta escala y deriva
	float s = star_layer(p + vec2(t * 0.002, 0.0), 45.0, t);
	s += star_layer(p, 90.0, t * 1.3) * 0.7;
	s += star_layer(p + vec2(0.0, t * 0.001), 170.0, t * 0.7) * 0.5;
	col += vec3(s) * mix(vec3(1.0), color_gold.rgb, 0.25);

	// Viñeta para enfocar el centro
	float vignette = smoothstep(1.25, 0.35, length((uv - 0.5) * vec2(aspect, 1.0)));
	COLOR = vec4(col * mix(0.55, 1.0, vignette), 1.0);
}
