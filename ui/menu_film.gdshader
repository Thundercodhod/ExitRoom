shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform bool reduced_motion = false;
float random(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}
void fragment(){
	vec2 uv = SCREEN_UV;
	vec2 grid = vec2(960.0,540.0);
	vec3 col = texture(screen_texture,(floor(uv*grid)+.5)/grid).rgb;
	float t = reduced_motion ? 0.0 : floor(TIME*10.0);
	float grain = (random(uv*grid+t)-.5)*.018;
	float vignette = smoothstep(.22,.85,length((uv-.5)*vec2(1.2,1.0)));
	col *= vec3(.77,.88,.91)*(1.0-vignette*.65);
	col += grain;
	// Darken the menu edge while leaving the lit house visible.
	col *= 1.0-smoothstep(.45,1.0,uv.x)*.72;
	COLOR = vec4(col,1.0);
}
