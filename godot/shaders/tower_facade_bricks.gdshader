shader_type spatial;

// The Stonewatch Beacon atlas is densely packed. Sample only six coherent
// patches within one pale-stone column, one patch per masonry block. UVs on
// each facade span its dimensions in metres, so blocks stay 1 x 0.5 m on
// every building instead of stretching with the BoxMesh.
uniform sampler2D tower_base_color : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 facade_metres = vec2(4.0, 4.0);
uniform vec4 stone_tint : source_color = vec4(1.0);

float brick_hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 metres = UV * facade_metres;
	float row = floor(metres.y / 0.5);
	float stagger = mod(row, 2.0) * 0.5;
	float column = floor(metres.x + stagger);
	vec2 local_uv = vec2(fract(metres.x + stagger), fract(metres.y / 0.5));
	vec2 cell = vec2(column, row);

	float variant = floor(brick_hash(cell) * 6.0);
	float source_y = 1077.0;
	if (variant > 4.5) {
		source_y = 1336.0;
	} else if (variant > 3.5) {
		source_y = 1287.0;
	} else if (variant > 2.5) {
		source_y = 1237.0;
	} else if (variant > 1.5) {
		source_y = 1180.0;
	} else if (variant > 0.5) {
		source_y = 1126.0;
	}
	// The patch is 51 x 23 atlas pixels: nearly the block's 2:1 aspect.
	vec2 atlas_uv = (vec2(948.0, source_y) + local_uv * vec2(51.0, 23.0)) / 2048.0;
	vec3 stone = texture(tower_base_color, atlas_uv).rgb;
	stone *= mix(0.94, 1.06, brick_hash(cell + vec2(9.0, 3.0)));

	// Restrained mortar and a shallow edge shadow make the large blocks read
	// from the playable camera distance without adding physical wall geometry.
	float joint = 1.0 - step(0.035, local_uv.x) * step(0.070, local_uv.y);
	float edge = 1.0 - step(0.070, local_uv.x) * step(0.12, local_uv.y);
	vec3 color = mix(stone, stone * 0.77, edge);
	color = mix(color, vec3(0.33, 0.34, 0.32), joint);
	ALBEDO = color * stone_tint.rgb;
	ROUGHNESS = 0.94;
	METALLIC = 0.0;
}
