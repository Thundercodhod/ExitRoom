shader_type sky;
uniform sampler2D panorama : source_color, filter_nearest, repeat_enable;
void sky() {
	float yaw = atan(EYEDIR.x,-EYEDIR.z)-.51;
	vec2 uv = vec2(yaw/6.2831853+.5,acos(clamp(EYEDIR.y,-1.0,1.0))/3.14159265);
	uv=(floor(uv*vec2(512.0,256.0))+.5)/vec2(512.0,256.0);
	vec3 color = texture(panorama,uv).rgb;
	float horizon=1.0-smoothstep(.02,.65,EYEDIR.y);
	color=mix(color,color*vec3(1.12,.95,1.0),.35);
	color=mix(color,vec3(.96,.32,.055),horizon*.16);
	vec3 direction=normalize(floor(EYEDIR*150.0+.5)/150.0);
	float sun=step(cos(.064),dot(direction,normalize(vec3(.70,.09,-.715))));
	COLOR=mix(color,vec3(1.0,.89,.33),sun);
}
