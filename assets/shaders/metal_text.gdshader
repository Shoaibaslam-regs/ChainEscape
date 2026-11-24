// Polished-gold fill for text, with a moving glint band.
// Keeps the glyph shapes (alpha) and replaces their colour.
// Set `rect_size` to the node's size; animate `glint_position` from about
// -0.3 to 1.3 to sweep the highlight across.
shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(1.0, 0.941, 0.749, 1.0);
uniform vec4 middle_color : source_color = vec4(0.910, 0.690, 0.290, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.612, 0.420, 0.110, 1.0);
uniform vec4 glint_color : source_color = vec4(1.0, 0.973, 0.882, 1.0);
uniform vec2 rect_size = vec2(1.0, 1.0);
uniform float glint_position = -0.3;
uniform float glint_width = 0.1;

varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec4 glyph = texture(TEXTURE, UV) * COLOR;
	vec2 normalized = local_position / max(rect_size, vec2(1.0));
	float height = clamp(normalized.y, 0.0, 1.0);
	vec3 metal = height < 0.45
		? mix(top_color.rgb, middle_color.rgb, height / 0.45)
		: mix(middle_color.rgb, bottom_color.rgb, (height - 0.45) / 0.55);
	float diagonal = normalized.x + normalized.y * 0.25;
	float glint = 1.0 - smoothstep(0.0, glint_width, abs(diagonal - glint_position));
	COLOR = vec4(mix(metal, glint_color.rgb, glint * 0.85), glyph.a);
}
