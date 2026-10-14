shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D grass_map : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D dirt_map : source_color, filter_nearest_mipmap, repeat_enable;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec2 uv = world_position.xz / 3.1;
	float patch = sin(world_position.x*.18 + sin(world_position.z*.12))*0.5+0.5;
	float clearing = 1.0-smoothstep(2.7,5.5,length(world_position.xz-vec2(0.0,-16.0)));
	vec3 grass = texture(grass_map,uv).rgb*vec3(1.22,.77,.28);
	vec3 dirt = texture(dirt_map,uv).rgb*vec3(.74,.55,.37);
	ALBEDO = mix(grass,dirt,max(clearing,patch*.20));
	ROUGHNESS = 1.0;
	SPECULAR = .08;
}
