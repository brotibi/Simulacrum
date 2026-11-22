shader_type spatial;
render_mode skip_vertex_transform, vertex_lighting, specular_disabled, shadows_disabled;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable;
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);

// PS1 vertex snapping (jitter) settings
uniform bool vertex_snap_enabled = true;
uniform vec2 snap_resolution = vec2(213.0, 120.0);

// PS1 affine texture mapping (perspectiveless UV interpolation)
uniform float affine_amount : hint_range(0.0, 1.0) = 1.0;

// Distance vertex darkening / Silent Hill fog falloff
uniform float vertex_darkening_start = 4.0;
uniform float vertex_darkening_end = 18.0;

varying vec2 affine_uv;
varying float affine_w;
varying float vertex_fade;

void vertex() {
	// Transform vertex to view space manually (required by skip_vertex_transform)
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 clip_pos = PROJECTION_MATRIX * view_pos;

	if (vertex_snap_enabled && clip_pos.w > 0.0001) {
		vec2 ndc = clip_pos.xy / clip_pos.w;
		vec2 snapped_ndc = floor(ndc * snap_resolution + 0.5) / snap_resolution;
		clip_pos.xy = snapped_ndc * clip_pos.w;
	}

	POSITION = clip_pos;
	VERTEX = view_pos.xyz;
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);

	vec2 scaled_uv = UV * uv_scale + uv_offset;
	UV = scaled_uv;

	// Multiply UV by clip_pos.w in vertex shader and divide in fragment shader
	// to undo hardware perspective correction (PS1 affine warping)
	float w = max(clip_pos.w, 0.001);
	affine_uv = scaled_uv * w;
	affine_w = w;

	float dist = length(view_pos.xyz);
	vertex_fade = 1.0 - clamp((dist - vertex_darkening_start) / max(vertex_darkening_end - vertex_darkening_start, 0.001), 0.0, 1.0);
}

void fragment() {
	vec2 perspective_uv = UV;
	vec2 warped_uv = affine_uv / affine_w;
	vec2 final_uv = mix(perspective_uv, warped_uv, affine_amount);

	vec4 tex = texture(albedo_texture, final_uv);
	ALBEDO = tex.rgb * albedo_color.rgb * COLOR.rgb * vertex_fade;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
