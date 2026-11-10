shader_type spatial;
// Cave rock. Projects a tileable rock texture from all three axes
// (triplanar) so the generated cave mesh needs no UVs. Floors, walls and
// ceilings get different colours, the vertex colour carries baked ambient
// occlusion (rgb) and a large-scale tint (alpha), and damp patches on the
// floor get a wet sheen that catches the torchlight.

uniform sampler2D height_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : filter_linear_mipmap, repeat_enable;
uniform float tex_scale = 0.22;
uniform float normal_strength = 1.1;
uniform vec3 wall_color : source_color = vec3(0.40, 0.34, 0.29);
uniform vec3 wall_color_dark : source_color = vec3(0.21, 0.19, 0.20);
uniform vec3 floor_color : source_color = vec3(0.33, 0.28, 0.22);
uniform vec3 moss_color : source_color = vec3(0.14, 0.20, 0.10);
uniform float wetness = 0.6;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float tri_height(vec3 p, vec3 w, float s) {
	return texture(height_tex, p.zy * s).r * w.x
		+ texture(height_tex, p.xz * s).r * w.y
		+ texture(height_tex, p.xy * s).r * w.z;
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);

	vec2 uv_x = world_pos.zy * tex_scale;
	vec2 uv_y = world_pos.xz * tex_scale;
	vec2 uv_z = world_pos.xy * tex_scale;

	float h = tri_height(world_pos, w, tex_scale);
	float big = tri_height(world_pos + vec3(17.0, 3.0, 9.0), w, tex_scale * 0.18);

	// Whiteout-blended triplanar normal mapping.
	vec3 tx = texture(normal_tex, uv_x).xyz * 2.0 - 1.0;
	vec3 ty = texture(normal_tex, uv_y).xyz * 2.0 - 1.0;
	vec3 tz = texture(normal_tex, uv_z).xyz * 2.0 - 1.0;
	tx.xy *= normal_strength;
	ty.xy *= normal_strength;
	tz.xy *= normal_strength;
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	vec3 bumped = normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);

	float ao = COLOR.r;
	float tint = COLOR.a;
	float is_floor = smoothstep(0.55, 0.85, n.y);
	float is_ceiling = smoothstep(-0.4, -0.8, n.y);

	vec3 rock = mix(wall_color, wall_color_dark, clamp(tint * 0.8 + big * 0.5 - 0.3, 0.0, 1.0));
	rock = mix(rock, rock * 0.6, is_ceiling);
	// Damp, darker rock low down on the walls.
	rock *= mix(0.7, 1.0, smoothstep(0.0, 1.6, world_pos.y));
	vec3 ground = floor_color * mix(0.8, 1.15, big);
	vec3 albedo = mix(rock, ground, is_floor);
	// Moss in low crevices.
	float moss = (1.0 - smoothstep(0.0, 0.9, world_pos.y)) * smoothstep(0.45, 0.25, h) * smoothstep(0.35, 0.65, big);
	albedo = mix(albedo, moss_color, moss * 0.8);
	albedo *= 0.55 + 0.7 * h;

	float wet = smoothstep(0.55, 0.7, big) * is_floor * wetness;

	ALBEDO = albedo * mix(1.0, ao, 0.65);
	AO = ao;
	AO_LIGHT_AFFECT = 0.25;
	ROUGHNESS = mix(0.92, 0.25, wet) - h * 0.08;
	SPECULAR = mix(0.35, 0.6, wet);
	NORMAL = normalize((VIEW_MATRIX * vec4(mix(bumped, n, wet * 0.6), 0.0)).xyz);
}
