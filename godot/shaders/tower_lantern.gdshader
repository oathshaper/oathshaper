shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap;
uniform sampler2D surface_map : filter_linear_mipmap;
uniform float lamp_power = 0.0;
varying float tower_height;
void vertex() {
	tower_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}
void fragment() {
	vec3 paint = texture(albedo_map, UV).rgb;
	ALBEDO = paint;
	NORMAL_MAP = texture(normal_map, UV).rgb;
	vec3 surface = texture(surface_map, UV).rgb;
	ROUGHNESS = surface.g;
	METALLIC = surface.b;
	// The civic tower's amber panes occupy this measured band. Exclude the
	// dark mullions and stone, preserving the source mesh and its texture atlas.
	float window_band = smoothstep(7.50, 7.56, tower_height) * (1.0 - smoothstep(8.12, 8.19, tower_height));
	float amber = smoothstep(0.03, 0.10, paint.r - paint.b) * smoothstep(0.08, 0.22, paint.r);
	EMISSION = vec3(1.0, 0.65, 0.25) * window_band * amber * lamp_power;
}
