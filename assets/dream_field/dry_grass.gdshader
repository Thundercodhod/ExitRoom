shader_type spatial;
render_mode cull_disabled, diffuse_burley;

// This field uses fine geometric straw; the frog's Binbun material is untouched.
uniform vec4 dark_straw : source_color = vec4(0.24, 0.25, 0.065, 1.0);
uniform vec4 pale_straw : source_color = vec4(0.67, 0.43, 0.10, 1.0);
uniform float draw_distance = 76.0;
uniform float wind_strength = 0.09;
varying vec3 world_position;
varying float variation;
varying float blade_height;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	variation = INSTANCE_CUSTOM.x;
	blade_height = 1.0 - UV.y;
	float wave = sin(world_position.x * 0.16 + world_position.z * 0.11 + TIME * 0.83);
	wave += sin(world_position.z * 0.31 - TIME * 1.36 + variation * 6.28) * 0.27;
	vec3 sway = vec3(wave, 0.0, wave * 0.38) * wind_strength * blade_height * blade_height;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(sway, 0.0)).xyz;
	float distance_to_camera = length(world_position.xz - CAMERA_POSITION_WORLD.xz);
	// Sink only the outermost ring into the straw-coloured ground before culling.
	VERTEX.y -= smoothstep(draw_distance - 16.0, draw_distance, distance_to_camera) * 1.7;
}

void fragment() {
	float patch = sin(world_position.x * 0.12 + sin(world_position.z * 0.09)) * 0.5 + 0.5;
	vec3 straw = mix(dark_straw.rgb, pale_straw.rgb, variation * 0.54 + patch * 0.46);
	ALBEDO = straw * mix(0.48, 1.10, smoothstep(0.0, 0.85, blade_height));
	ROUGHNESS = 1.0;
	SPECULAR = 0.08;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
