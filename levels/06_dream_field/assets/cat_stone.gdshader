shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D handpaint : source_color, filter_nearest_mipmap, repeat_disable;
void fragment() {
	vec3 paint=pow(max(texture(handpaint,UV).rgb,vec3(.001)),vec3(.58));
	float grey=dot(paint,vec3(.299,.587,.114));
	ALBEDO=mix(vec3(grey),paint,.35)*vec3(1.12,1.03,.91);
	ROUGHNESS=.96;
	SPECULAR=.08;
}
