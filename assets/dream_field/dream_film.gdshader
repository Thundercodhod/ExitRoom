shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

void fragment() {
	vec2 grid=vec2(360.0*SCREEN_PIXEL_SIZE.y/SCREEN_PIXEL_SIZE.x,360.0);
	vec2 uv=(floor(SCREEN_UV*grid)+.5)/grid;
	vec3 color = texture(screen_texture, uv).rgb;
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	color = mix(vec3(luma), color, 0.94);
	float shadow = 1.0 - smoothstep(0.08, 0.60, luma);
	color *= mix(vec3(1.0), vec3(0.94, 0.87, 1.04), shadow * 0.28);
	vec2 edge = (SCREEN_UV - 0.5) * vec2(1.5, 1.1);
	float vignette = smoothstep(0.35, 0.88, length(edge));
	color *= 1.0 - vignette * 0.16;
	COLOR = vec4(color, 1.0);
}
