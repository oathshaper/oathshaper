shader_type spatial;

// Sample one coherent stone island from the supplied tower's packed UV atlas.
// The box faces each use this island once; the full atlas is never tiled over
// a facade. Region is (x, y, width, height) in normalized atlas coordinates.
uniform sampler2D tower_base_color : source_color, filter_linear, repeat_disable;
uniform vec4 atlas_region = vec4(0.0, 0.0, 1.0, 1.0);

void fragment() {
	// One-texel inset prevents neighboring atlas islands bleeding onto edges.
	vec2 inset = vec2(1.0 / 2048.0);
	vec2 patch_uv = atlas_region.xy + inset + clamp(UV, vec2(0.0), vec2(1.0)) * (atlas_region.zw - 2.0 * inset);
	ALBEDO = texture(tower_base_color, patch_uv).rgb;
	ROUGHNESS = 0.92;
	METALLIC = 0.0;
}
