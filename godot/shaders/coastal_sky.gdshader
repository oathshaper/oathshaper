shader_type sky;

// Static coastal cloud field. No TIME or POSITION keeps Godot 4.3 from
// rebuilding the radiance map every frame as the player walks. Godot 4.3's
// Compatibility renderer cannot compile the sky half-res sampler path, so
// this bounded two-scale cloud pattern renders directly without a subpass.
float hash21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float noise21(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

void sky() {
	float altitude = EYEDIR.y;
	float upper = smoothstep(-0.015, 0.62, altitude);
	vec3 color = mix(vec3(0.18, 0.23, 0.32), vec3(0.025, 0.045, 0.10), upper);
	float haze = 1.0 - smoothstep(-0.07, 0.17, altitude);
	color = mix(color, vec3(0.35, 0.29, 0.28), haze * 0.43);

	// Project onto a high cloud deck. Broad patches and fine broken wisps
	// produce layered coastal clouds without a panorama seam as the camera turns.
	vec2 deck = EYEDIR.xz / max(altitude + 0.35, 0.35);
	float broad = noise21(deck * vec2(1.15, 0.66) + vec2(4.0, 11.0));
	float detail = noise21(deck * vec2(2.6, 1.35) + vec2(13.0, 2.0));
	float body = smoothstep(0.50, 0.61, broad * 0.77 + detail * 0.23);
	float wisps = smoothstep(0.60, 0.72, detail) * 0.24;
	float height_mask = smoothstep(0.045, 0.17, altitude) *
		(1.0 - smoothstep(0.76, 0.98, altitude));
	float clouds = clamp((body * 0.77 + wisps) * height_mask, 0.0, 0.84);
	vec3 cloud_color = mix(vec3(0.17, 0.20, 0.27), vec3(0.40, 0.33, 0.30),
		1.0 - clamp(altitude * 1.5, 0.0, 1.0));
	COLOR = mix(color, cloud_color, clouds);
}
