shader_type spatial;

// Keep the original flat, collision-free water box. World-space ripples move
// through fixed harbor coordinates, so turning the camera never swims the UVs.
varying vec3 harbor_position;

float distance_to_island_squared(vec2 point, vec4 island) {
	vec2 outside = max(abs(point - island.xy) - island.zw, vec2(0.0));
	return dot(outside, outside);
}

void vertex() {
	harbor_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 point = harbor_position.xz;
	float harbor_distance = length(point - vec2(4.0, -12.0));
	float detail_fade = 1.0 - smoothstep(35.0, 120.0, harbor_distance);
	float swell = sin(dot(point, vec2(0.23, 0.15)) + TIME * 0.37)
		* sin(dot(point, vec2(-0.08, 0.27)) - TIME * 0.24)
		* (1.0 - smoothstep(90.0, 250.0, harbor_distance));
	float ripple = sin(dot(point, vec2(1.08, 0.34)) + TIME * 0.80)
		* sin(dot(point, vec2(-0.27, 0.78)) - TIME * 0.58) * detail_fade;
	float crest = smoothstep(0.36, 0.78, swell + ripple * 0.27);
	// Two gently curved wave trains make short, directional crest streaks.
	// Smooth thresholds keep their edges stable at the normal game camera.
	float wavelet_a = sin(dot(point, vec2(1.60, 0.38)) + TIME * 1.08
		+ sin(dot(point, vec2(0.19, -0.34))) * 0.24);
	float wavelet_b = sin(dot(point, vec2(1.22, -0.46)) - TIME * 0.77);
	float broken_a = smoothstep(-0.30, 0.52,
		sin(dot(point, vec2(-0.30, 0.71)) - TIME * 0.23));
	float broken_b = smoothstep(0.10, 0.75,
		sin(dot(point, vec2(0.36, 0.86)) + TIME * 0.29));
	float fine_crest = smoothstep(0.71, 0.94, wavelet_a) * broken_a;
	fine_crest += smoothstep(0.78, 0.96, wavelet_b) * broken_b * 0.55;
	// Small ripples fade before they compress into single-pixel horizon noise.
	fine_crest *= detail_fade;

	// The fixed gradient gives open water a little depth without sampling the
	// screen depth buffer or shifting as the player walks past the piers.
	float far_water = smoothstep(12.0, 58.0, harbor_distance);
	vec3 water = mix(vec3(0.075, 0.255, 0.300), vec3(0.035, 0.145, 0.190), far_water);
	water += vec3(swell * 0.014 + ripple * 0.011);
	water = mix(water, vec3(0.23, 0.43, 0.46), crest * 0.12);
	water = mix(water, vec3(0.33, 0.51, 0.52), fine_crest * 0.18);

	// Art-directed edge glints follow the five major walkable islands. Their
	// rectangles match the blockout, and the band stays just outside each edge.
	// This is deliberately faint; it does not claim depth-derived foam.
	float shore_sq = distance_to_island_squared(point, vec4(0.0, 0.0, 8.0, 8.0));
	shore_sq = min(shore_sq, distance_to_island_squared(point, vec4(-20.0, 0.0, 8.0, 8.0)));
	shore_sq = min(shore_sq, distance_to_island_squared(point, vec4(0.0, -22.0, 10.0, 8.0)));
	shore_sq = min(shore_sq, distance_to_island_squared(point, vec4(22.0, -2.0, 8.0, 10.0)));
	shore_sq = min(shore_sq, distance_to_island_squared(point, vec4(40.0, -1.0, 6.0, 9.0)));
	float near_shore = 1.0 - smoothstep(0.09, 1.44, shore_sq);
	float edge_glint = near_shore * smoothstep(0.20, 0.76, swell + ripple * 0.30);
	water = mix(water, vec3(0.37, 0.53, 0.52), near_shore * 0.11 + edge_glint * 0.22);

	ALBEDO = water;
	ROUGHNESS = mix(0.74, 0.49, crest * 0.3 + fine_crest * 0.55 + edge_glint * 0.2);
	METALLIC = 0.0;
	SPECULAR = 0.25;
}
