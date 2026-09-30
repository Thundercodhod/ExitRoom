shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float pixel_height : hint_range(180.0, 720.0) = 270.0;
uniform float softness : hint_range(0.0, 1.0) = 0.45;
uniform float exposure : hint_range(0.3, 1.5) = 0.72;
uniform float saturation : hint_range(0.0, 1.0) = 0.72;
uniform float grain_strength : hint_range(0.0, 0.05) = 0.009;
uniform float vignette_strength : hint_range(0.0, 0.8) = 0.48;

float noise(vec2 point) {
	return fract(sin(dot(point, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 grid = vec2(pixel_height * SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, pixel_height);
	vec2 cell = floor(SCREEN_UV * grid);
	vec2 uv = (cell + 0.5) / grid;
	vec2 spread = vec2(softness) / grid;
	vec3 color = texture(screen_texture, uv).rgb * 0.5;
	color += texture(screen_texture, uv + vec2(spread.x, 0.0)).rgb * 0.125;
	color += texture(screen_texture, uv - vec2(spread.x, 0.0)).rgb * 0.125;
	color += texture(screen_texture, uv + vec2(0.0, spread.y)).rgb * 0.125;
	color += texture(screen_texture, uv - vec2(0.0, spread.y)).rgb * 0.125;
	float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
	color = mix(vec3(luminance), color, saturation);
	// Keep warm practical lights, with a cooler cast in the unlit areas.
	float shadow = 1.0 - smoothstep(0.06, 0.55, luminance);
	color *= mix(vec3(1.0), vec3(0.69, 0.86, 1.08), shadow * 0.72);
	color = pow(max(color * exposure, vec3(0.0)), vec3(1.12));
	float grain = noise(cell + floor(TIME * 12.0)) - 0.5;
	color += grain * grain_strength;
	// Dither the reduced palette to avoid smooth modern-looking gradients.
	color = floor(max(color, vec3(0.0)) * 48.0 + noise(cell)) / 48.0;
	vec2 edge_position = (SCREEN_UV - 0.5) * vec2(2.0, 1.65);
	float edge = smoothstep(0.35, 1.12, length(edge_position));
	color *= 1.0 - edge * vignette_strength;
	COLOR = vec4(color, 1.0);
}
