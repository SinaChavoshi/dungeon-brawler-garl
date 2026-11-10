shader_type spatial;
// Glowing cave crystal: emissive core with a brighter rim.
render_mode specular_schlick_ggx;

uniform vec3 color : source_color = vec3(0.3, 0.8, 1.0);
uniform float glow = 2.5;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float pulse = 0.85 + 0.15 * sin(TIME * 1.7 + NODE_POSITION_WORLD.x * 3.0);
	ALBEDO = color * 0.3;
	ROUGHNESS = 0.15;
	METALLIC = 0.0;
	EMISSION = color * glow * pulse * (0.45 + rim);
}
