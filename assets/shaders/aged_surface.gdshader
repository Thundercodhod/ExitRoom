shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_map : filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(0.8, 0.78, 0.7, 1.0);
uniform float metres_per_tile = 3.0;
uniform float grime = 0.5;
uniform float saturation = 0.6;
uniform float normal_strength = 0.2;
uniform float base_roughness = 0.85;
varying vec3 world_position;
varying vec3 world_normal;

float hash(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}
float noise3(vec3 p) {
    vec3 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash(i), hash(i+vec3(1,0,0)), f.x), mix(hash(i+vec3(0,1,0)), hash(i+vec3(1,1,0)), f.x), f.y),
               mix(mix(hash(i+vec3(0,0,1)), hash(i+vec3(1,0,1)), f.x), mix(hash(i+vec3(0,1,1)), hash(i+vec3(1,1,1)), f.x), f.y), f.z);
}
vec3 tri_color(sampler2D tex, vec3 p, vec3 w) {
    return texture(tex,p.yz).rgb*w.x + texture(tex,p.xz).rgb*w.y + texture(tex,p.xy).rgb*w.z;
}
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
    vec3 n = normalize(world_normal);
    vec3 w = pow(abs(n),vec3(8.0));
    w /= max(w.x+w.y+w.z,0.001);
    vec3 p = world_position / metres_per_tile;
    vec3 c = tri_color(albedo_map,p,w);
    c = mix(vec3(dot(c,vec3(0.299,0.587,0.114))),c,saturation);
    float broad = noise3(world_position*0.63+vec3(4.7,2.1,1.3));
    float mottling = broad*0.65 + noise3(world_position*2.2)*0.25 + noise3(world_position*6.0)*0.10;
    float damp = smoothstep(0.39,0.73,mottling);
    float foot = (1.0-smoothstep(0.05,0.9,world_position.y))*0.35;
    ALBEDO = c*tint.rgb*mix(vec3(1.0),vec3(0.29,0.31,0.27),clamp((damp+foot)*grime,0.0,0.85));
    float rough = texture(roughness_map,p.yz).r*w.x + texture(roughness_map,p.xz).r*w.y + texture(roughness_map,p.xy).r*w.z;
    ROUGHNESS = clamp(rough*0.25+base_roughness*0.8,0.65,1.0);
    SPECULAR = 0.2;
    vec3 tx = texture(normal_map_tex,p.yz).rgb*2.0-1.0;
    vec3 ty = texture(normal_map_tex,p.xz).rgb*2.0-1.0;
    vec3 tz = texture(normal_map_tex,p.xy).rgb*2.0-1.0;
    vec3 mapped = normalize(vec3(tx.z*sign(n.x),tx.x,tx.y)*w.x + vec3(ty.x,ty.z*sign(n.y),ty.y)*w.y + vec3(tz.x,tz.y,tz.z*sign(n.z))*w.z);
    NORMAL = normalize(mat3(VIEW_MATRIX)*normalize(mix(n,mapped,normal_strength)));
}
