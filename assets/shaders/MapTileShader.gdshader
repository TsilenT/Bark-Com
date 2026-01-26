shader_type spatial;

// Exposed Parameters (Instance-Specific)
instance uniform vec4 albedo_mod : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform float highlight_strength : hint_range(0.0, 1.0) = 0.0;
instance uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Base Textures (Shared)
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform float roughness : hint_range(0,1) = 0.8;

varying vec3 world_normal;

void vertex() {
	// Retrieve world normal for side-face detection
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec4 base_tex = texture(texture_albedo, UV);
	
	// Apply Instance Color Mod (Fog/Biome tint)
	vec3 final_albedo = base_tex.rgb * albedo_mod.rgb;
	
	// Cliff Shading: Darken vertical faces (Sides)
	// If normal is not pointing up (Y > 0.8), darken it.
	if (world_normal.y < 0.8) {
		final_albedo *= 0.6; // Darken sides to emphasize volume
	}
	
	// Apply Highlight Overlay (Additive or Mix)
	final_albedo = mix(final_albedo, highlight_color.rgb, highlight_strength * 0.5);
	
	ALBEDO = final_albedo;
	ROUGHNESS = roughness;
}
