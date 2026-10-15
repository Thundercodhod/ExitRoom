shader_type spatial;
render_mode unshaded, cull_disabled;
varying vec3 world_position;
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec2 p=(world_position.xz-vec2(48.0,-60.0))/vec2(68.0,77.0);
	if(dot(p,p)>1.0) discard;
	vec3 view=normalize(world_position-CAMERA_POSITION_WORLD);
	float reflection=exp(-pow((view.x-.70)/.085,2.0));
	float ripple=sin(world_position.z*3.5+sin(world_position.x*.9)+TIME*.55)*.5+.5;
	ripple=floor(ripple*4.0)/4.0;
	vec3 water=mix(vec3(.27,.18,.27),vec3(.45,.28,.29),ripple*.6);
	water=mix(water,vec3(.95,.62,.17),reflection*(.45+ripple*.55));
	ALBEDO=water;
}
